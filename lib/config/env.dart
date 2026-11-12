/// Configuración de compilación.
///
/// Los valores llegan por `--dart-define-from-file=config/firebase.json`,
/// así la clave de Firebase no queda escrita en el código.
class Env {
  const Env._();

  /// El spec declara `lapticon-backend-ed.onrender.com`, pero ese host responde
  /// 404. El backend real es el mismo que sirve `/api-docs`.
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://lapticon-backend.onrender.com',
  );

  static const firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const firebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID');

  /// Con la clave y el proyecto basta para iniciar sesión con correo. El App ID
  /// real solo hace falta si después se agregan otros servicios de Firebase.
  static const firebaseAppId = String.fromEnvironment(
    'FIREBASE_APP_ID',
    defaultValue: '1:000000000000:android:0000000000000000',
  );
  static const firebaseSenderId = String.fromEnvironment(
    'FIREBASE_SENDER_ID',
    defaultValue: '000000000000',
  );

  /// Corre la app contra un backend en memoria, sin red ni Firebase.
  static const demo = bool.fromEnvironment('DEMO');

  static bool get firebaseConfigured =>
      firebaseApiKey.isNotEmpty && firebaseProjectId.isNotEmpty;
}
