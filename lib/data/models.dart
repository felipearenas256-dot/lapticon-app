// El spec deja sin esquema varias respuestas y algunas omiten campos: por
// ejemplo `/viajes/disponibles` no trae `_id` ni `estado`. Por eso los modelos
// toleran datos ausentes en vez de fallar al convertir el JSON.

String? _text(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

double? _number(dynamic value) {
  if (value is num) return value.toDouble();
  return value == null ? null : double.tryParse(value.toString());
}

DateTime? _date(dynamic value) =>
    value == null ? null : DateTime.tryParse(value.toString());

class Usuario {
  const Usuario({
    required this.uid,
    this.email,
    this.nombre,
    this.apellido,
    this.telefono,
    this.fechaNacimiento,
    this.nacionalidad,
    this.correo,
  });

  factory Usuario.fromJson(Map<String, dynamic> json) => Usuario(
        uid: _text(json['uid']) ?? '',
        email: _text(json['email']),
        nombre: _text(json['nombre']),
        apellido: _text(json['apellido']),
        telefono: _text(json['telefono']),
        fechaNacimiento: _date(json['fechaNacimiento'])?.toUtc(),
        nacionalidad: _text(json['nacionalidad']),
        correo: _text(json['correo']),
      );

  final String uid;
  final String? email;
  final String? nombre;
  final String? apellido;
  final String? telefono;
  final DateTime? fechaNacimiento;
  final String? nacionalidad;
  final String? correo;

  String get nombreCompleto =>
      [nombre, apellido].whereType<String>().join(' ').trim();
}

class Viaje {
  const Viaje({
    this.id,
    this.uid,
    this.numeroVuelo,
    required this.ciudadOrigen,
    required this.ciudadDestino,
    this.fechaViaje,
    this.estado = 'disponible',
    this.nombreUsuario,
    this.afinidad,
  });

  factory Viaje.fromJson(Map<String, dynamic> json) => Viaje(
        id: _text(json['_id'] ?? json['id'] ?? json['viajeId']),
        uid: _text(json['uid']),
        numeroVuelo: _text(json['numeroVuelo']),
        ciudadOrigen: _text(json['ciudadOrigen']) ?? 'Sin origen',
        ciudadDestino: _text(json['ciudadDestino']) ?? 'Sin destino',
        fechaViaje: _date(json['fechaViaje'])?.toUtc(),
        estado: _text(json['estado']) ?? 'disponible',
        nombreUsuario: _text(json['nombreUsuario']),
        afinidad: _number(json['afinidad']),
      );

  final String? id;
  final String? uid;
  final String? numeroVuelo;
  final String ciudadOrigen;
  final String ciudadDestino;

  /// Fecha sin hora, en UTC. Ver `formatDateOnly`.
  final DateTime? fechaViaje;
  final String estado;
  final String? nombreUsuario;

  /// Entre 0 y 1. Solo viene en las sugerencias de `emparejar-viajes`.
  final double? afinidad;

  bool get activo => estado == 'disponible' || estado == 'contactado';

  Viaje copyWith({String? estado}) => Viaje(
        id: id,
        uid: uid,
        numeroVuelo: numeroVuelo,
        ciudadOrigen: ciudadOrigen,
        ciudadDestino: ciudadDestino,
        fechaViaje: fechaViaje,
        estado: estado ?? this.estado,
        nombreUsuario: nombreUsuario,
        afinidad: afinidad,
      );
}

class Encomienda {
  const Encomienda({
    required this.id,
    this.uid,
    required this.ciudadOrigen,
    required this.ciudadDestino,
    this.observaciones,
    this.moneda,
    this.valor,
    this.estado = 'disponible',
    this.viajeroId,
    this.fechaCreacion,
    this.fechaVencimiento,
    this.nombreRemitente,
  });

  factory Encomienda.fromJson(Map<String, dynamic> json) {
    return Encomienda(
      id: _text(json['_id'] ?? json['id']) ?? '',
      uid: _text(json['uid']),
      ciudadOrigen: _text(json['ciudadOrigen']) ?? 'Sin origen',
      ciudadDestino: _text(json['ciudadDestino']) ?? 'Sin destino',
      observaciones: _text(json['observaciones']),
      moneda: _text(json['moneda']),
      valor: _number(json['valor']),
      estado: _text(json['estado']) ?? 'disponible',
      viajeroId: _text(json['viajeroId']),
      fechaCreacion: _date(json['fechaCreacion']),
      fechaVencimiento: _date(json['fechaVencimiento']),
      nombreRemitente: _text(json['remitenteNombre']),
    );
  }

  final String id;
  final String? uid;
  final String ciudadOrigen;
  final String ciudadDestino;
  final String? observaciones;
  final String? moneda;
  final double? valor;
  final String estado;
  final String? viajeroId;
  final DateTime? fechaCreacion;
  final DateTime? fechaVencimiento;
  final String? nombreRemitente;

  Encomienda copyWith({String? estado, String? viajeroId}) => Encomienda(
        id: id,
        uid: uid,
        ciudadOrigen: ciudadOrigen,
        ciudadDestino: ciudadDestino,
        observaciones: observaciones,
        moneda: moneda,
        valor: valor,
        estado: estado ?? this.estado,
        viajeroId: viajeroId ?? this.viajeroId,
        fechaCreacion: fechaCreacion,
        fechaVencimiento: fechaVencimiento,
        nombreRemitente: nombreRemitente,
      );
}

class Rating {
  const Rating({
    this.usuarioOrigen,
    this.usuarioDestino,
    this.rolDestino,
    required this.calificacion,
    this.comentario,
    this.timestamp,
  });

  factory Rating.fromJson(Map<String, dynamic> json) => Rating(
        usuarioOrigen: _text(json['usuarioOrigen']),
        usuarioDestino: _text(json['usuarioDestino']),
        rolDestino: _text(json['rolDestino']),
        calificacion: _number(json['calificacion']) ?? 0,
        comentario: _text(json['comentario']),
        timestamp: _date(json['timestamp']),
      );

  final String? usuarioOrigen;
  final String? usuarioDestino;
  final String? rolDestino;
  final double calificacion;
  final String? comentario;
  final DateTime? timestamp;
}

class RatingResumen {
  const RatingResumen({
    required this.total,
    this.promedio,
    required this.calificaciones,
  });

  factory RatingResumen.fromJson(Map<String, dynamic> json) => RatingResumen(
        total: _number(json['total'])?.toInt() ?? 0,
        promedio: _number(json['promedio']),
        calificaciones: [
          for (final item in (json['calificaciones'] as List? ?? const []))
            if (item is Map<String, dynamic>) Rating.fromJson(item),
        ],
      );

  final int total;
  final double? promedio;
  final List<Rating> calificaciones;
}

class EncomiendasEnRuta {
  const EncomiendasEnRuta({required this.disponibles, required this.tomadas});

  final List<Encomienda> disponibles;
  final List<Encomienda> tomadas;
}
