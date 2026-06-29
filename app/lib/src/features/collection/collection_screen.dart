import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/auth/auth_controller.dart';
import '../../data/collection_controller.dart';
import '../../data/collection_repository.dart';
import '../../providers.dart';
import '../../util/format.dart';
import '../catalog/widgets/card_thumb.dart';
import 'manage_tags_sheet.dart';
import 'tag_picker_sheet.dart';

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
                onPressed: () => context.push('/login'),
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
    final tags = ref.watch(tagsProvider).asData?.value ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Collection'),
        actions: [
          IconButton(
            tooltip: 'Manage tags',
            icon: const Icon(Icons.label_outline),
            onPressed: () => ManageTagsSheet.show(context),
          ),
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
            tooltip: 'Stats',
            onPressed: () => context.push('/collection/stats'),
            icon: const Icon(Icons.insights_outlined),
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
              if (v == 'settings') context.push('/settings');
            },
            itemBuilder: (_) => [
              PopupMenuItem(enabled: false, child: Text(email)),
              const PopupMenuItem(value: 'settings', child: Text('Settings')),
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
          if (tags.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8, top: 6),
                    child: ChoiceChip(
                      label: const Text('All'),
                      selected: filter.tagClientUuid == null,
                      onSelected: (_) => ref.read(collectionFilterProvider.notifier).setTag(null),
                    ),
                  ),
                  for (final t in tags)
                    Padding(
                      padding: const EdgeInsets.only(right: 8, top: 6),
                      child: ChoiceChip(
                        label: Text(t.name),
                        selected: filter.tagClientUuid == t.clientUuid,
                        onSelected: (_) => ref
                            .read(collectionFilterProvider.notifier)
                            .setTag(filter.tagClientUuid == t.clientUuid ? null : t.clientUuid),
                      ),
                    ),
                ],
              ),
            ),
          if (stats != null && stats.count > 0) _StatsBar(stats: stats),
          Expanded(
            child: entries.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (items) => items.isEmpty
                  ? const _EmptyCollection()
                  : ListView.builder(
                      itemCount: items.length,
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
            Text('No cards here', style: Theme.of(context).textTheme.titleMedium),
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

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: () => context.push('/card/${entry.variant.cardId}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 44,
                height: 62,
                child: ClipRRect(borderRadius: BorderRadius.circular(4), child: CardThumb(thumbPath: entry.variant.thumbUrl)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.card.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                    Text(
                      '${item.variantId} · ${item.condition}'
                      '${entry.variant.isAltArt ? ' · ${entry.variant.variantLabel ?? 'Alt'}' : ''}',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                    ),
                    if (entry.tags.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 2,
                          children: [
                            for (final t in entry.tags)
                              Chip(
                                label: Text(t.name),
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                padding: EdgeInsets.zero,
                                labelStyle: theme.textTheme.labelSmall,
                              ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(formatUsd(lineValue), style: const TextStyle(fontWeight: FontWeight.w700)),
                        const Spacer(),
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
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (v) {
                  if (v == 'tags') TagPickerSheet.show(context, entry);
                  if (v == 'remove') actions.remove(item);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'tags', child: ListTile(leading: Icon(Icons.label_outline), title: Text('Tags…'), contentPadding: EdgeInsets.zero)),
                  PopupMenuItem(value: 'remove', child: ListTile(leading: Icon(Icons.delete_outline), title: Text('Remove'), contentPadding: EdgeInsets.zero)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
