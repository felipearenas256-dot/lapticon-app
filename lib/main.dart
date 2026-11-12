import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app.dart';
import 'config/env.dart';
import 'data/auth_service.dart';
import 'data/demo_backend.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  Intl.defaultLocale = 'es';

  final AuthService auth;
  final http.Client client;

  if (Env.demo) {
    auth = DemoAuthService();
    client = demoClient();
  } else if (Env.firebaseConfigured) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: Env.firebaseApiKey,
        appId: Env.firebaseAppId,
        messagingSenderId: Env.firebaseSenderId,
        projectId: Env.firebaseProjectId,
      ),
    );
    auth = FirebaseAuthService();
    client = http.Client();
  } else {
    auth = UnconfiguredAuthService();
    client = http.Client();
  }

  runApp(LapticonApp(auth: auth, client: client));
}
