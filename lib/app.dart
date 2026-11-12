import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'config/env.dart';
import 'data/api_client.dart';
import 'data/auth_service.dart';
import 'data/lapticon_api.dart';
import 'features/auth/complete_profile_screen.dart';
import 'features/auth/welcome_screen.dart';
import 'features/shell/main_shell.dart';
import 'features/shell/splash_screen.dart';
import 'state/app_state.dart';
import 'state/session.dart';
import 'theme/app_theme.dart';

class LapticonApp extends StatefulWidget {
  const LapticonApp({
    super.key,
    required this.auth,
    required this.client,
    this.demoBanner = Env.demo,
  });

  final AuthService auth;
  final http.Client client;
  final bool demoBanner;

  @override
  State<LapticonApp> createState() => _LapticonAppState();
}

class _LapticonAppState extends State<LapticonApp> {
  late final LapticonApi _api = LapticonApi(
    ApiClient(
      client: widget.client,
      baseUrl: Env.apiBaseUrl,
      token: widget.auth.token,
    ),
  );
  late final Session _session = Session(auth: widget.auth, api: _api)..start();
  final _revision = Revision();
  final _tab = ShellTab();
  late final _catalog = CityCatalog(_api);

  @override
  void dispose() {
    _session.dispose();
    _revision.dispose();
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MultiProvider(
        providers: [
          Provider.value(value: _api),
          Provider.value(value: _catalog),
          ChangeNotifierProvider.value(value: _session),
          ChangeNotifierProvider.value(value: _revision),
          ChangeNotifierProvider.value(value: _tab),
        ],
        child: MaterialApp(
          title: 'Lapticon',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          locale: const Locale('es'),
          supportedLocales: const [Locale('es')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => widget.demoBanner
              ? Banner(
                  message: 'DEMO',
                  location: BannerLocation.topEnd,
                  child: child,
                )
              : child!,
          home: const AuthGate(),
        ),
      );
}

/// Decide la pantalla raíz según el estado de la sesión.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final status = context.select<Session, SessionStatus>((s) => s.status);
    return switch (status) {
      SessionStatus.loading => const SplashScreen(),
      SessionStatus.signedOut => const WelcomeScreen(),
      SessionStatus.guest => const GuestShell(),
      SessionStatus.needsProfile => const CompleteProfileScreen(),
      SessionStatus.ready => const MainShell(),
    };
  }
}
