import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/collection_controller.dart';
import '../../data/collection_repository.dart';
import '../../providers.dart';

/// Assign tags ("boxes") to a collection entry; create new tags inline.
class TagPickerSheet extends ConsumerStatefulWidget {
  const TagPickerSheet({super.key, required this.entry});
  final CollectionEntry entry;

  static Future<void> show(BuildContext context, CollectionEntry entry) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => TagPickerSheet(entry: entry),
    );
  }

  @override
  ConsumerState<TagPickerSheet> createState() => _TagPickerSheetState();
}

class _TagPickerSheetState extends ConsumerState<TagPickerSheet> {
  late Set<String> _selected;
  final _newTag = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selected = widget.entry.tags.map((t) => t.clientUuid).toSet();
  }

  @override
  void dispose() {
    _newTag.dispose();
    super.dispose();
  }

  Future<void> _createTag() async {
    final name = _newTag.text.trim();
    if (name.isEmpty) return;
    final cu = await ref.read(collectionActionsProvider).createTag(name);
    setState(() {
      _selected.add(cu);
      _newTag.clear();
    });
  }

  Future<void> _save() async {
    await ref.read(collectionActionsProvider).setItemTags(widget.entry.item.clientUuid, _selected.toList());
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final tags = ref.watch(tagsProvider).asData?.value ?? const [];
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tags for ${widget.entry.card.name}', style: Theme.of(context).textTheme.titleLarge),
            Text(widget.entry.item.variantId, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            if (tags.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No tags yet — create one below.'),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final t in tags)
                    FilterChip(
                      label: Text(t.name),
                      selected: _selected.contains(t.clientUuid),
                      onSelected: (sel) => setState(() {
                        if (sel) {
                          _selected.add(t.clientUuid);
                        } else {
                          _selected.remove(t.clientUuid);
                        }
                      }),
                    ),
                ],
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newTag,
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'New tag (e.g. Green Deck Box)',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _createTag(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(onPressed: _createTag, icon: const Icon(Icons.add)),
              ],
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(onPressed: _save, child: const Text('Save')),
            ),
          ],
        ),
      ),
    );
  }
}
