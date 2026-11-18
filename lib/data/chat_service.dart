import 'dart:async';

import 'package:flutter/foundation.dart';

/// Un mensaje del chat entre el remitente y el viajero de una encomienda.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.autor,
    required this.texto,
    required this.enviado,
  });

  final String id;

  /// `uid` de quien lo escribió.
  final String autor;
  final String texto;
  final DateTime enviado;
}

/// Datos de la conversación: nombres, quién está escribiendo y hasta cuándo
/// leyó cada participante.
class ChatInfo {
  const ChatInfo({
    this.nombres = const {},
    this.leido = const {},
    this.escribiendo = const {},
  });

  final Map<String, String> nombres;
  final Map<String, DateTime> leido;
  final Map<String, DateTime> escribiendo;

  /// Escribiendo solo cuenta si se avisó hace poco: si la app se cerró a mitad
  /// de un mensaje, el aviso no se queda pegado.
  bool estaEscribiendo(String uid) {
    final desde = escribiendo[uid];
    return desde != null &&
        DateTime.now().difference(desde) < const Duration(seconds: 10);
  }
}

/// Chat uno a uno por encomienda. El servidor de Lapticon no tiene endpoints
/// para enviar ni leer mensajes, así que el chat usa su propio almacenamiento:
/// Firestore en la app real y memoria en el modo demo.
abstract class ChatService {
  /// Crea la conversación si no existe y registra el nombre de quien la abre.
  Future<void> abrir({
    required String chatId,
    required List<String> participantes,
    required String miUid,
    required String miNombre,
  });

  Stream<ChatInfo> info(String chatId);

  /// Mensajes en orden cronológico, del más viejo al más nuevo.
  Stream<List<ChatMessage>> mensajes(String chatId);

  Future<void> enviar(String chatId, String miUid, String texto);

  Future<void> marcarLeido(String chatId, String miUid);

  Future<void> escribiendo(String chatId, String miUid, bool activo);
}

/// Se usa cuando la app no tiene Firebase configurado.
class UnavailableChatService implements ChatService {
  const UnavailableChatService();

  static const _error = ChatUnavailable();

  @override
  Future<void> abrir({
    required String chatId,
    required List<String> participantes,
    required String miUid,
    required String miNombre,
  }) =>
      Future.error(_error);

  @override
  Stream<ChatInfo> info(String chatId) => Stream.error(_error);

  @override
  Stream<List<ChatMessage>> mensajes(String chatId) => Stream.error(_error);

  @override
  Future<void> enviar(String chatId, String miUid, String texto) =>
      Future.error(_error);

  @override
  Future<void> marcarLeido(String chatId, String miUid) async {}

  @override
  Future<void> escribiendo(String chatId, String miUid, bool activo) async {}
}

class ChatUnavailable implements Exception {
  const ChatUnavailable([
    this.message = 'El chat no está disponible en esta versión de la app.',
  ]);

  final String message;

  @override
  String toString() => message;
}

/// Chat en memoria para el modo demo y las pruebas. La otra persona responde
/// sola después de un momento, mostrando antes que está escribiendo.
class DemoChatService implements ChatService {
  DemoChatService({this.replyDelay = const Duration(milliseconds: 1600)}) {
    _seed();
  }

  final Duration replyDelay;
  final _chats = <String, _DemoChat>{};
  int _next = 0;

  static const _nombres = {
    'demo-usuario': 'Ana Gómez',
    'u-carlos': 'Carlos Ruiz',
    'u-lucia': 'Lucía Mora',
    'u-jorge': 'Jorge Peña',
    'u-marta': 'Marta Díaz',
  };

  static const _respuestas = [
    '¡Listo! Te escribo apenas aterrice.',
    'Perfecto, quedamos así.',
    'Va bien empacada, no te preocupes.',
    'Te aviso cuando esté llegando.',
  ];

  void _seed() {
    final hace = DateTime.now().subtract(const Duration(hours: 3));
    final chat = _chat('e2')
      ..participantes = ['demo-usuario', 'u-carlos']
      ..info = ChatInfo(nombres: {..._nombres});
    chat.mensajes.addAll([
      ChatMessage(
        id: 'm${_next++}',
        autor: 'u-carlos',
        texto: 'Hola Ana, ya tomé tu encomienda. Viajo el viernes.',
        enviado: hace,
      ),
      ChatMessage(
        id: 'm${_next++}',
        autor: 'demo-usuario',
        texto: '¡Genial! ¿Dónde te la entrego?',
        enviado: hace.add(const Duration(minutes: 4)),
      ),
      ChatMessage(
        id: 'm${_next++}',
        autor: 'u-carlos',
        texto: 'Puede ser en el aeropuerto, puerta 3, a las 6 a. m.',
        enviado: hace.add(const Duration(minutes: 6)),
      ),
    ]);
  }

  _DemoChat _chat(String id) => _chats.putIfAbsent(id, _DemoChat.new);

  @override
  Future<void> abrir({
    required String chatId,
    required List<String> participantes,
    required String miUid,
    required String miNombre,
  }) async {
    final chat = _chat(chatId);
    if (chat.participantes.isEmpty) chat.participantes = participantes;
    final nombres = {...chat.info.nombres, miUid: miNombre};
    for (final uid in participantes) {
      final conocido = _nombres[uid];
      if (conocido != null) nombres.putIfAbsent(uid, () => conocido);
    }
    chat.update(info: _copy(chat.info, nombres: nombres));
  }

  @override
  Stream<ChatInfo> info(String chatId) =>
      _chat(chatId).watch((chat) => chat.info);

  @override
  Stream<List<ChatMessage>> mensajes(String chatId) =>
      _chat(chatId).watch((chat) => List.unmodifiable(chat.mensajes));

  @override
  Future<void> enviar(String chatId, String miUid, String texto) async {
    final chat = _chat(chatId);
    chat.mensajes.add(
      ChatMessage(
        id: 'm${_next++}',
        autor: miUid,
        texto: texto,
        enviado: DateTime.now(),
      ),
    );
    chat.update();

    final otro = chat.participantes.firstWhere(
      (uid) => uid != miUid,
      orElse: () => '',
    );
    if (otro.isEmpty) return;

    // La otra persona "lee", escribe y responde.
    Timer(replyDelay ~/ 3, () {
      chat.update(
        info: _copy(
          chat.info,
          leido: {...chat.info.leido, otro: DateTime.now()},
          escribiendo: {...chat.info.escribiendo, otro: DateTime.now()},
        ),
      );
    });
    Timer(replyDelay, () {
      chat.mensajes.add(
        ChatMessage(
          id: 'm${_next++}',
          autor: otro,
          texto: _respuestas[_next % _respuestas.length],
          enviado: DateTime.now(),
        ),
      );
      chat.update(
        info: _copy(
          chat.info,
          escribiendo: {...chat.info.escribiendo}..remove(otro),
        ),
      );
    });
  }

  @override
  Future<void> marcarLeido(String chatId, String miUid) async {
    final chat = _chat(chatId);
    chat.update(
      info: _copy(chat.info, leido: {...chat.info.leido, miUid: DateTime.now()}),
    );
  }

  @override
  Future<void> escribiendo(String chatId, String miUid, bool activo) async {}

  ChatInfo _copy(
    ChatInfo info, {
    Map<String, String>? nombres,
    Map<String, DateTime>? leido,
    Map<String, DateTime>? escribiendo,
  }) =>
      ChatInfo(
        nombres: nombres ?? info.nombres,
        leido: leido ?? info.leido,
        escribiendo: escribiendo ?? info.escribiendo,
      );
}

class _DemoChat extends ChangeNotifier {
  List<String> participantes = [];
  ChatInfo info = const ChatInfo();
  final mensajes = <ChatMessage>[];

  void update({ChatInfo? info}) {
    if (info != null) this.info = info;
    notifyListeners();
  }

  /// Emite el valor actual al suscribirse y luego cada cambio.
  Stream<T> watch<T>(T Function(_DemoChat chat) read) {
    late final StreamController<T> controller;
    void emit() => controller.add(read(this));
    controller = StreamController<T>(
      onListen: () {
        emit();
        addListener(emit);
      },
      onCancel: () => removeListener(emit),
    );
    return controller.stream;
  }
}
