import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../box_session_provider.dart';
import '../mock_ble_client.dart';
import '../../protocol.dart';
import 'registration_overlay.dart';
import 'box_details_page.dart';

class MeshDetailsPage extends StatelessWidget {
  const MeshDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BoxSessionProvider>();
    final mesh = provider.selectedMesh;

    if (mesh == null) {
      return const Scaffold(body: Center(child: Text('No mesh selected')));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(mesh.name),
        actions: [
          _ConnectionIndicator(status: provider.connectionStatus),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MeshStatusCard(mesh: mesh),
                const SizedBox(height: 24),
                _SectionHeader(title: 'Missing Items', color: Colors.red, count: mesh.missingItems.length),
                _MissingItemsList(items: mesh.missingItems),
                const SizedBox(height: 24),
                _SectionHeader(title: 'Recent Activity', color: Colors.blue),
                _RecentActivityList(events: mesh.recentEvents),
                const SizedBox(height: 24),
                _SectionHeader(title: 'Registered Boxes', color: Colors.teal, count: mesh.boxes.length),
                _BoxList(boxes: mesh.boxes),
              ],
            ),
          ),
          const RegistrationOverlay(),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (provider.bleClient is MockBleClient)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: FloatingActionButton.small(
                heroTag: 'mockTag',
                onPressed: () => (provider.bleClient as MockBleClient).simulateTagDrop('MOCK-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}'),
                tooltip: 'Simulate Tag Drop',
                backgroundColor: Colors.amber,
                child: const Icon(Icons.nfc),
              ),
            ),
          FloatingActionButton.extended(
            heroTag: 'addItems',
            onPressed: () => provider.startRegistration(),
            label: const Text('Add Items'),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

class _MeshStatusCard extends StatelessWidget {
  final MeshData mesh;
  const _MeshStatusCard({required this.mesh});

  @override
  Widget build(BuildContext context) {
    final bool isOk = mesh.missingItems.isEmpty;
    return Card(
      color: isOk ? Colors.green.shade50 : Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(
              isOk ? Icons.check_circle : Icons.warning,
              size: 48,
              color: isOk ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOk ? 'SYSTEM OK' : 'MISSING ITEMS',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isOk ? Colors.green.shade900 : Colors.orange.shade900,
                  ),
                ),
                Text('Mesh ID: ${mesh.pinHash.toRadixString(16).toUpperCase()}'),
              ],
            ),
          ],
        ),
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

class _MissingItemsList extends StatelessWidget {
  final List<ReportEntry> items;
  const _MissingItemsList({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Text('All registered items are present.'),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return ListTile(
          leading: const Icon(Icons.error_outline, color: Colors.red),
          title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('Expected in Box 0x${item.box_id.toRadixString(16).toUpperCase()}'),
        );
      },
    );
  }
}

class _RecentActivityList extends StatelessWidget {
  final List<LogEntryData> events;
  const _RecentActivityList({required this.events});

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Text('No recent activity logs available.'),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        final bool isInsert = event.type == 0;
        return ListTile(
          dense: true,
          leading: Icon(
            isInsert ? Icons.add_circle_outline : Icons.remove_circle_outline,
            color: isInsert ? Colors.green : Colors.blueGrey,
          ),
          title: Text('${isInsert ? "Inserted" : "Extracted"} ${event.itemName}'),
          subtitle: Text('Box 0x${event.boxId.toRadixString(16).toUpperCase()} • Seq ${event.seqId}'),
        );
      },
    );
  }
}

class _BoxList extends StatelessWidget {
  final List<BoxData> boxes;
  const _BoxList({required this.boxes});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: boxes.length,
      itemBuilder: (context, index) {
        final box = boxes[index];
        return Card(
          child: ListTile(
            leading: Icon(
              box.isOnline ? Icons.inventory_2 : Icons.inventory_2_outlined,
              color: box.isOnline ? Colors.teal : Colors.grey,
            ),
            title: Text(box.name),
            subtitle: Text('${box.isOnline ? "Reachable" : "Last seen ${box.lastSeen}"} • ${box.itemCount} Items'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BoxDetailsPage(box: box),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _ConnectionIndicator extends StatelessWidget {
  final ConnectionStatus status;
  const _ConnectionIndicator({required this.status});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;
    switch (status) {
      case ConnectionStatus.connected:
        icon = Icons.bluetooth_connected;
        color = Colors.green;
        break;
      case ConnectionStatus.connecting:
        icon = Icons.bluetooth_searching;
        color = Colors.orange;
        break;
      case ConnectionStatus.disconnected:
        icon = Icons.bluetooth_disabled;
        color = Colors.red;
        break;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Icon(icon, color: color),
    );
  }
}
