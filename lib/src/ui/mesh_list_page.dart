import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../box_session_provider.dart';
import 'mesh_details_page.dart';

class MeshListPage extends StatelessWidget {
  const MeshListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BoxSessionProvider>();
    final meshes = provider.discoveredMeshes;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Meshes'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => provider.startScan(),
          ),
        ],
      ),
      body: meshes.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Searching for boxes...'),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: meshes.length,
              itemBuilder: (context, index) {
                final mesh = meshes[index];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.hub, size: 40, color: Colors.teal),
                    title: Text(mesh.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${mesh.boxCount} Boxes • ${mesh.itemCount} Items'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      provider.selectMesh(mesh);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const MeshDetailsPage()),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
