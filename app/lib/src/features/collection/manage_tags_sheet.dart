import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/collection_controller.dart';
import '../../data/local/database.dart';
import '../../providers.dart';

/// Create / rename / delete tags.
class ManageTagsSheet extends ConsumerWidget {
  const ManageTagsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const ManageTagsSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(tagsProvider).asData?.value ?? const [];
    final actions = ref.read(collectionActionsProvider);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Tags', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _createDialog(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('New'),
                ),
              ],
            ),
            if (tags.isEmpty)
              const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Text('No tags yet.'))
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final t in tags)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.label_outline),
                        title: Text(t.name),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _renameDialog(context, ref, t),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => actions.deleteTag(t),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _createDialog(BuildContext context, WidgetRef ref) async {
    final name = await _nameDialog(context, title: 'New tag');
    if (name != null && name.isNotEmpty) {
      await ref.read(collectionActionsProvider).createTag(name);
    }
  }

  Future<void> _renameDialog(BuildContext context, WidgetRef ref, TagRow tag) async {
    final name = await _nameDialog(context, title: 'Rename tag', initial: tag.name);
    if (name != null && name.isNotEmpty) {
      await ref.read(collectionActionsProvider).renameTag(tag, name);
    }
  }

  Future<String?> _nameDialog(BuildContext context, {required String title, String initial = ''}) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Tag name'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(controller.text), child: const Text('Save')),
        ],
      ),
    );
  }
}
