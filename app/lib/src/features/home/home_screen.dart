import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform.dart';

/// Placeholder home for Phase 0. Demonstrates the scanner feature-flag seam:
/// the scan entry point renders only on platforms where scanning is supported.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('OP Scanner')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('One Piece TCG Collection', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Phase 0 — scaffold · placeholder home',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            if (isScanningSupported)
              FilledButton.icon(
                // Wired up in Phase 3.
                onPressed: null,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan a card (Phase 3)'),
              )
            else
              Text(
                'Scanning is available on the mobile app.',
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}
