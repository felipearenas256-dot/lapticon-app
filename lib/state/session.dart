import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/api_exception.dart';
import '../data/auth_service.dart';
import '../data/lapticon_api.dart';
import '../data/models.dart';

enum SessionStatus { loading, signedOut, guest, needsProfile, ready }

/// Estado de autenticación y perfil del usuario.
class Session extends ChangeNotifier {
  Session({required this._auth, required this._api});

  final AuthService _auth;
  final LapticonApi _api;

  SessionStatus status = SessionStatus.loading;
  AuthUser? user;
  Usuario? perfil;
  StreamSubscription<AuthUser?>? _subscription;

  /// Evita buscar el perfil mientras el registro todavía lo está creando.
  bool _registering = false;

  bool get isGuest => status == SessionStatus.guest;
  String? get uid => user?.uid;

  String get displayName {
    final name = perfil?.nombreCompleto ?? '';
    return name.isNotEmpty ? name : (user?.email ?? 'Invitado');
  }

  void start() {
    _subscription = _auth.changes.listen(_onUserChanged);
  }

  Future<void> _onUserChanged(AuthUser? next) async {
    user = next;
    if (next == null) {
      perfil = null;
      if (status != SessionStatus.guest) status = SessionStatus.signedOut;
      notifyListeners();
      return;
    }
    if (!_registering) await loadProfile();
  }

  /// Un 404 significa que la cuenta existe en Firebase pero no en el backend.
  /// Otros errores no bloquean la app: el perfil se reintenta desde Perfil.
  Future<void> loadProfile() async {
    final current = user;
    if (current == null) return;
    if (status != SessionStatus.ready) {
      status = SessionStatus.loading;
      notifyListeners();
    }
    try {
      perfil = await _api.perfil(current.uid);
      status = SessionStatus.ready;
    } on ApiException catch (error) {
      status = error.kind == ApiErrorKind.notFound
          ? SessionStatus.needsProfile
          : SessionStatus.ready;
    }
    notifyListeners();
  }

  Future<void> signIn(String email, String password) =>
      _auth.signIn(email, password);

  /// Si la cuenta se crea pero el perfil falla, la sesión queda en
  /// `needsProfile` y el usuario termina de completarlo sin perder su cuenta.
  Future<void> register({
    required String email,
    required String password,
    required Map<String, dynamic> datos,
  }) async {
    _registering = true;
    try {
      await _auth.register(email, password);
      user = _auth.current;
      try {
        perfil = await _api.registrarPerfil({...datos, 'correo': email});
        status = SessionStatus.ready;
      } on ApiException {
        status = SessionStatus.needsProfile;
      }
      notifyListeners();
    } finally {
      _registering = false;
    }
  }

  Future<void> completeProfile(Map<String, dynamic> datos) async {
    perfil = await _api.registrarPerfil({...datos, 'correo': user?.email});
    status = SessionStatus.ready;
    notifyListeners();
  }

  Future<void> updateProfile(Map<String, dynamic> datos) async {
    final current = user;
    if (current == null) return;
    perfil = await _api.actualizarPerfil(current.uid, datos);
    notifyListeners();
  }

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordReset(email);

  void continueAsGuest() {
    status = SessionStatus.guest;
    notifyListeners();
  }

  void leaveGuest() {
    status = SessionStatus.signedOut;
    notifyListeners();
  }

  Future<void> signOut() async {
    status = SessionStatus.signedOut;
    await _auth.signOut();
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
