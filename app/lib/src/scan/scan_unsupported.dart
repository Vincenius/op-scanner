import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Web / unsupported-platform placeholder. The real [ScanScreen] (camera + OCR
/// + matcher) is selected on native via scan_entry.dart's conditional import.
class ScanScreen extends StatelessWidget {
  const ScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text('Scan'),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Scanning is available on the mobile app.', textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
