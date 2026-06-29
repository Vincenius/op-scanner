import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../data/catalog_repository.dart';
import '../data/collection_controller.dart';
import '../data/local/database.dart';
import '../data/sync_service.dart';
import '../providers.dart';
import '../util/format.dart';
import '../features/catalog/widgets/card_thumb.dart';
import 'camera_image_convert.dart';
import 'matcher.dart';
import 'opencv_rectifier.dart';
import 'phash.dart';
import 'scan_controller.dart';

// Card code formats: OP01-016, ST14-001, EB02-061, P-001 (promo).
final _codeRegex = RegExp(r'\b((?:OP|ST|EB)\d{2}-\d{3}|P-\d{3})\b', caseSensitive: false);

// Require the same card across this many consecutive frames before adding.
const int _stableNeeded = 2;
// Empty/no-match frames before the same card may be added again.
const int _resetAfterEmpty = 3;
// Minimum spacing between processed frames. Frames arriving while one is being
// processed are dropped; this also paces work so the UI isolate keeps breathing.
const Duration _minProcessGap = Duration(milliseconds: 90);
// OCR (ML Kit) is comparatively expensive, so it runs off the recognition hot
// path: at most this often, with the last read code reused in between.
const Duration _ocrInterval = Duration(milliseconds: 600);
const Duration _ocrTtl = Duration(milliseconds: 1500);

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
  bool _streaming = false;
  int _sensorOrientation = 0;
  String? _error;
  _ScanOutcome? _outcome;

  // Stability / debounce state.
  String? _stableVariant;
  int _stableCount = 0;
  String? _lastAddedVariant;
  int _emptyFrames = 0;

  // Frame pacing + OCR throttle.
  DateTime _lastProcessed = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastOcrAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _ocrBusy = false;
  String? _recentCode;
  DateTime _recentCodeAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Release the camera when backgrounded (the OS may reclaim it) and re-init
    // on resume, so we don't stream into a dead/invalid controller.
    if (state == AppLifecycleState.resumed) {
      if (_camera == null) _resumeCamera();
    } else {
      _scanning = false;
      _streaming = false;
      final c = _camera;
      _camera = null;
      if (mounted) setState(() {});
      c?.dispose(); // dispose() also stops the image stream
    }
  }

  Future<void> _resumeCamera() async {
    await _initCamera();
    if (_camera != null && _db.isNotEmpty) {
      _scanning = true;
      await _startStream();
    }
  }

  Future<void> _start() async {
    // Re-read the match DB from SQLite each time the screen opens. The provider
    // is cached for the app's lifetime, so without invalidating it a catalog
    // sync done since launch (the one that downloads recognition hashes) would
    // not be reflected and the screen would stay stuck on "no recognition data".
    ref.invalidate(scanDbProvider);
    _db = await ref.read(scanDbProvider.future);
    if (_camera == null) await _initCamera();
    if (_camera != null && _db.isNotEmpty) {
      if (mounted) setState(() => _error = null);
      _scanning = true;
      await _startStream();
    } else if (_db.isEmpty) {
      if (mounted) {
        setState(() => _error = 'No recognition data yet — sync the catalog first.');
      }
    }
  }

  /// Run a catalog sync (which downloads recognition hashes), then re-check the
  /// match DB. Invoked from the empty-state button so the user can recover
  /// without leaving the scan screen.
  Future<void> _syncAndRetry() async {
    try {
      await ref.read(syncControllerProvider.notifier).sync();
    } catch (_) {
      // Sync errors surface via syncControllerProvider; _start re-checks the
      // local DB regardless and re-shows the prompt if still empty.
    }
    await _start();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      _sensorOrientation = back.sensorOrientation;
      // Request a format we can wrap directly into an OpenCV Mat (and feed ML
      // Kit) without re-encoding: NV21 on Android, BGRA on iOS.
      final format = Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888;
      final controller = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: format,
      );
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
    _streaming = false;
    WidgetsBinding.instance.removeObserver(this);
    _camera?.dispose();
    _recognizer.close();
    super.dispose();
  }

  Future<void> _startStream() async {
    final camera = _camera;
    if (camera == null || _streaming || _db.isEmpty) return;
    if (!camera.value.isInitialized) return;
    _streaming = true;
    try {
      await camera.startImageStream(_onFrame);
    } catch (e) {
      _streaming = false;
      if (mounted) setState(() => _error = 'Scan stream unavailable: $e');
    }
  }

  /// Live-preview frame callback. Frames that arrive while one is in flight (or
  /// inside the pacing window) are dropped — recognition runs as fast as the
  /// pipeline allows without queueing stale frames or starving the UI.
  void _onFrame(CameraImage image) {
    if (!_scanning || _processing) return;
    final now = DateTime.now();
    if (now.difference(_lastProcessed) < _minProcessGap) return;
    _processing = true;
    _lastProcessed = now;
    _handleFrame(image).whenComplete(() => _processing = false);
  }

  Future<void> _handleFrame(CameraImage image) async {
    List<String>? hashes;
    try {
      // Synchronous section — runs before the first await, while the frame
      // buffer is still valid: convert to BGR, detect + rectify the card (both
      // upright orientations), and hash each.
      final bgr = cameraImageToBgr(image);
      if (bgr != null) {
        try {
          var rgbs = rectifyCardOrientations(bgr);
          if (rgbs.isEmpty) rgbs = centerCropOrientations(bgr);
          hashes = [for (final r in rgbs) phashFromRgb(r)];
        } finally {
          bgr.dispose();
        }
      }
      // Fire-and-forget OCR (throttled); updates the cached code for later
      // frames without blocking this one.
      _maybeOcr(image);
    } catch (_) {
      // Transient decode/detect errors shouldn't stop the stream.
    }

    if (hashes == null || hashes.isEmpty) {
      _onNoMatch();
      return;
    }

    try {
      final code = _freshCode();
      final repo = ref.read(catalogRepositoryProvider);
      final restrict = code != null ? await repo.variantIdsForCode(code) : null;
      final result = matchHashMulti(
        hashes,
        _db,
        restrictTo: (restrict?.isEmpty ?? true) ? null : restrict,
      );
      await _onResult(result, code, repo);
    } catch (_) {
      // Matching/repo errors shouldn't stop the stream.
    }
  }

  /// Run OCR on a throttle, off the recognition hot path. The detected card code
  /// is cached and reused (within [_ocrTtl]) to restrict match candidates.
  void _maybeOcr(CameraImage image) {
    if (_ocrBusy) return;
    final now = DateTime.now();
    if (now.difference(_lastOcrAt) < _ocrInterval) return;
    final input = inputImageFromCameraImage(image, _sensorOrientation);
    if (input == null) return; // format not OCR-able (e.g. yuv420 fallback)
    _lastOcrAt = now;
    _ocrBusy = true;
    _ocr(input).whenComplete(() => _ocrBusy = false);
  }

  Future<void> _ocr(InputImage input) async {
    try {
      final recognized = await _recognizer.processImage(input);
      final code = _codeRegex.firstMatch(recognized.text)?.group(0)?.toUpperCase();
      if (code != null) {
        _recentCode = code;
        _recentCodeAt = DateTime.now();
      }
    } catch (_) {}
  }

  String? _freshCode() {
    if (_recentCode == null) return null;
    if (DateTime.now().difference(_recentCodeAt) > _ocrTtl) return null;
    return _recentCode;
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
        _CameraFill(controller: camera),
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
            child: Text('Point at a card — any angle, scanning automatically',
                style: TextStyle(color: Colors.white70, fontSize: 12)),
          ),
        ),
      ],
    );
  }

  Widget _bottomPanel() {
    final outcome = _outcome;
    final noData = _db.isEmpty;
    final sync = ref.watch(syncControllerProvider);
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null && _camera != null)
            Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_error!, style: const TextStyle(color: Colors.orangeAccent))),
          if (noData)
            _SyncPrompt(running: sync.running, progress: sync.progress, onSync: _syncAndRetry)
          else if (outcome != null && outcome.topVariant != null)
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

/// Fills the available space with the live preview at the camera's true aspect
/// ratio (BoxFit.cover). A bare [CameraPreview] given the tight constraints of
/// an expanded Stack stretches the texture (skewed preview); here CameraPreview
/// keeps its ratio under loose constraints and we scale it up to cover the box.
class _CameraFill extends StatelessWidget {
  const _CameraFill({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // CameraPreview reports its ratio in landscape; on a portrait device it
        // renders rotated, so the on-screen ratio is the reciprocal.
        final portrait =
            MediaQuery.orientationOf(context) == Orientation.portrait;
        final previewRatio = controller.value.aspectRatio;
        final shownRatio = portrait ? 1 / previewRatio : previewRatio;
        final boxRatio = constraints.maxWidth / constraints.maxHeight;
        final scale =
            shownRatio > boxRatio ? shownRatio / boxRatio : boxRatio / shownRatio;
        return ClipRect(
          child: Transform.scale(
            scale: scale,
            child: Center(child: CameraPreview(controller)),
          ),
        );
      },
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

/// Empty-state recovery shown when no recognition hashes are present locally.
/// Lets the user sync (which downloads the hashes) without leaving the screen.
class _SyncPrompt extends StatelessWidget {
  const _SyncPrompt({required this.running, required this.progress, required this.onSync});
  final bool running;
  final SyncProgress? progress;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    if (!running) {
      return FilledButton.icon(
        onPressed: onSync,
        icon: const Icon(Icons.sync),
        label: const Text('Sync catalog now'),
      );
    }
    String label;
    switch (progress?.phase) {
      case 'images':
        label = 'Downloading images…';
      case 'complete':
        label = 'Finishing…';
      default:
        label = 'Syncing catalog…';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          LinearProgressIndicator(value: progress?.fraction),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white70)),
        ],
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
