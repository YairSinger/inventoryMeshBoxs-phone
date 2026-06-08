import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:inventory_mesh_box_phone/src/box_session_provider.dart';
import 'package:inventory_mesh_box_phone/src/ble_client.dart';
import 'package:inventory_mesh_box_phone/src/ui/mesh_list_page.dart';
import 'package:inventory_mesh_box_phone/src/ui/mesh_details_page.dart';

import 'mesh_ui_test.mocks.dart';

@GenerateMocks([IBleClient])
void main() {
  late MockIBleClient mockBleClient;
  late BoxSessionProvider provider;

  setUp(() {
    mockBleClient = MockIBleClient();
    when(mockBleClient.eventStream).thenAnswer((_) => const Stream.empty());
    provider = BoxSessionProvider(bleClient: mockBleClient);
  });

  Widget createTestWidget(Widget child) {
    return ChangeNotifierProvider<BoxSessionProvider>.value(
      value: provider,
      child: MaterialApp(
        home: child,
      ),
    );
  }

  testWidgets('MeshListPage should show discovered meshes', (WidgetTester tester) async {
    await tester.pumpWidget(createTestWidget(const MeshListPage()));

    expect(find.text('Nearby Meshes'), findsOneWidget);
    expect(find.text('Camping Trip'), findsOneWidget);
    expect(find.text('2 Boxes • 15 Items'), findsOneWidget);
  });

  testWidgets('Tapping a mesh should navigate to details', (WidgetTester tester) async {
    await tester.pumpWidget(createTestWidget(const MeshListPage()));

    await tester.tap(find.text('Camping Trip'));
    // Advance time for the simulated connection delay in selectMesh
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.byType(MeshDetailsPage), findsOneWidget);
    expect(find.text('MISSING ITEMS'), findsOneWidget);
    expect(find.text('Flashlight'), findsOneWidget);
  });

  testWidgets('MeshDetailsPage should show box registry', (WidgetTester tester) async {
    final future = provider.selectMesh(provider.discoveredMeshes.first);
    await tester.pumpWidget(createTestWidget(const MeshDetailsPage()));
    
    // Advance time for simulated connection
    await tester.pump(const Duration(seconds: 1));
    await future;
    await tester.pumpAndSettle();

    expect(find.text('Kitchen Box'), findsOneWidget);
    expect(find.text('Online • 8 Items'), findsOneWidget);
    expect(find.text('Gear Box'), findsOneWidget);
    expect(find.text('Last seen 2 hours ago • 7 Items'), findsOneWidget);
  });
}
