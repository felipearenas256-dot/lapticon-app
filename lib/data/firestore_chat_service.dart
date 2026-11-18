import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import 'chat_service.dart';

/// Chat guardado en Cloud Firestore, del mismo proyecto Firebase que la
/// autenticación. Estructura:
///
/// ```text
/// chats/{encomiendaId}
///   participantes: [uidRemitente, uidViajero]
///   nombres:       {uid: nombre}
///   leido:         {uid: fecha}
///   escribiendo:   {uid: fecha | null}
///   ultimoMensaje, actualizado
/// chats/{encomiendaId}/mensajes/{id}
///   autor, texto, enviado
/// ```
///
/// Las reglas de seguridad están en `firestore.rules`: solo los dos
/// participantes leen y escriben su conversación.
class FirestoreChatService implements ChatService {
  FirestoreChatService(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _chat(String id) =>
      _db.collection('chats').doc(id);

  /// Firestore sin activar o con reglas que no lo permiten llega como
  /// `permission-denied` o `failed-precondition`: se explica en lenguaje claro.
  static Object _explain(Object error) {
    if (error is FirebaseException &&
        const {'permission-denied', 'failed-precondition', 'not-found'}
            .contains(error.code)) {
      return const ChatUnavailable(
        'El chat todavía no está activado en el servidor. Pide que activen '
        'Firestore y publiquen las reglas de firestore.rules.',
      );
    }
    return error;
  }

  static Future<T> _guard<T>(Future<T> future) =>
      future.catchError((Object error) => throw _explain(error));

  static Stream<T> _guardStream<T>(Stream<T> stream) => stream.handleError(
        (Object error) => throw _explain(error),
      );

  static DateTime _date(dynamic value) =>
      value is Timestamp ? value.toDate() : DateTime.now();

  static Map<String, DateTime> _dates(dynamic value) => {
        if (value is Map)
          for (final entry in value.entries)
            if (entry.value != null) '${entry.key}': _date(entry.value),
      };

  @override
  Future<void> abrir({
    required String chatId,
    required List<String> participantes,
    required String miUid,
    required String miNombre,
  }) =>
      _guard(
        _chat(chatId).set({
          'participantes': participantes,
          'nombres': {miUid: miNombre},
          'actualizado': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)),
      );

  @override
  Stream<ChatInfo> info(String chatId) =>
      _guardStream(_chat(chatId).snapshots()).map((snapshot) {
        final data = snapshot.data() ?? const {};
        final nombres = data['nombres'];
        return ChatInfo(
          nombres: {
            if (nombres is Map)
              for (final entry in nombres.entries)
                '${entry.key}': '${entry.value}',
          },
          leido: _dates(data['leido']),
          escribiendo: _dates(data['escribiendo']),
        );
      });

  @override
  Stream<List<ChatMessage>> mensajes(String chatId) => _guardStream(
        _chat(chatId)
            .collection('mensajes')
            .orderBy('enviado', descending: true)
            .limit(200)
            .snapshots(),
      ).map(
        (query) => [
          for (final doc in query.docs.reversed)
            ChatMessage(
              id: doc.id,
              autor: '${doc.data()['autor']}',
              texto: '${doc.data()['texto']}',
              enviado: _date(doc.data()['enviado']),
            ),
        ],
      );

  @override
  Future<void> enviar(String chatId, String miUid, String texto) {
    final chat = _chat(chatId);
    final batch = _db.batch()
      ..set(chat.collection('mensajes').doc(), {
        'autor': miUid,
        'texto': texto,
        'enviado': FieldValue.serverTimestamp(),
      })
      ..update(chat, {
        'ultimoMensaje': texto,
        'actualizado': FieldValue.serverTimestamp(),
        'escribiendo.$miUid': null,
        'leido.$miUid': FieldValue.serverTimestamp(),
      });
    return _guard(batch.commit());
  }

  @override
  Future<void> marcarLeido(String chatId, String miUid) =>
      _chat(chatId).update({'leido.$miUid': FieldValue.serverTimestamp()});

  @override
  Future<void> escribiendo(String chatId, String miUid, bool activo) =>
      _chat(chatId).update({
        'escribiendo.$miUid': activo ? FieldValue.serverTimestamp() : null,
      });
}
