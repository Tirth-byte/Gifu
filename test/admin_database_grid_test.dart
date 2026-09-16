import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gufi/core/services/gufi_backend_store.dart';
import 'package:gufi/features/admin/presentation/admin_database_grid_page.dart';

void main() {
  testWidgets(
    'AdminDatabaseGridPage renders live spreadsheet grid, tools, and tabs',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: AdminDatabaseGridPage())),
      );

      // Initial pump and wait for mock users to populate
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Title and Tabs
      expect(find.text('Database'), findsOneWidget);
      expect(find.text('Users'), findsOneWidget);
      expect(find.text('Audit Logs'), findsOneWidget);

      // Verify Toolbar components
      expect(find.text('Grid view'), findsOneWidget);
      expect(find.textContaining('Sort'), findsOneWidget);
      expect(find.text('Hide fields'), findsOneWidget);
      expect(find.text('Filter'), findsOneWidget);
      expect(find.text('Search'), findsOneWidget);

      // Tap Search to expand search input bar
      await tester.tap(find.text('Search'));
      await tester.pump();
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search users'), findsOneWidget);

      // Close search
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      // Verify Columns in Grid
      expect(find.text('Username'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Verified'), findsAtLeastNWidgets(1));
      expect(find.text('Provider'), findsOneWidget);

      // Switch Tab to Audit Logs
      await tester.tap(find.text('Audit Logs'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify intentional empty state per Spec A & X
      expect(find.text('No admin activity yet'), findsOneWidget);

      // Add a real admin audit log event to store
      GufiBackendStore.instance.addAuditLog(
        action: 'USER_DISABLED',
        adminEmail: 'admin@gufi.app',
        targetEmail: 'user@gufi.app',
      );

      // Tap Refresh icon on toolbar to fetch latest
      await tester.tap(find.byIcon(Icons.refresh_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify Audit Logs Table Headers and Content
      expect(find.text('Timestamp'), findsOneWidget);
      expect(find.text('Admin'), findsOneWidget);
      expect(find.text('Action'), findsOneWidget);
      expect(find.text('Disabled user'), findsOneWidget);
    },
  );
}
