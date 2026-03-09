enum EstadoEvento { validado, pendiente, solicitudEliminacion, cancelado }

// Clase para el chat dentro del evento
class MensajeCalendario {
  final String autor;
  final String texto;
  final DateTime fecha;
  MensajeCalendario({required this.autor, required this.texto, required this.fecha});
}

class Evento {
  final String titulo;
  final DateTime fecha;
  final String categoria; // 'Médico', 'Escuela', 'Ocio', 'Custodia'
  final String creador;
  final String responsable; // Nuevo campo: ¿Quién se encarga?
  final bool esImportante;
  
  // PILAR 3 y 5: Estados y Auditoría
  EstadoEvento estado;
  String? motivoSolicitud; // Por qué se quiere borrar/cambiar
  String? solicitanteCambio; // Quién pide borrarlo
  
  // PILAR 4: Acuse de recibo legal
  DateTime? vistoPorOtro; 
  
  // CHAT INTERNO DEL EVENTO
  List<MensajeCalendario> chat;

  Evento({
    required this.titulo,
    required this.fecha,
    required this.categoria,
    required this.creador,
    this.responsable = 'Compartido',
    this.esImportante = false,
    this.estado = EstadoEvento.validado,
    this.motivoSolicitud,
    this.solicitanteCambio,
    this.vistoPorOtro,
    List<MensajeCalendario>? chat,
  }) : chat = chat ?? [];
}