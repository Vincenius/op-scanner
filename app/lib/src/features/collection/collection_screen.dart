import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/auth/auth_controller.dart';
import '../../data/collection_controller.dart';
import '../../data/collection_repository.dart';
import '../../providers.dart';
import '../../util/format.dart';
import '../catalog/widgets/card_thumb.dart';

class CollectionScreen extends ConsumerWidget {
  const CollectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    switch (auth.status) {
      case AuthStatus.unknown:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case AuthStatus.unauthenticated:
        return const _SignedOut();
      case AuthStatus.authenticated:
        return _CollectionView(email: auth.user!.email);
    }
  }
}

class _SignedOut extends StatelessWidget {
  const _SignedOut();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Collection')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 56),
              const SizedBox(height: 12),
              Text('Sign in to track your collection',
                  style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => context.go('/login'),
                icon: const Icon(Icons.login),
                label: const Text('Sign in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollectionView extends ConsumerWidget {
  const _CollectionView({required this.email});
  final String email;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(collectionFilterProvider);
    final sync = ref.watch(collectionSyncControllerProvider);
    final entries = ref.watch(collectionEntriesProvider);
    final stats = ref.watch(collectionStatsProvider).asData?.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Collection'),
        actions: [
          PopupMenuButton<CollectionSort>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort',
            initialValue: filter.sort,
            onSelected: ref.read(collectionFilterProvider.notifier).setSort,
            itemBuilder: (_) => const [
              PopupMenuItem(value: CollectionSort.addedDesc, child: Text('Recently added')),
              PopupMenuItem(value: CollectionSort.name, child: Text('Name')),
              PopupMenuItem(value: CollectionSort.priceDesc, child: Text('Price ↓')),
              PopupMenuItem(value: CollectionSort.priceAsc, child: Text('Price ↑')),
              PopupMenuItem(value: CollectionSort.quantityDesc, child: Text('Quantity')),
            ],
          ),
          IconButton(
            tooltip: 'Sync',
            onPressed: sync.running ? null : ref.read(collectionSyncControllerProvider.notifier).sync,
            icon: const Icon(Icons.sync),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle_outlined),
            onSelected: (v) {
              if (v == 'logout') ref.read(authControllerProvider.notifier).logout();
            },
            itemBuilder: (_) => [
              PopupMenuItem(enabled: false, child: Text(email)),
              const PopupMenuItem(value: 'logout', child: Text('Sign out')),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: TextField(
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search your collection…',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                filled: true,
              ),
              onChanged: ref.read(collectionFilterProvider.notifier).setQuery,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          if (sync.running) const LinearProgressIndicator(),
          if (stats != null && stats.count > 0) _StatsBar(stats: stats),
          Expanded(
            child: entries.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (items) => items.isEmpty
                  ? const _EmptyCollection()
                  : ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) => _CollectionTile(entry: items[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsBar extends StatelessWidget {
  const _StatsBar({required this.stats});
  final ({int count, int copies, double value}) stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('${stats.count} entries · ${stats.copies} cards'),
          Text('Value ${formatUsd(stats.value)}', style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _EmptyCollection extends StatelessWidget {
  const _EmptyCollection();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.collections_bookmark_outlined, size: 56),
            const SizedBox(height: 12),
            Text('No cards yet', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text('Browse the catalog and add cards to your collection.', textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _CollectionTile extends ConsumerWidget {
  const _CollectionTile({required this.entry});
  final CollectionEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final item = entry.item;
    final actions = ref.read(collectionActionsProvider);
    final lineValue = (entry.variant.marketPrice ?? 0) * item.quantity;

    return ListTile(
      onTap: () => context.go('/card/${entry.variant.cardId}'),
      leading: SizedBox(
        width: 40,
        height: 56,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: CardThumb(thumbPath: entry.variant.thumbUrl),
        ),
      ),
      title: Text(entry.card.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${item.variantId} · ${item.condition}'
        '${entry.variant.isAltArt ? ' · ${entry.variant.variantLabel ?? 'Alt'}' : ''}',
        style: theme.textTheme.bodySmall,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(formatUsd(lineValue), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => actions.setQuantity(item, item.quantity - 1),
            icon: const Icon(Icons.remove_circle_outline),
          ),
          Text('${item.quantity}', style: theme.textTheme.titleMedium),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => actions.setQuantity(item, item.quantity + 1),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }
}
