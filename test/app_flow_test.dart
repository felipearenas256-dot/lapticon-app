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

  testWidgets('la demo limpia arranca sin viajes ni encomiendas',
      (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      LapticonApp(
        auth: DemoAuthService(),
        client: demoClient(latency: Duration.zero, withSampleData: false),
        demoBanner: false,
      ),
    );
    await tester.pumpAndSettle();
    await signIn(tester);

    expect(find.text('Hola, Ana'), findsOneWidget);
    expect(
      find.text('Si vas a viajar, regístralo y lleva una encomienda.'),
      findsOneWidget,
    );
    expect(find.text('No tienes encomiendas activas.'), findsOneWidget);
    expect(find.text('Viajeros para tus encomiendas'), findsNothing);
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

    expect(find.text('3 viajeros disponibles'), findsOneWidget);
    expect(find.text('Ana Gómez'), findsOneWidget);
    expect(find.text('Carlos Ruiz'), findsOneWidget);
    expect(find.text('Lucía Mora'), findsOneWidget);
  });

  testWidgets('el viaje de otro usuario se ofrece y se le envía una encomienda',
      (tester) async {
    await pumpApp(tester);
    await signIn(tester);

    // En Inicio aparecen los viajeros que sirven para mi encomienda publicada.
    await tester.scrollUntilVisible(
      find.text('Viajeros para tus encomiendas'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Viajeros para tus encomiendas'), findsOneWidget);

    await openTab(tester, 'Buscar');
    await tester.tap(find.text('Origen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'bogota');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Bogotá'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Destino (opcional)'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'miami');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Miami'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buscar viajeros'));
    await tester.pumpAndSettle();

    // Mi viaje (AV204) aparece marcado como mío, sin botón para enviarme.
    expect(find.text('2 viajeros disponibles'), findsOneWidget);
    expect(find.text('Tu viaje · así lo ven los demás'), findsOneWidget);

    await tester.tap(find.text('Carlos Ruiz'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enviar encomienda en este viaje'));
    await tester.pumpAndSettle();

    expect(find.text('Para el viaje de Carlos Ruiz'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, '¿Qué vas a enviar?'),
      'Un libro',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Valor'), '10');
    await tester.tap(find.text('Publicar encomienda'));
    await tester.pumpAndSettle();

    expect(
      find.text('Encomienda publicada. Carlos Ruiz la verá en su viaje.'),
      findsOneWidget,
    );
  });

  testWidgets('el viaje recién registrado aparece al buscar su ruta',
      (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      LapticonApp(
        auth: DemoAuthService(),
        client: demoClient(latency: Duration.zero, withSampleData: false),
        demoBanner: false,
      ),
    );
    await tester.pumpAndSettle();
    await signIn(tester);

    Future<void> pick(String field, String text, String city) async {
      await tester.tap(find.text(field).last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, text);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, city));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text('Viajar'));
    await tester.pumpAndSettle();
    await pick('Origen', 'cali', 'Cali');
    await pick('Destino', 'quito', 'Quito');
    await tester.tap(find.byIcon(Icons.event_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ACEPTAR'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Número de vuelo'),
      'AV204',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Registrar viaje'));
    await tester.pumpAndSettle();
    expect(find.text('Disponibles en tu ruta'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await openTab(tester, 'Buscar');
    await pick('Origen', 'cali', 'Cali');
    await pick('Destino (opcional)', 'quito', 'Quito');
    await tester.tap(find.text('Buscar viajeros'));
    await tester.pumpAndSettle();

    expect(find.text('Solo tu viaje va por esta ruta'), findsOneWidget);
    expect(find.text('Tu viaje · así lo ven los demás'), findsOneWidget);
  });

  testWidgets('el remitente ve los viajeros que van por la ruta de su encomienda',
      (tester) async {
    await pumpApp(tester);
    await signIn(tester);
    await openTab(tester, 'Encomiendas');

    await tester.tap(find.text('Documentos en sobre sellado'));
    await tester.pumpAndSettle();

    expect(find.text('2 viajeros van por tu ruta'), findsOneWidget);
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

  testWidgets('remitente y viajero conversan por el chat de la encomienda',
      (tester) async {
    await pumpApp(tester);
    await signIn(tester);
    await openTab(tester, 'Encomiendas');

    await tester.tap(find.text('Regalo de cumpleaños, caja pequeña'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chatear con el viajero'));
    await tester.pumpAndSettle();

    // Conversación previa y datos del viajero.
    expect(find.text('Carlos Ruiz'), findsOneWidget);
    expect(
      find.text('Puede ser en el aeropuerto, puerta 3, a las 6 a. m.'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField), 'Perfecto, allá nos vemos');
    await tester.pump();
    await tester.tap(find.byTooltip('Enviar'));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Perfecto, allá nos vemos'), findsOneWidget);
    expect(find.text('escribiendo…'), findsOneWidget);

    // El viajero responde solo en el modo demo.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('escribiendo…'), findsNothing);
    expect(find.text('Visto'), findsOneWidget);

    // Las respuestas rápidas también envían.
    await tester.tap(find.text('¿Dónde nos vemos?'));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('¿Dónde nos vemos?'), findsNWidgets(2));
  });
}
