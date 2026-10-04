import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mcq/features/products/presentation/product_form_screen.dart';

Widget _wrap() {
  return const ProviderScope(
    child: MaterialApp(home: ProductFormScreen()),
  );
}

Future<void> _pumpForm(WidgetTester tester) async {
  await tester.pumpWidget(_wrap());
  await tester.pump();
}

void main() {
  testWidgets('Foam shows Foam Type, Code, Quantity and Cost Price', (WidgetTester tester) async {
    await _pumpForm(tester);

    expect(find.text('Foam Type'), findsOneWidget);
    expect(find.text('Code (optional)'), findsOneWidget);
    expect(find.text('Quantity'), findsWidgets);
    expect(find.text('Cost / piece (Rs.)'), findsOneWidget);
  });

  testWidgets('Foam hides the product name field and colour rows', (WidgetTester tester) async {
    await _pumpForm(tester);

    expect(find.text('Product Name'), findsNothing);
    expect(find.text('Add Colour'), findsNothing);
  });

  testWidgets('Foam Cover shows Design Number, Picture and colour rows', (WidgetTester tester) async {
    await _pumpForm(tester);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Foam Cover').last);
    await tester.pumpAndSettle();

    expect(find.text('Design Number (optional)'), findsOneWidget);
    expect(find.text('Picture'), findsOneWidget);
    expect(find.text('Add Colour'), findsOneWidget);
    expect(find.text('Foam Type'), findsNothing);
    expect(find.text('Product Name'), findsNothing);
  });

  testWidgets('Pillow Cover shows Design Code and no picture field', (WidgetTester tester) async {
    await _pumpForm(tester);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pillow Cover').last);
    await tester.pumpAndSettle();

    expect(find.text('Design Code (optional)'), findsOneWidget);
    expect(find.text('Add Colour'), findsOneWidget);
    expect(find.text('Picture'), findsNothing);
    expect(find.text('Foam Type'), findsNothing);
  });

  testWidgets('Carpet shows Name, Code, Picture and colour rows', (WidgetTester tester) async {
    await _pumpForm(tester);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Carpet').last);
    await tester.pumpAndSettle();

    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Code (optional)'), findsOneWidget);
    expect(find.text('Picture'), findsOneWidget);
    expect(find.text('Add Colour'), findsOneWidget);
    expect(find.text('Product Name'), findsNothing);
  });
}