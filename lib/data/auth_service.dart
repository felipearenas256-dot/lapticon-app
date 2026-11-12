import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

class AuthUser {
  const AuthUser({required this.uid, this.email});

  final String uid;
  final String? email;
}

class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class AuthService {
  Stream<AuthUser?> get changes;
  AuthUser? get current;
  Future<String?> token({bool forceRefresh = false});
  Future<void> signIn(String email, String password);
  Future<void> register(String email, String password);
  Future<void> sendPasswordReset(String email);
  Future<void> signOut();
}

class FirebaseAuthService implements AuthService {
  FirebaseAuthService() : _auth = FirebaseAuth.instance;

  final FirebaseAuth _auth;

  AuthUser? _map(User? user) =>
      user == null ? null : AuthUser(uid: user.uid, email: user.email);

  @override
  Stream<AuthUser?> get changes => _auth.authStateChanges().map(_map);

  @override
  AuthUser? get current => _map(_auth.currentUser);

  @override
  Future<String?> token({bool forceRefresh = false}) async =>
      _auth.currentUser?.getIdToken(forceRefresh);

  @override
  Future<void> signIn(String email, String password) => _guard(
        () => _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        ),
      );

  @override
  Future<void> register(String email, String password) => _guard(
        () => _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        ),
      );

  @override
  Future<void> sendPasswordReset(String email) =>
      _guard(() => _auth.sendPasswordResetEmail(email: email));

  @override
  Future<void> signOut() => _auth.signOut();

  Future<void> _guard(Future<Object?> Function() action) async {
    try {
      await action();
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(_message(error.code));
    }
  }

  String _message(String code) {
    switch (code) {
      case 'invalid-credential':
      case 'invalid-login-credentials':
      case 'wrong-password':
      case 'user-not-found':
        return 'El correo o la contraseña no son correctos.';
      case 'invalid-email':
        return 'Ese correo no es válido.';
      case 'email-already-in-use':
        return 'Ya existe una cuenta con ese correo. Inicia sesión.';
      case 'weak-password':
        return 'Usa una contraseña de al menos 6 caracteres.';
      case 'user-disabled':
        return 'Esta cuenta está deshabilitada.';
      case 'too-many-requests':
        return 'Demasiados intentos. Espera unos minutos.';
      case 'network-request-failed':
        return 'No pudimos conectarnos. Revisa tu internet.';
      default:
        return 'No pudimos completar la solicitud ($code).';
    }
  }
}

/// Inicio de sesión simulado para el modo demo.
class DemoAuthService implements AuthService {
  final _controller = StreamController<AuthUser?>.broadcast();
  AuthUser? _user;

  void _emit(AuthUser? user) {
    _user = user;
    _controller.add(user);
  }

  @override
  Stream<AuthUser?> get changes async* {
    yield _user;
    yield* _controller.stream;
  }

  @override
  AuthUser? get current => _user;

  @override
  Future<String?> token({bool forceRefresh = false}) async =>
      _user == null ? null : 'token-demo';

  @override
  Future<void> signIn(String email, String password) async =>
      _emit(AuthUser(uid: 'demo-usuario', email: email));

  @override
  Future<void> register(String email, String password) => signIn(email, password);

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> signOut() async => _emit(null);
}

/// Se usa si la app se compila sin configuración: permite explorar las rutas
/// públicas y explica por qué no se puede entrar.
class UnconfiguredAuthService implements AuthService {
  static const _failure = AuthFailure(
    'Esta compilación no tiene la configuración de Firebase.',
  );

  @override
  Stream<AuthUser?> get changes => Stream.value(null);

  @override
  AuthUser? get current => null;

  @override
  Future<String?> token({bool forceRefresh = false}) async => null;

  @override
  Future<void> signIn(String email, String password) => throw _failure;

  @override
  Future<void> register(String email, String password) => throw _failure;

  @override
  Future<void> sendPasswordReset(String email) => throw _failure;

  @override
  Future<void> signOut() async {}
}
