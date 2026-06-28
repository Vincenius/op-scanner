import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config.dart';
import '../../core/platform.dart';
import '../../data/auth/auth_controller.dart';
import '../../providers.dart';
import '../../util/format.dart';
import '../share/share_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final sync = ref.watch(syncControllerProvider);
    final lastSync = ref.watch(lastSyncProvider).asData?.value;
    final count = ref.watch(localVariantCountProvider).asData?.value ?? 0;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          const _SectionHeader('Account'),
          if (auth.isAuthenticated) ...[
            ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: Text(auth.user!.email),
              subtitle: const Text('Signed in'),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign out'),
              onTap: () => ref.read(authControllerProvider.notifier).logout(),
            ),
          ] else
            ListTile(
              leading: const Icon(Icons.login),
              title: const Text('Sign in'),
              subtitle: const Text('Track and sync your collection'),
              onTap: () => context.go('/login'),
            ),
          if (auth.isAuthenticated) ...[
            const Divider(),
            const _SectionHeader('Share'),
            const _ShareSection(),
          ],
          const Divider(),
          const _SectionHeader('Catalog'),
          ListTile(
            leading: const Icon(Icons.style_outlined),
            title: Text('$count cards in local database'),
            subtitle: Text('Last synced ${formatRelative(lastSync)}'),
          ),
          ListTile(
            leading: sync.running
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
            title: const Text('Refresh catalog'),
            subtitle: sync.running
                ? Text(switch (sync.progress?.phase) {
                    'images' => 'Caching images ${sync.progress!.done}/${sync.progress!.total}',
                    _ => 'Syncing…',
                  })
                : const Text('Download new cards, prices, and recognition data'),
            onTap: sync.running ? null : ref.read(syncControllerProvider.notifier).sync,
          ),
          if (sync.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('Last refresh failed: ${sync.error}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          const Divider(),
          const _SectionHeader('About'),
          ListTile(
            leading: const Icon(Icons.cloud_outlined),
            title: const Text('API server'),
            subtitle: Text(AppConfig.apiBaseUrl),
          ),
          ListTile(
            leading: const Icon(Icons.qr_code_scanner),
            title: const Text('Card scanning'),
            subtitle: Text(isScanningSupported ? 'Available on this device' : 'Mobile only'),
          ),
        ],
      ),
    );
  }
}

class _ShareSection extends ConsumerWidget {
  const _ShareSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(shareStatusProvider);
    final controller = ref.read(shareControllerProvider);
    return status.when(
      loading: () => const ListTile(
        leading: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
        title: Text('Public share'),
      ),
      error: (e, _) => const ListTile(
        leading: Icon(Icons.public_off),
        title: Text('Share unavailable'),
        subtitle: Text('Connect to manage sharing'),
      ),
      data: (slug) {
        return Column(
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.public),
              title: const Text('Public share link'),
              subtitle: Text(slug == null
                  ? 'Off — others can\'t see your collection'
                  : 'On — anyone with the link can view your collection'),
              value: slug != null,
              onChanged: (on) => on ? controller.enable() : controller.disable(),
            ),
            if (slug != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: SelectableText(shareLink(slug),
                          maxLines: 1, style: Theme.of(context).textTheme.bodySmall),
                    ),
                    IconButton(
                      tooltip: 'Copy link',
                      icon: const Icon(Icons.copy, size: 20),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: shareLink(slug)));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Link copied')),
                          );
                        }
                      },
                    ),
                    IconButton(
                      tooltip: 'Open',
                      icon: const Icon(Icons.open_in_new, size: 20),
                      onPressed: () => context.go('/share/$slug'),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.primary)),
    );
  }
}
