import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:lapticon/app.dart';
import 'package:lapticon/data/auth_service.dart';
import 'package:lapticon/data/demo_backend.dart';

/// Recorre la app completa contra el backend en memoria.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('es');
    Intl.defaultLocale = 'es';
  });

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      LapticonApp(
        auth: DemoAuthService(),
        client: demoClient(latency: Duration.zero),
        demoBanner: false,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
  }

  Future<void> signIn(WidgetTester tester) async {
    await tester.tap(find.text('Ya tengo cuenta'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Correo'),
      'ana@ejemplo.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Contraseña'),
      'secreto123',
    );
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
  }

  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(NavigationDestination, label));
    await tester.pumpAndSettle();
  }

  testWidgets('sin sesión muestra la bienvenida', (tester) async {
    await pumpApp(tester);

    expect(find.text('Crear cuenta'), findsOneWidget);
    expect(find.text('Explorar sin cuenta'), findsOneWidget);
  });

  testWidgets('valida el formulario de login antes de enviar', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Ya tengo cuenta'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(find.text('Escribe un correo válido'), findsOneWidget);
    expect(find.text('Escribe tu contraseña'), findsOneWidget);
  });

  testWidgets('tras entrar muestra saludo, viaje y encomiendas', (tester) async {
    await pumpApp(tester);
    await signIn(tester);

    expect(find.text('Hola, Ana'), findsOneWidget);
    expect(find.text('Tu próximo viaje'), findsOneWidget);
    expect(find.textContaining('AV204'), findsOneWidget);
  });

  testWidgets('la lista de encomiendas se filtra por estado', (tester) async {
    await pumpApp(tester);
    await signIn(tester);
    await openTab(tester, 'Encomiendas');

    expect(find.text('Documentos en sobre sellado'), findsOneWidget);

    final recibidas = find.widgetWithText(ChoiceChip, 'Recibidas');
    await tester.ensureVisible(recibidas);
    await tester.pumpAndSettle();
    await tester.tap(recibidas);
    await tester.pumpAndSettle();

    expect(find.text('Libros universitarios'), findsOneWidget);
    expect(find.text('Documentos en sobre sellado'), findsNothing);
  });

  testWidgets('el invitado busca viajeros y ve resultados reales de la ruta',
      (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Explorar sin cuenta'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Origen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'bogota');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Bogotá'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Destino'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'miami');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Miami'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Buscar viajeros'));
    await tester.pumpAndSettle();

    expect(find.text('2 viajeros disponibles'), findsOneWidget);
    expect(find.text('Carlos Ruiz'), findsOneWidget);
    expect(find.text('Lucía Mora'), findsOneWidget);
  });

  testWidgets('el invitado no puede buscar sin origen', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Explorar sin cuenta'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Buscar viajeros'));
    await tester.pumpAndSettle();

    expect(find.text('Elige al menos la ciudad de origen.'), findsOneWidget);
  });

  testWidgets('el remitente retira su encomienda sin usar un estado inválido',
      (tester) async {
    await pumpApp(tester);
    await signIn(tester);
    await openTab(tester, 'Encomiendas');

    await tester.tap(find.text('Documentos en sobre sellado'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retirar encomienda'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Retirar'));
    await tester.pumpAndSettle();

    expect(find.text('Encomienda retirada.'), findsOneWidget);
    expect(find.text('Vencida'), findsOneWidget);
    expect(find.text('Retirar encomienda'), findsNothing);
  });

  testWidgets('el viajero ve las sugerencias con su afinidad', (tester) async {
    await pumpApp(tester);
    await signIn(tester);
    await openTab(tester, 'Encomiendas');

    await tester.tap(find.text('Documentos en sobre sellado'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver viajeros sugeridos'));
    await tester.pumpAndSettle();

    expect(find.text('56 % de afinidad'), findsWidgets);
  });

  testWidgets('el asistente explica cuando el servicio falla', (tester) async {
    await pumpApp(tester);
    await signIn(tester);

    await tester.tap(find.byTooltip('Asistente'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Hola');
    await tester.tap(find.byTooltip('Enviar'));
    await tester.pumpAndSettle();

    expect(
      find.text('El asistente no está disponible ahora. Intenta más tarde.'),
      findsOneWidget,
    );
  });

  testWidgets('cerrar sesión vuelve a la bienvenida', (tester) async {
    await pumpApp(tester);
    await signIn(tester);
    await openTab(tester, 'Perfil');

    await tester.scrollUntilVisible(
      find.text('Cerrar sesión'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(IndexedStack),
            matching: find.byType(Scrollable),
          )
          .last,
    );
    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(find.text('Explorar sin cuenta'), findsOneWidget);
  });
}
