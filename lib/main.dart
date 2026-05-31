import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'src/ble_client.dart';
import 'src/box_session_provider.dart';
import 'src/ui/registration_overlay.dart';
import 'protocol.dart';

import 'package:flutter/foundation.dart';
import 'src/mock_ble_client.dart';

void main() {
  // Use MockBleClient for rapid testing if in debug mode or explicitly requested
  const useMock = kDebugMode;
  
  final IBleClient bleClient = useMock 
    ? MockBleClient() 
    : BleClient(pinHash: 0x12345678); 
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BoxSessionProvider(bleClient: bleClient)),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inventory Mesh Box',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const DashboardPage(),
    );
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BoxSessionProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Mesh Box'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (provider.bleClient is MockBleClient && provider.currentMode == imb_op_mode.mode_registration)
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Simulate Tag Drop',
              onPressed: () => (provider.bleClient as MockBleClient).simulateTagDrop('TAG-${DateTime.now().millisecondsSinceEpoch}'),
            ),
          _buildConnectionStatus(provider.bleClient),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildModeCard(context, provider),
                const SizedBox(height: 16),
                if (provider.isRegistrationIncomplete)
                   _buildIncompleteBanner(context, provider),
                const SizedBox(height: 16),
                const Text('Box Inventory', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Expanded(
                  child: provider.registeredItems.isEmpty 
                    ? const Center(child: Text('No items yet. Start registration to add tags.'))
                    : ListView.builder(
                        itemCount: provider.registeredItems.length,
                        itemBuilder: (context, index) {
                          final item = provider.registeredItems[index];
                          return ListTile(
                            leading: const Icon(Icons.inventory_2),
                            title: Text(item.name),
                            subtitle: Text('UID: ${item.uid}'),
                          );
                        },
                      ),
                ),
                _buildActionButtons(context, provider),
              ],
            ),
          ),
          const RegistrationOverlay(),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus(IBleClient client) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Icon(
        client.isAuthenticated ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
        color: client.isAuthenticated ? Colors.green : Colors.red,
      ),
    );
  }

  Widget _buildModeCard(BuildContext context, BoxSessionProvider provider) {
    final modeName = provider.currentMode.toString().split('.').last.replaceAll('mode_', '').toUpperCase();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const Icon(Icons.settings_remote, size: 48, color: Colors.teal),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Current Mode', style: Theme.of(context).textTheme.labelLarge),
                Text(modeName, style: Theme.of(context).textTheme.headlineSmall),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncompleteBanner(BuildContext context, BoxSessionProvider provider) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade800),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning, color: Colors.amber),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Registration is incomplete. Some items need names.'),
          ),
          TextButton(
            onPressed: () => provider.startRegistration(),
            child: const Text('RESUME'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, BoxSessionProvider provider) {
    if (provider.currentMode == imb_op_mode.mode_registration) {
      return ElevatedButton.icon(
        onPressed: provider.hasPendingTags ? null : () => provider.endRegistration(),
        icon: const Icon(Icons.stop),
        label: const Text('END REGISTRATION'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.shade100,
          foregroundColor: Colors.red,
        ),
      );
    } else {
      return ElevatedButton.icon(
        onPressed: () => provider.startRegistration(),
        icon: const Icon(Icons.add),
        label: const Text('START REGISTRATION'),
      );
    }
  }
}
