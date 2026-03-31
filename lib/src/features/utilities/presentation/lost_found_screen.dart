import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/lost_found_repository.dart';
import '../../auth/data/auth_repository.dart';
import 'package:timeago/timeago.dart' as timeago;

class LostFoundScreen extends ConsumerWidget {
  const LostFoundScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Lost & Found'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'LOST'),
              Tab(text: 'FOUND'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            LostFoundList(type: LostFoundType.lost),
            LostFoundList(type: LostFoundType.found),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showReportDialog(context, ref),
          label: const Text('Report Item'),
          icon: const Icon(Icons.add),
        ),
      ),
    );
  }

  void _showReportDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    LostFoundType type = LostFoundType.lost;
    String category = 'ID Card';
    final categories = [
      'ID Card',
      'Keys',
      'Phone',
      'Wallet',
      'Books',
      'Others',
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Report Item'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<LostFoundType>(
                      initialValue: type,
                      items: LostFoundType.values.map((t) {
                        return DropdownMenuItem(
                          value: t,
                          child: Text(t.name.toUpperCase()),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => type = val!),
                      decoration: const InputDecoration(labelText: 'Type'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      items: categories.map((c) {
                        return DropdownMenuItem(value: c, child: Text(c));
                      }).toList(),
                      onChanged: (val) => setState(() => category = val!),
                      decoration: const InputDecoration(labelText: 'Category'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Item Name',
                        hintText: 'e.g. Blue Wallet',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'Where and when?',
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (titleController.text.isEmpty) return;

                    final user = ref.read(authRepositoryProvider).currentUser;
                    final item = LostFoundItem(
                      id: '',
                      title: titleController.text,
                      description: descriptionController.text,
                      type: type,
                      category: category,
                      reporterId: user?.uid ?? 'guest',
                      reporterName: user?.displayName ?? 'Anonymous',
                      createdAt: DateTime.now(),
                    );

                    await ref.read(lostFoundRepositoryProvider).addItem(item);
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class LostFoundList extends ConsumerWidget {
  final LostFoundType type;

  const LostFoundList({super.key, required this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(lostFoundStreamProvider)
        .when(
          data: (items) {
            final filtered = items.where((i) => i.type == type).toList();
            if (filtered.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No ${type.name} items reported yet',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final item = filtered[index];
                return _buildItemCard(context, ref, item);
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => Center(child: Text('Error: $e')),
        );
  }

  Widget _buildItemCard(
    BuildContext context,
    WidgetRef ref,
    LostFoundItem item,
  ) {
    final theme = Theme.of(context);
    final isLost = item.type == LostFoundType.lost;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isLost
              ? Colors.red.withOpacity(0.1)
              : Colors.green.withOpacity(0.1),
          child: Icon(
            isLost ? Icons.warning_amber_rounded : Icons.check_circle_outline,
            color: isLost ? Colors.red : Colors.green,
          ),
        ),
        title: Text(
          item.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    item.category,
                    style: TextStyle(fontSize: 10, color: theme.primaryColor),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  timeago.format(item.createdAt),
                  style: const TextStyle(fontSize: 10),
                ),
              ],
            ),
          ],
        ),
        trailing: item.status == 'resolved'
            ? const Icon(Icons.done_all, color: Colors.blue)
            : null,
      ),
    );
  }
}
