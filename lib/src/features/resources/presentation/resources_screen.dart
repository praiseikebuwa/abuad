import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/resource_repository.dart';
import '../domain/resource.dart';

class ResourcesScreen extends ConsumerWidget {
  const ResourcesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(resourceRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Academic Resources"),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              // TODO: Implement level filtering
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Filtering coming soon!")),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Resource>>(
        stream: repo.watchResources(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final resources = snapshot.data ?? [];

          if (resources.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    "No resources yet.",
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: resources.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final resource = resources[index];
              return _ResourceCard(resource: resource);
            },
          );
        },
      ),
    );
  }
}

class _ResourceCard extends StatelessWidget {
  final Resource resource;

  const _ResourceCard({required this.resource});

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint("Could not launch $url");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue[50],
          child: const Icon(Icons.description, color: Colors.blue),
        ),
        title: Text(
          resource.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text("${resource.courseCode} • ${resource.level} Lvl"),
        trailing: const Icon(Icons.download_rounded, color: Colors.grey),
        onTap: () => _launchUrl(resource.url),
      ),
    );
  }
}
