import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../data/collection_controller.dart';
import '../data/local/database.dart';
import '../providers.dart';
import '../util/format.dart';
import '../features/catalog/widgets/card_thumb.dart';
import 'matcher.dart';
import 'phash.dart';
import 'rectifier.dart';
import 'scan_controller.dart';

// Card code formats: OP01-016, ST14-001, EB02-061, P-001 (promo).
final _codeRegex = RegExp(r'\b((?:OP|ST|EB)\d{2}-\d{3}|P-\d{3})\b', caseSensitive: false);

class _ScanOutcome {
  _ScanOutcome(this.result, this.code, this.topVariant, this.topName);
  final MatchResult result;
  final String? code;
  final CatalogVariant? topVariant;
  final String? topName;
}

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  CameraController? _camera;
  final TextRecognizer _recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  bool _busy = false;
  String? _error;
  _ScanOutcome? _outcome;

  @override
  void initState() {
    super.initState();
    _initCamera();
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
    _camera?.dispose();
    _recognizer.close();
    super.dispose();
  }

  Future<String?> _ocrCode(String path) async {
    try {
      final recognized = await _recognizer.processImage(InputImage.fromFilePath(path));
      final match = _codeRegex.firstMatch(recognized.text);
      return match?.group(0)?.toUpperCase();
    } catch (_) {
      return null;
    }
  }

  Future<void> _scan() async {
    final camera = _camera;
    if (_busy || camera == null || !camera.value.isInitialized) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final db = await ref.read(scanDbProvider.future);
      if (db.isEmpty) {
        setState(() => _error = 'No recognition data yet — sync the catalog first.');
        return;
      }
      final shot = await camera.takePicture();
      final bytes = await File(shot.path).readAsBytes();
      final code = await _ocrCode(shot.path);

      final rgb = rectifyToRgb(bytes);
      if (rgb == null) {
        setState(() => _error = 'Could not read the photo.');
        return;
      }

      final repo = ref.read(catalogRepositoryProvider);
      final restrict = code != null ? await repo.variantIdsForCode(code) : null;
      final result = matchHash(phashFromRgb(rgb), db, restrictTo: (restrict?.isEmpty ?? true) ? null : restrict);

      final top = result.top1;
      CatalogVariant? topVariant;
      String? topName;
      if (top != null) {
        topVariant = await repo.variantById(top.variantId);
        if (topVariant != null) {
          topName = (await repo.cardById(topVariant.cardId))?.name;
        }
      }
      final outcome = _ScanOutcome(result, code, topVariant, topName);

      // Rapid-add: auto-add a confident match and keep scanning.
      if (ref.read(rapidAddProvider) && result.accepted && top != null) {
        await _add(top.variantId, topName ?? top.variantId);
        setState(() => _outcome = outcome);
      } else {
        setState(() => _outcome = outcome);
      }
    } catch (e) {
      setState(() => _error = 'Scan failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add(String variantId, String label) async {
    final tag = ref.read(scanTagProvider);
    await ref.read(collectionActionsProvider).addScanned(variantId, tagClientUuid: tag);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added $label'), duration: const Duration(milliseconds: 900)),
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
            const Text('Rapid', style: TextStyle(fontSize: 13)),
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
        // Card-aspect alignment guide.
        Center(
          child: AspectRatio(
            aspectRatio: 600 / 838,
            child: Container(
              margin: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white70, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        if (_busy) const Center(child: CircularProgressIndicator()),
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
          if (outcome != null) _ResultCard(outcome: outcome, onAdd: _add),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _busy ? null : _scan,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan card'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
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
    final top = outcome.result.top1;
    if (top == null || outcome.topVariant == null) {
      return const Card(child: Padding(padding: EdgeInsets.all(12), child: Text('No match found. Try re-framing the card.')));
    }
    final v = outcome.topVariant!;
    final name = outcome.topName ?? v.variantId;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            SizedBox(width: 44, height: 62, child: ClipRRect(borderRadius: BorderRadius.circular(4), child: CardThumb(thumbPath: v.thumbUrl))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('${v.variantId}'
                      '${outcome.result.accepted ? '' : '  · confirm?'}'
                      '${outcome.code != null ? '  · OCR ${outcome.code}' : ''}'
                      '  · d=${top.distance}'),
                ],
              ),
            ),
            Text(formatUsd(v.marketPrice)),
            const SizedBox(width: 8),
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
