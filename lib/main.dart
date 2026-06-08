import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'src/ble_client.dart';
import 'src/box_session_provider.dart';
import 'src/ui/mesh_list_page.dart';
import 'src/mock_ble_client.dart';

void main() {
  const useMock = false;
  
  final IBleClient bleClient = useMock 
    ? MockBleClient() 
    : BleClient(); 
  
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
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const MeshListPage(),
    );
  }
}
