import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../data/catalog_repository.dart';
import '../data/collection_controller.dart';
import '../data/local/database.dart';
import '../providers.dart';
import '../util/format.dart';
import '../features/catalog/widgets/card_thumb.dart';
import 'matcher.dart';
import 'phash.dart';
import 'process_frame.dart';
import 'scan_controller.dart';

// Card code formats: OP01-016, ST14-001, EB02-061, P-001 (promo).
final _codeRegex = RegExp(r'\b((?:OP|ST|EB)\d{2}-\d{3}|P-\d{3})\b', caseSensitive: false);

// Require the same card across this many consecutive frames before adding.
const int _stableNeeded = 2;
// Empty/no-match frames before the same card may be added again.
const int _resetAfterEmpty = 3;
const Duration _frameGap = Duration(milliseconds: 250);

class _ScanOutcome {
  _ScanOutcome(this.result, this.code, this.topVariant, this.topName, this.added);
  final MatchResult result;
  final String? code;
  final CatalogVariant? topVariant;
  final String? topName;
  final bool added;
}

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> with WidgetsBindingObserver {
  CameraController? _camera;
  final TextRecognizer _recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  Map<String, String> _db = const {};
  bool _scanning = false;
  bool _processing = false;
  String? _error;
  _ScanOutcome? _outcome;

  // Stability / debounce state.
  String? _stableVariant;
  int _stableCount = 0;
  String? _lastAddedVariant;
  int _emptyFrames = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Release the camera when backgrounded (the OS may reclaim it) and re-init
    // on resume, so the loop doesn't spin on a dead/invalid controller.
    if (state == AppLifecycleState.resumed) {
      if (_camera == null) _resumeCamera();
    } else {
      _scanning = false;
      final c = _camera;
      _camera = null;
      if (mounted) setState(() {});
      c?.dispose();
    }
  }

  Future<void> _resumeCamera() async {
    await _initCamera();
    if (_camera != null && _db.isNotEmpty) {
      _scanning = true;
      _loop();
    }
  }

  Future<void> _start() async {
    _db = await ref.read(scanDbProvider.future);
    await _initCamera();
    if (_camera != null && _db.isNotEmpty) {
      _scanning = true;
      _loop();
    } else if (_db.isEmpty) {
      setState(() => _error = 'No recognition data yet — sync the catalog first.');
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(back, ResolutionPreset.high, enableAudio: false);
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _camera = controller);
    } catch (e) {
      setState(() => _error = 'Camera unavailable: $e');
    }
  }

  @override
  void dispose() {
    _scanning = false;
    WidgetsBinding.instance.removeObserver(this);
    _camera?.dispose();
    _recognizer.close();
    super.dispose();
  }

  /// Continuous auto-capture loop (no manual tap). Each tick captures a frame,
  /// recognizes it, and auto-adds confident, stable, not-just-added cards.
  Future<void> _loop() async {
    while (_scanning && mounted) {
      final camera = _camera;
      if (camera != null && camera.value.isInitialized && !_processing) {
        await _tick(camera);
      }
      await Future.delayed(_frameGap);
    }
  }

  Future<void> _tick(CameraController camera) async {
    _processing = true;
    try {
      final shot = await camera.takePicture();
      final bytes = await File(shot.path).readAsBytes();
      final code = await _ocrCode(shot.path);
      try {
        await File(shot.path).delete();
      } catch (_) {}

      final rgb = rectifyPhoto(bytes);
      if (rgb == null) {
        _onNoMatch();
        return;
      }
      final repo = ref.read(catalogRepositoryProvider);
      final restrict = code != null ? await repo.variantIdsForCode(code) : null;
      final result = matchHash(
        phashFromRgb(rgb),
        _db,
        restrictTo: (restrict?.isEmpty ?? true) ? null : restrict,
      );
      await _onResult(result, code, repo);
    } catch (e) {
      // Transient capture/decode errors shouldn't stop the loop.
    } finally {
      _processing = false;
    }
  }

  Future<void> _onResult(MatchResult result, String? code, CatalogRepository repo) async {
    final top = result.top1;
    if (!result.accepted || top == null) {
      _onNoMatch();
      return;
    }
    _emptyFrames = 0;
    if (top.variantId == _stableVariant) {
      _stableCount++;
    } else {
      _stableVariant = top.variantId;
      _stableCount = 1;
    }

    final variant = await repo.variantById(top.variantId);
    final name = variant != null ? (await repo.cardById(variant.cardId))?.name : null;

    var added = false;
    final shouldAdd = _stableCount >= _stableNeeded && top.variantId != _lastAddedVariant;
    if (shouldAdd && ref.read(rapidAddProvider)) {
      await _add(top.variantId, name ?? top.variantId);
      _lastAddedVariant = top.variantId;
      added = true;
    }
    if (mounted) {
      setState(() => _outcome = _ScanOutcome(result, code, variant, name, added));
    }
  }

  void _onNoMatch() {
    _emptyFrames++;
    _stableVariant = null;
    _stableCount = 0;
    if (_emptyFrames >= _resetAfterEmpty) {
      _lastAddedVariant = null;
      if (mounted && _outcome != null) setState(() => _outcome = null);
    }
  }

  Future<String?> _ocrCode(String path) async {
    try {
      final recognized = await _recognizer.processImage(InputImage.fromFilePath(path));
      return _codeRegex.firstMatch(recognized.text)?.group(0)?.toUpperCase();
    } catch (_) {
      return null;
    }
  }

  Future<void> _add(String variantId, String label) async {
    final tag = ref.read(scanTagProvider);
    await ref.read(collectionActionsProvider).addScanned(variantId, tagClientUuid: tag);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added $label'), duration: const Duration(milliseconds: 800)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final rapid = ref.watch(rapidAddProvider);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text('Scan'),
        actions: [
          Row(children: [
            const Text('Auto-add', style: TextStyle(fontSize: 13)),
            Switch(value: rapid, onChanged: (_) => ref.read(rapidAddProvider.notifier).toggle()),
          ]),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _preview()),
          _TagSelector(),
          _bottomPanel(),
        ],
      ),
    );
  }

  Widget _preview() {
    final camera = _camera;
    if (_error != null && camera == null) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, style: const TextStyle(color: Colors.white))));
    }
    if (camera == null) return const Center(child: CircularProgressIndicator());
    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(camera),
        Center(
          child: AspectRatio(
            aspectRatio: 600 / 838,
            child: Container(
              margin: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white70, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const Positioned(
          top: 12,
          left: 0,
          right: 0,
          child: Center(
            child: Text('Point at a card — scanning automatically',
                style: TextStyle(color: Colors.white70, fontSize: 12)),
          ),
        ),
      ],
    );
  }

  Widget _bottomPanel() {
    final outcome = _outcome;
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null && _camera != null)
            Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_error!, style: const TextStyle(color: Colors.orangeAccent))),
          if (outcome != null && outcome.topVariant != null)
            _ResultCard(outcome: outcome, onAdd: _add)
          else
            const SizedBox(
              height: 48,
              child: Center(child: Text('Searching…', style: TextStyle(color: Colors.white54))),
            ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.outcome, required this.onAdd});
  final _ScanOutcome outcome;
  final Future<void> Function(String variantId, String label) onAdd;

  @override
  Widget build(BuildContext context) {
    final top = outcome.result.top1!;
    final v = outcome.topVariant!;
    final name = outcome.topName ?? v.variantId;
    return Card(
      color: outcome.added ? Colors.green.shade100 : null,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            SizedBox(width: 40, height: 56, child: ClipRRect(borderRadius: BorderRadius.circular(4), child: CardThumb(thumbPath: v.thumbUrl))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('${v.variantId}'
                      '${outcome.code != null ? ' · OCR ${outcome.code}' : ''}'
                      ' · d=${top.distance}'),
                ],
              ),
            ),
            Text(formatUsd(v.marketPrice)),
            const SizedBox(width: 8),
            if (outcome.added)
              const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.check_circle, color: Colors.green))
            else
              FilledButton(onPressed: () => onAdd(v.variantId, name), child: const Text('Add')),
          ],
        ),
      ),
    );
  }
}

class _TagSelector extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(tagsProvider).asData?.value ?? const [];
    final selected = ref.watch(scanTagProvider);
    return Container(
      color: Colors.black,
      height: 48,
      child: Row(
        children: [
          const Padding(padding: EdgeInsets.only(left: 12), child: Text('Tag:', style: TextStyle(color: Colors.white70))),
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              children: [
                ChoiceChip(
                  label: const Text('None'),
                  selected: selected == null,
                  onSelected: (_) => ref.read(scanTagProvider.notifier).set(null),
                ),
                for (final t in tags)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: ChoiceChip(
                      label: Text(t.name),
                      selected: selected == t.clientUuid,
                      onSelected: (_) => ref.read(scanTagProvider.notifier).set(t.clientUuid),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: ActionChip(
                    avatar: const Icon(Icons.add, size: 16),
                    label: const Text('New'),
                    onPressed: () => _newTag(context, ref),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _newTag(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New tag'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: 'e.g. Green Deck Box')),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(controller.text), child: const Text('Create')),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      final cu = await ref.read(collectionActionsProvider).createTag(name.trim());
      ref.read(scanTagProvider.notifier).set(cu);
    }
  }
}
