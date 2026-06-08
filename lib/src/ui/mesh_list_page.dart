import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../box_session_provider.dart';
import 'mesh_details_page.dart';
import '../../protocol.dart';

class MeshListPage extends StatelessWidget {
  const MeshListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BoxSessionProvider>();
    final activeMeshes = provider.discoveredMeshes.where((m) => m.device != null).toList();
    final cachedMeshes = provider.discoveredMeshes.where((m) => m.device == null).toList();

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
      body: provider.discoveredMeshes.isEmpty
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
          : ListView(
              padding: const EdgeInsets.all(8),
              children: [
                if (activeMeshes.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                    child: Text('Available Meshes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
                  ),
                  ...activeMeshes.map((mesh) => _buildMeshCard(context, provider, mesh)),
                ],
                if (cachedMeshes.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                    child: Text('Saved / Out of Range', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
                  ),
                  ...cachedMeshes.map((mesh) => _buildMeshCard(context, provider, mesh)),
                ]
              ],
            ),
    );
  }

  Widget _buildMeshCard(BuildContext context, BoxSessionProvider provider, MeshData mesh) {
    final isActive = mesh.device != null;
    return Card(
      color: isActive ? Colors.white : Colors.grey.shade100,
      child: ListTile(
        leading: Icon(Icons.hub, size: 40, color: isActive ? Colors.teal : Colors.grey),
        title: Text(mesh.name, style: TextStyle(fontWeight: FontWeight.bold, color: isActive ? Colors.black : Colors.grey)),
        subtitle: Text('${mesh.boxCount} Boxes • ${mesh.itemCount} Items'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          if (mesh.pinHash == 0) {
            _showProvisionDialog(context, provider, mesh);
          } else {
            provider.selectMesh(mesh);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MeshDetailsPage()),
            );
          }
        },
      ),
    );
  }

  void _showProvisionDialog(BuildContext context, BoxSessionProvider provider, MeshData mesh) {
    final meshNameController = TextEditingController();
    final boxNameController = TextEditingController();
    final pinController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Provision Box'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter mesh details and a box name.'),
            const SizedBox(height: 16),
            TextField(
              controller: meshNameController,
              decoration: const InputDecoration(labelText: 'Mesh Name (e.g. Camping)'),
            ),
            TextField(
              controller: boxNameController,
              decoration: const InputDecoration(labelText: 'Box Name (e.g. Kitchen)'),
            ),
            TextField(
              controller: pinController,
              decoration: const InputDecoration(labelText: '4-Digit PIN'),
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () async {
              final meshName = meshNameController.text.trim();
              final boxName = boxNameController.text.trim();
              final pin = pinController.text.trim();
              if (meshName.isEmpty || boxName.isEmpty || pin.length != 4) return;

              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);

              navigator.pop();
              
              scaffoldMessenger.showSnackBar(
                const SnackBar(
                  content: Text('Registering box...'),
                ),
              );

              // We pass the Box Name to the firmware, but the Mesh Name is saved locally on the phone (or as part of a cloud sync later).
              // The firmware only saves the Box Name and the PIN Hash.
              final status = await provider.provisionBox(mesh, boxName, pin);
              if (status == imb_ack_status.ack_ok) {
                 scaffoldMessenger.showSnackBar(
                  const SnackBar(content: Text('Provisioning SUCCESS!')),
                );
              } else {
                scaffoldMessenger.showSnackBar(
                  SnackBar(content: Text('Provisioning FAILED: $status')),
                );
              }
            },
            child: const Text('PROVISION'),
          ),
        ],
      ),
    );
  }
}
