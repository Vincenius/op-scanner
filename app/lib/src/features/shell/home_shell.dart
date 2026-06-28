import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../catalog/catalog_screen.dart';
import '../collection/collection_screen.dart';

final navIndexProvider = NotifierProvider<NavIndex, int>(NavIndex.new);

class NavIndex extends Notifier<int> {
  @override
  int build() => 0;
  void set(int i) => state = i;
}

/// Bottom-nav shell hosting the Catalog and Collection tabs.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(navIndexProvider);
    return Scaffold(
      body: IndexedStack(
        index: index,
        children: const [CatalogScreen(), CollectionScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: ref.read(navIndexProvider.notifier).set,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.style_outlined), selectedIcon: Icon(Icons.style), label: 'Catalog'),
          NavigationDestination(icon: Icon(Icons.collections_bookmark_outlined), selectedIcon: Icon(Icons.collections_bookmark), label: 'Collection'),
        ],
      ),
    );
  }
}
