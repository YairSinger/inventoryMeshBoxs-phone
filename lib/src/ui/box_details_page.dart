import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../box_session_provider.dart';
import '../../protocol.dart';

class BoxDetailsPage extends StatelessWidget {
  final BoxData box;
  
  const BoxDetailsPage({super.key, required this.box});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BoxSessionProvider>();
    final mesh = provider.selectedMesh;
    
    // Filter events for this specific box
    final boxEvents = mesh?.recentEvents.where((e) => e.boxId == box.id).toList() ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(box.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Rename Box',
            onPressed: () => _showRenameBoxDialog(context, provider, box),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Box Identifiers', style: Theme.of(context).textTheme.titleMedium),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.tag),
                      title: const Text('Box ID'),
                      subtitle: Text('0x${box.id.toRadixString(16).toUpperCase()}'),
                      dense: true,
                    ),
                    ListTile(
                      leading: Icon(box.isOnline ? Icons.wifi : Icons.wifi_off, color: box.isOnline ? Colors.green : Colors.grey),
                      title: const Text('Status'),
                      subtitle: Text(box.isOnline ? 'Reachable' : 'Last seen ${box.lastSeen}'),
                      dense: true,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _SectionHeader(title: 'Contained Items', color: Colors.teal, count: box.items.length),
            if (box.items.isEmpty)
               const Padding(
                 padding: EdgeInsets.all(8.0),
                 child: Text('This box is empty.'),
               )
            else
               ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: box.items.length,
                itemBuilder: (context, index) {
                  final item = box.items[index];
                  return ListTile(
                    leading: const Icon(Icons.inventory_2_outlined),
                    title: Text(item.name),
                  );
                },
              ),
            const SizedBox(height: 24),
            _SectionHeader(title: 'Box Activity Log', color: Colors.blue),
            if (boxEvents.isEmpty)
               const Padding(
                 padding: EdgeInsets.all(8.0),
                 child: Text('No recent activity for this box.'),
               )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: boxEvents.length,
                itemBuilder: (context, index) {
                  final event = boxEvents[index];
                  final bool isInsert = event.type == 0;
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      isInsert ? Icons.add_circle_outline : Icons.remove_circle_outline,
                      color: isInsert ? Colors.green : Colors.blueGrey,
                    ),
                    title: Text('${isInsert ? "Inserted" : "Extracted"} ${event.itemName}'),
                    subtitle: Text('Seq ${event.seqId}'),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showRenameBoxDialog(BuildContext context, BoxSessionProvider provider, BoxData box) {
    final controller = TextEditingController(text: box.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Box'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Box Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty || name == box.name) return;
              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              
              navigator.pop();
              final status = await provider.renameBox(name);
              if (status != imb_ack_status.ack_ok) {
                scaffoldMessenger.showSnackBar(
                  SnackBar(content: Text('Rename failed: $status')),
                );
              }
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color color;
  final int? count;
  const _SectionHeader({required this.title, required this.color, this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Container(width: 4, height: 24, color: color),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          if (count != null) ...[
            const SizedBox(width: 8),
            Chip(label: Text('$count'), visualDensity: VisualDensity.compact),
          ],
        ],
      ),
    );
  }
}
