// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:appbanco_scotiabank_ventas/main.dart';

void main() {
  testWidgets('Verificar carga inicial de la aplicación', (WidgetTester tester) async {
    // Inicializamos Supabase con valores ficticios para evitar errores de inicialización
    // durante la ejecución del test de widgets.
    await Supabase.initialize(
      url: 'https://placeholder.supabase.co',
      anonKey: 'placeholder',
    );

    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp(isLoggedIn: false));

    // Verificamos que MyApp se construye correctamente y el árbol de widgets carga.
    expect(find.byType(MyApp), findsOneWidget);
  });
}
