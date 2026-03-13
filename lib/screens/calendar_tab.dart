import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:image_picker/image_picker.dart'; // Añadido para Evidencia Documental
import '../services/pdf_service.dart'; // Añadido para el pilar de exportación
import '../screens/finance_tab.dart'; // IMPORTANTE: Para acceder a baseDatosGastosGlobal

// 1. MODELO DE DATOS (Lo definimos aquí para simular la BD)
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
  final String categoria; 
  final String creador;
  final String responsable; 
  final bool esImportante;
  
  EstadoEvento estado;
  String? motivoSolicitud; 
  String? solicitanteCambio; 
  DateTime? vistoPorOtro; 
  List<MensajeCalendario> chat;
  
  // JUGADA 2: EVIDENCIA DOCUMENTAL
  List<String> adjuntos; // Rutas de fotos (informes médicos, notas...)
  List<String> logsTrazabilidad; // "10:00 - Check-in GPS", "10:05 - Foto subida"
  final List<String> ninosAsignados; // REQ 1: Metadato de Niños Implicados
  String? idGastoAsociado;
  List<String> ticketsGasto; // 📸 NUEVO: Memoria visual de los tickets en el evento

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
    List<String>? adjuntos,
    List<String>? logsTrazabilidad,
    List<String>? ninosAsignados,
    this.idGastoAsociado,
    List<String>? ticketsGasto,
  }) : chat = chat ?? [], adjuntos = adjuntos ?? [], logsTrazabilidad = logsTrazabilidad ?? [], ninosAsignados = ninosAsignados ?? [], ticketsGasto = ticketsGasto ?? [];
}

// --- BASE DE DATOS EVENTOS (GLOBAL) ---
Map<DateTime, List<Evento>>? baseDatosEventosGlobal;

class CalendarTab extends StatefulWidget {
  const CalendarTab({super.key});

  @override
  State<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<CalendarTab> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  
  late final Map<DateTime, List<Evento>> _eventos;

  final String miNombre = 'Alberto';
  final String otroNombre = 'Yaiza';

  // JUGADA 4: RBAC (Role-Based Access Control)
  String _rolUsuario = 'admin'; // Valores: 'admin' (Padre/Madre), 'observer' (Abuelo/Mediador)

  // --- CONFIGURACIÓN DE CUSTODIA (Estado) ---
  DateTime _inicioCustodia = DateTime(2024, 1, 1);
  // Patrón por defecto: 2-2-3 (Ciclo de 14 días)
  final List<Map<String, dynamic>> _patronCustodia = [
    {'dias': 2, 'persona': 'Alberto'},
    {'dias': 2, 'persona': 'Yaiza'},
    {'dias': 3, 'persona': 'Alberto'},
    {'dias': 2, 'persona': 'Yaiza'},
    {'dias': 2, 'persona': 'Alberto'},
    {'dias': 3, 'persona': 'Yaiza'},
  ];

  // NUEVO: Mapa para guardar los cambios manuales (Día -> Persona)
  final Map<DateTime, String> _custodiaManual = {};

  // REQ 3: Registro de Alteraciones (Auditoría)
  final List<String> _registroAuditoria = [];

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _inicializarEventos();
  }

  void _inicializarEventos() {
    // Si ya existen datos en memoria global, los usamos en lugar de reiniciar
    if (baseDatosEventosGlobal != null) {
      _eventos = baseDatosEventosGlobal!;
      return;
    }

    final hoy = DateTime.now();
    _eventos = {
      DateTime.utc(hoy.year, hoy.month, hoy.day + 1): [
        Evento(titulo: 'Cita Pediatra Viggo', fecha: hoy.add(const Duration(days: 1)), categoria: 'Médico', creador: 'Alberto', responsable: 'Alberto', esImportante: true),
      ],
      DateTime.utc(hoy.year, hoy.month, hoy.day + 3): [
        Evento(titulo: 'Reunión Tutora Ivy', fecha: hoy.add(const Duration(days: 3)), categoria: 'Escuela', creador: 'Yaiza', responsable: 'Ambos', vistoPorOtro: DateTime.now()),
        Evento(titulo: 'Comprar material', fecha: hoy.add(const Duration(days: 3)), categoria: 'Escuela', creador: 'Alberto', responsable: 'Alberto'),
      ],
      DateTime.utc(hoy.year, hoy.month, hoy.day + 5): [
        Evento(titulo: 'Cumpleaños Abuela', fecha: hoy.add(const Duration(days: 5)), categoria: 'Ocio', creador: 'Alberto', responsable: 'Alberto', estado: EstadoEvento.solicitudEliminacion, solicitanteCambio: 'Alberto', motivoSolicitud: 'Se ha pospuesto por enfermedad', chat: [MensajeCalendario(autor: 'Alberto', texto: 'Lo siento, la abuela está mala, mejor lo quitamos.', fecha: DateTime.now())]),
      ],
    };
    
    // Guardamos la referencia global
    baseDatosEventosGlobal = _eventos;
  }

  List<Evento> _getEventosDelDia(DateTime dia) {
    return _eventos[DateTime.utc(dia.year, dia.month, dia.day)] ?? [];
  }

  // MOTOR DE CUSTODIA DINÁMICO
  String _getCustodio(DateTime dia) {
    // 1. PRIORIDAD: Revisar si hay un cambio manual para este día
    final fechaKey = DateTime.utc(dia.year, dia.month, dia.day);
    if (_custodiaManual.containsKey(fechaKey)) {
      return _custodiaManual[fechaKey]!;
    }

    // 2. FALLBACK: Si no hay cambio manual, usar el patrón matemático
    if (dia.isBefore(_inicioCustodia)) return miNombre; // Fallback para fechas antiguas
    
    int diasDesdeInicio = dia.difference(_inicioCustodia).inDays;
    int totalDiasCiclo = _patronCustodia.fold(0, (sum, item) => sum + (item['dias'] as int));
    if (totalDiasCiclo == 0) return miNombre;

    int diaEnCiclo = diasDesdeInicio % totalDiasCiclo;
    int acumulado = 0;
    
    for (var segmento in _patronCustodia) {
      acumulado += (segmento['dias'] as int);
      if (diaEnCiclo < acumulado) return segmento['persona'];
    }
    return miNombre;
  }

  Color _getColor(String cat) {
    switch (cat) {
      case 'Médico': return Colors.red.shade400;
      case 'Escuela': return Colors.blue.shade400;
      case 'Ocio': return Colors.orange.shade400;
      default: return Colors.teal;
    }
  }

  IconData _getIcono(String cat) {
    switch (cat) {
      case 'Médico': return Icons.local_hospital;
      case 'Escuela': return Icons.school;
      case 'Ocio': return Icons.cake;
      default: return Icons.event;
    }
  }

  // JUGADA 1: SIMULACIÓN DE CHECK-IN GEOPOSICIONADO
  // En producción usarías el paquete 'geolocator' aquí.
  void _registrarCheckInGPS() {
    // 1. Obtener coordenadas (Simulado)
    final ahora = DateTime.now();
    const lat = 40.416775;
    const long = -3.703790;
    
    // 2. Crear el log de trazabilidad
    String log = '📍 ${ahora.hour}:${ahora.minute.toString().padLeft(2,"0")}h - Check-in GPS: Lat $lat, Long $long (Precisión: 12m) realizado por $miNombre';
    
    setState(() {
      // AHORA: Creamos un evento "Técnico" para que quede constancia en el PDF
      final key = DateTime.utc(ahora.year, ahora.month, ahora.day);
      
      final checkInEvento = Evento(
        titulo: '📍 REGISTRO DE PRESENCIA (GPS)',
        fecha: ahora,
        categoria: 'Otro', // Usamos 'Otro' para diferenciarlo de Médico/Escuela
        creador: miNombre,
        responsable: miNombre,
        estado: EstadoEvento.validado, // Nace validado porque es una prueba técnica irrefutable
        logsTrazabilidad: [log, 'Dispositivo ID: KND-USER-${miNombre.toUpperCase()}-001'], // Datos forenses
      );

      if (_eventos[key] != null) {
        _eventos[key]!.add(checkInEvento);
      } else {
        _eventos[key] = [checkInEvento];
      }

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Check-in guardado en el informe forense'), backgroundColor: Colors.indigo));
    });
  }

  // --- FORMULARIO (Mantenemos el tuyo intacto, solo añadimos la lógica del Pilar 3) ---
  void _abrirFormularioEvento() {
    final TextEditingController tituloCtrl = TextEditingController();
    String categoriaSeleccionada = 'Escuela';
    String responsableSeleccionado = miNombre;
    DateTime fechaSeleccionada = _selectedDay ?? DateTime.now();
    TimeOfDay horaSeleccionada = TimeOfDay.now();
    bool esImportante = false;
    // JUGADA 2: Adjuntos en creación
    List<String> rutasAdjuntos = [];
    // REQ 1: Listas para selección de niños
    final List<String> misHijos = ['Viggo', 'Ivy'];
    List<String> ninosSeleccionados = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 20, left: 20, right: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Nuevo Evento', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal)),
                  const SizedBox(height: 15),
                  
                  TextField(
                    controller: tituloCtrl,
                    decoration: const InputDecoration(labelText: 'Título del evento', prefixIcon: Icon(Icons.edit), border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: categoriaSeleccionada,
                          decoration: const InputDecoration(labelText: 'Categoría', border: OutlineInputBorder()),
                          items: ['Médico', 'Escuela', 'Ocio', 'Otro'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                          onChanged: (v) => setModalState(() => categoriaSeleccionada = v!),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: responsableSeleccionado,
                          decoration: const InputDecoration(labelText: 'Responsable', border: OutlineInputBorder()),
                          items: ['Alberto', 'Yaiza', 'Ambos', 'Abuelos'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                          onChanged: (v) => setModalState(() => responsableSeleccionado = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  
                  Row(
                    children: [
                      Expanded(child: OutlinedButton.icon(onPressed: () async { final d = await showDatePicker(context: context, initialDate: fechaSeleccionada, firstDate: DateTime(2020), lastDate: DateTime(2030)); if(d!=null) setModalState(() => fechaSeleccionada = d); }, icon: const Icon(Icons.calendar_today), label: Text('${fechaSeleccionada.day}/${fechaSeleccionada.month}'))),
                      const SizedBox(width: 10),
                      Expanded(child: OutlinedButton.icon(onPressed: () async { final t = await showTimePicker(context: context, initialTime: horaSeleccionada); if(t!=null) setModalState(() => horaSeleccionada = t); }, icon: const Icon(Icons.access_time), label: Text(horaSeleccionada.format(context)))),
                    ],
                  ),
                  
                  SwitchListTile(title: const Text('Marcar como Importante'), value: esImportante, activeThumbColor: Colors.orange, onChanged: (v) => setModalState(() => esImportante = v)),
                  
                  // REQ 1: Selector de Niños
                  const SizedBox(height: 10),
                  const Text('¿A quién afecta?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  Wrap(
                    spacing: 8,
                    children: misHijos.map((hijo) {
                      return FilterChip(
                        label: Text(hijo),
                        selected: ninosSeleccionados.contains(hijo),
                        selectedColor: Colors.teal.shade100,
                        checkmarkColor: Colors.teal,
                        onSelected: (bool selected) {
                          setModalState(() {
                            if (selected) ninosSeleccionados.add(hijo); else ninosSeleccionados.remove(hijo);
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),

                  // JUGADA 2: BOTÓN ADJUNTAR EVIDENCIA
                  OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        final List<XFile> fotos = await ImagePicker().pickMultiImage();
                        if (fotos.isNotEmpty) {
                          if (kIsWeb) await Future.delayed(const Duration(milliseconds: 300)); // Fix congelamiento Web
                          setModalState(() => rutasAdjuntos.addAll(fotos.map((f) => f.path)));
                        }
                      } catch (e) {
                        debugPrint('Error al adjuntar: $e');
                      }
                    },
                    icon: const Icon(Icons.attach_file),
                    label: Text(rutasAdjuntos.isEmpty ? 'Adjuntar Evidencia (Informe/Notas)' : '${rutasAdjuntos.length} Documentos adjuntos (Añadir más)'),
                  ),
                  const SizedBox(height: 10),

                  // 3. Previsualización de Evidencias al Crear Evento
                  if (rutasAdjuntos.isNotEmpty) ...[
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: rutasAdjuntos.length,
                        itemBuilder: (ctx, i) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 10, right: 10),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 80, height: 80,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade300),
                                    image: DecorationImage(image: kIsWeb ? NetworkImage(rutasAdjuntos[i]) : FileImage(File(rutasAdjuntos[i])) as ImageProvider, fit: BoxFit.cover)
                                  ),
                                ),
                                Positioned(
                                  top: -5,
                                  right: -5,
                                  child: GestureDetector(
                                    onTap: () => setModalState(() => rutasAdjuntos.removeAt(i)),
                                    child: const CircleAvatar(radius: 12, backgroundColor: Colors.red, child: Icon(Icons.close, color: Colors.white, size: 14)),
                                  ),
                                )
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white), onPressed: () {
                    if (tituloCtrl.text.isNotEmpty) {
                      // PILAR 3 INYECTADO: Verificamos de quién es el día
                      String custodioDia = _getCustodio(fechaSeleccionada);
                      bool esMiDia = custodioDia == miNombre;
                      EstadoEvento estadoInicial = esMiDia ? EstadoEvento.validado : EstadoEvento.pendiente;
                      
                      // JUGADA 3: DETECTOR DE COLISIONES (Recurrencia vs Custodia)
                      // Simulamos que es un evento semanal. Verificamos si choca en el futuro.
                      bool hayColisionFutura = false;
                      if (!esMiDia) {
                        // Si creo un evento en día que NO es mío, ya es una colisión directa
                        hayColisionFutura = true;
                      }
                      // Aquí iría un bucle for revisando las próximas 4 semanas si fuera recurrente

                      if (hayColisionFutura) {
                        // Warning Forense
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('ALERTA FORENSE: Este evento invade el tiempo de custodia del otro progenitor. Se requiere su validación.'),
                          backgroundColor: Colors.deepOrange,
                          duration: Duration(seconds: 4),
                        ));
                      }

                      final fechaFinal = DateTime(fechaSeleccionada.year, fechaSeleccionada.month, fechaSeleccionada.day, horaSeleccionada.hour, horaSeleccionada.minute);
                      final nuevoEvento = Evento(titulo: tituloCtrl.text, fecha: fechaFinal, categoria: categoriaSeleccionada, creador: miNombre, responsable: responsableSeleccionado, esImportante: esImportante, estado: estadoInicial, adjuntos: rutasAdjuntos, ninosAsignados: ninosSeleccionados);
                      
                      setState(() {
                        final key = DateTime.utc(fechaFinal.year, fechaFinal.month, fechaFinal.day);
                        // Log de creación
                        nuevoEvento.logsTrazabilidad.add('🆕 Creado por $miNombre el ${DateTime.now().toString().substring(0,16)}');
                        if (rutasAdjuntos.isNotEmpty) nuevoEvento.logsTrazabilidad.add('📎 ${rutasAdjuntos.length} documentos adjuntados al inicio.');
                        if (_eventos[key] != null) { _eventos[key]!.add(nuevoEvento); } else { _eventos[key] = [nuevoEvento]; }
                      });
                      
                      if (!esMiDia) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Evento creado en día de $otroNombre. Pendiente de aprobación.'), backgroundColor: Colors.orange));
                      }
                      Navigator.pop(context);
                    }
                  }, child: const Text('Guardar Evento'))),
                  const SizedBox(height: 20),
                ],
              ),
            );
          }
        );
      }
    );
  }

  // --- LÓGICA DE BACKEND (AHORA SIMULADA) ---
  // Este método centraliza el envío. Cuando conectes la BD real, solo tendrás que cambiar el código aquí dentro.
  void _enviarSolicitudCambioCustodia(Map<DateTime, String> cambiosPropuestos) async {
    Navigator.pop(context); // Cerramos el modal visualmente

    // TODO: INTEGRACIÓN CON BASE DE DATOS REAL (Fase Backend)
    // 1. Crear registro en colección 'solicitudes_custodia':
    //    { solicitante: miNombre, cambios: cambiosPropuestos, estado: 'pendiente', fecha: serverTimestamp }
    // 2. Enviar Notificación Push al dispositivo del otro progenitor.
    // 3. NO hacer setState aquí. La app debe esperar a que el Stream de la BD nos avise de que el estado pasó a 'aceptado'.

    // --- INICIO SIMULACIÓN (Para validar el flujo visual ahora) ---
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enviando solicitud a Yaiza...'), duration: Duration(seconds: 1)));
    
    await Future.delayed(const Duration(seconds: 2)); // Simulamos latencia de red

    if (mounted) {
      // Simulamos que la BD nos devuelve "Aceptado" y actualizamos la UI
      setState(() {
        _custodiaManual.addAll(cambiosPropuestos); 
        
        // REQ 2 y 3: Barrido de Eventos Zombis y Auditoría
        final hoyStr = DateTime.now().toString().substring(0, 10);
        cambiosPropuestos.forEach((fecha, nuevoCustodio) {
           // Auditoría
           String fechaAfectada = "${fecha.day}/${fecha.month}/${fecha.year}";
           _registroAuditoria.add("El $hoyStr se acordó modificar la custodia del día $fechaAfectada a favor de $nuevoCustodio");
           
           // Barrido Zombi (Efecto Mariposa)
           if (nuevoCustodio != miNombre) {
             final eventosDia = _getEventosDelDia(fecha);
             for (var evento in eventosDia) {
               if (evento.creador == miNombre && evento.estado == EstadoEvento.validado) {
                 evento.estado = EstadoEvento.pendiente;
                 evento.chat.add(MensajeCalendario(
                   autor: 'SISTEMA', 
                   texto: '⚠️ SISTEMA FORENSE: El día fue cedido tras crear este evento. Requiere re-validación.', 
                   fecha: DateTime.now()
                 ));
               }
             }
           }
        });
      });
      showDialog(
        context: context, 
        builder: (c) => AlertDialog(title: const Text('¡Solicitud Aceptada!'), content: const Text('Yaiza ha aceptado la propuesta de custodia. El calendario se ha actualizado.'), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Genial'))])
      );
    }
    // --- FIN SIMULACIÓN ---
  }

  // --- NUEVO: SOLICITUD RÁPIDA DE DÍA SUELTO (Botón "Solicitar Cambio") ---
  void _solicitarCambioDiaEspecifico(DateTime diaInicial) {
    // Inicializamos listas. Si el día inicial no es mío, lo añado a solicitados por defecto.
    List<DateTime> diasSolicitados = [];
    List<DateTime> diasOfrecidos = [];
    
    if (_getCustodio(diaInicial) != miNombre) {
      diasSolicitados.add(diaInicial);
    } else {
      diasOfrecidos.add(diaInicial);
    }

    DateTime focusedDayDialog = diaInicial;
    
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Lógica de validación: Mismo número de días ofrecidos que solicitados
            bool mismoNumero = diasSolicitados.length == diasOfrecidos.length;
            bool hayDias = diasSolicitados.isNotEmpty && diasOfrecidos.isNotEmpty;
            bool puedeEnviar = mismoNumero && hayDias;

            return AlertDialog(
              title: const Text('Selecciona días para intercambiar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: double.maxFinite,
                height: 500,
                child: Column(
                  children: [
                    const Text('Toca los días para añadir/quitar.\nAzul = Ofreces (Tuyos) | Naranja = Solicitas (Suyos)', style: TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
                    const SizedBox(height: 10),
                    Expanded(
                      child: TableCalendar(
                        locale: 'es_ES',
                        firstDay: DateTime.utc(2023, 1, 1),
                        lastDay: DateTime.utc(2030, 12, 31),
                        focusedDay: focusedDayDialog,
                        currentDay: DateTime.now(),
                        calendarFormat: CalendarFormat.month,
                        headerStyle: const HeaderStyle(titleCentered: true, formatButtonVisible: false),
                        rowHeight: 40,
                        startingDayOfWeek: StartingDayOfWeek.monday,
                        onPageChanged: (focused) => focusedDayDialog = focused,
                        selectedDayPredicate: (day) {
                          return diasSolicitados.any((d) => isSameDay(d, day)) || 
                                 diasOfrecidos.any((d) => isSameDay(d, day));
                        },
                        onDaySelected: (selectedDay, focusedDay) {
                          setDialogState(() {
                            focusedDayDialog = focusedDay;
                            final d = DateTime.utc(selectedDay.year, selectedDay.month, selectedDay.day);
                            String custodio = _getCustodio(d);
                            
                            if (custodio == miNombre) {
                              // Es mío: Lo añado/quito de ofrecidos
                              if (diasOfrecidos.any((dofr) => isSameDay(dofr, d))) {
                                diasOfrecidos.removeWhere((dofr) => isSameDay(dofr, d));
                              } else {
                                diasOfrecidos.add(d);
                              }
                            } else {
                              // Es del otro: Lo añado/quito de solicitados
                              if (diasSolicitados.any((dsol) => isSameDay(dsol, d))) {
                                diasSolicitados.removeWhere((dsol) => isSameDay(dsol, d));
                              } else {
                                diasSolicitados.add(d);
                              }
                            }
                          });
                        },
                        calendarBuilders: CalendarBuilders(
                          defaultBuilder: (_, day, __) {
                            String custodio = _getCustodio(day);
                            bool esMio = custodio == miNombre;
                            return Container(
                              margin: const EdgeInsets.all(4),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: esMio ? Colors.blue.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Text('${day.day}', style: TextStyle(color: esMio ? Colors.blue : Colors.deepOrange)),
                            );
                          },
                          selectedBuilder: (_, day, __) {
                             bool esSolicitado = diasSolicitados.any((d) => isSameDay(d, day));
                             bool esOfrecido = diasOfrecidos.any((d) => isSameDay(d, day));
                             
                             Color bg = Colors.grey;
                             if (esSolicitado) bg = Colors.orange; 
                             if (esOfrecido) bg = Colors.blue; 
                             
                             return Container(
                               margin: const EdgeInsets.all(6),
                               alignment: Alignment.center,
                               decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                               child: Text('${day.day}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                             );
                          },
                          todayBuilder: (_, day, __) {
                            String custodio = _getCustodio(day);
                            bool esMio = custodio == miNombre;
                            return Container(
                              margin: const EdgeInsets.all(4),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: esMio ? Colors.blue.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                                shape: BoxShape.circle,
                                border: Border.all(color: esMio ? Colors.blue : Colors.deepOrange),
                              ),
                              child: Text('${day.day}', style: TextStyle(color: esMio ? Colors.blue : Colors.deepOrange)),
                            );
                          }
                        ),
                      ),
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Text('Das: ${diasOfrecidos.length}', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                        const Icon(Icons.swap_horiz, size: 16, color: Colors.grey),
                        Text('Pides: ${diasSolicitados.length}', style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    if (!mismoNumero && (diasSolicitados.isNotEmpty || diasOfrecidos.isNotEmpty))
                      const Padding(padding: EdgeInsets.only(top: 4), child: Text('Debes intercambiar la misma cantidad.', style: TextStyle(color: Colors.red, fontSize: 11))),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: puedeEnviar ? () {
                    final Map<DateTime, String> cambios = {};
                    for (var d in diasSolicitados) {
                      cambios[DateTime.utc(d.year, d.month, d.day)] = miNombre;
                    }
                    for (var d in diasOfrecidos) {
                      cambios[DateTime.utc(d.year, d.month, d.day)] = otroNombre;
                    }
                    _enviarSolicitudCambioCustodia(cambios);
                  } : null,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                  child: const Text('Enviar Propuesta'),
                )
              ],
            );
          }
        );
      }
    );
  }

  // --- NUEVO: PANTALLA DE CONFIGURACIÓN DE CUSTODIA ---
  void _abrirConfiguracionCustodia() {
    DateTime focusedDayConfig = _focusedDay; // Empezamos viendo el mes actual
    
    // 1. MODO BORRADOR: Trabajamos sobre una copia para no aplicar cambios hasta que se "Envíe la solicitud"
    Map<DateTime, String> draftCustodia = Map.from(_custodiaManual);

    // Helper local para calcular la custodia en el borrador (para que veas cómo queda antes de enviar)
    String getCustodioDraft(DateTime dia) {
      // 1. Miramos en el borrador manual
      final fechaKey = DateTime.utc(dia.year, dia.month, dia.day);
      if (draftCustodia.containsKey(fechaKey)) {
        return draftCustodia[fechaKey]!;
      }
      // 2. Fallback al patrón (usamos la misma lógica que _getCustodio)
      if (dia.isBefore(_inicioCustodia)) return miNombre;
      int diasDesdeInicio = dia.difference(_inicioCustodia).inDays;
      int totalDiasCiclo = _patronCustodia.fold(0, (sum, item) => sum + (item['dias'] as int));
      if (totalDiasCiclo == 0) return miNombre;
      int diaEnCiclo = diasDesdeInicio % totalDiasCiclo;
      int acumulado = 0;
      for (var segmento in _patronCustodia) {
        acumulado += (segmento['dias'] as int);
        if (diaEnCiclo < acumulado) return segmento['persona'];
      }
      return miNombre;
    }

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.9, // Casi pantalla completa
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Editor Visual de Custodia', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
                    ],
                  ),
                  const Text('Toca los días para proponer cambios. No se aplicarán hasta que el otro acepte.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const Divider(),

                  // CALENDARIO INTERACTIVO
                  Expanded(
                    child: TableCalendar(
                      locale: 'es_ES',
                      firstDay: DateTime.utc(2020, 1, 1),
                      lastDay: DateTime.utc(2030, 12, 31),
                      focusedDay: focusedDayConfig,
                      currentDay: DateTime.now(),
                      calendarFormat: CalendarFormat.month,
                      headerStyle: const HeaderStyle(titleCentered: true, formatButtonVisible: false),
                      rowHeight: 40,
                      startingDayOfWeek: StartingDayOfWeek.monday,
                      onPageChanged: (focused) => focusedDayConfig = focused,
                      
                      // AL TOCAR UN DÍA: CAMBIAMOS LA CUSTODIA
                      onDaySelected: (selectedDay, focusedDay) {
                        setModalState(() {
                          focusedDayConfig = focusedDay;
                          final fechaKey = DateTime.utc(selectedDay.year, selectedDay.month, selectedDay.day);
                          
                          // Calculamos quién lo tiene ahora y lo invertimos
                          String actual = getCustodioDraft(selectedDay); // Usamos el draft
                          String nuevo = actual == miNombre ? otroNombre : miNombre;
                          
                          // Guardamos el cambio en el borrador
                          draftCustodia[fechaKey] = nuevo;
                        });
                      },
                      
                      // USAMOS EL MISMO CONSTRUCTOR VISUAL QUE EN LA PANTALLA PRINCIPAL
                      calendarBuilders: CalendarBuilders(
                        defaultBuilder: (_, day, __) => _buildCustodyDay(day, false, calculator: getCustodioDraft),
                        todayBuilder: (_, day, __) => _buildCustodyDay(day, false, isToday: true, calculator: getCustodioDraft),
                        selectedBuilder: (_, day, __) => _buildCustodyDay(day, false, calculator: getCustodioDraft),
                      ),
                    ),
                  ),

                  // LEYENDA
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildLegendItem(miNombre, Colors.blue.shade100),
                        const SizedBox(width: 20),
                        _buildLegendItem(otroNombre, Colors.orange.shade100),
                      ],
                    ),
                  ),

                  // BOTÓN PARA EL MODO AVANZADO (PATRONES)
                  TextButton.icon(
                    onPressed: () => _abrirConfiguracionPatron(context),
                    icon: const Icon(Icons.settings_suggest, size: 16, color: Colors.grey),
                    label: const Text('Configurar Patrón Recurrente (Avanzado)', style: TextStyle(color: Colors.grey)),
                  ),
                  
                  const SizedBox(height: 10),
                  // BOTÓN DE ENVIAR SOLICITUD (EL QUE PEDÍAS)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () => _enviarSolicitudCambioCustodia(draftCustodia),
                      icon: const Icon(Icons.send_rounded),
                      label: const Text('ENVIAR SOLICITUD AL OTRO PROGENITOR'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, elevation: 3),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          }
        );
      }
    );
  }

  // --- CONFIGURACIÓN DE PATRONES (MOVIDO A UN DIÁLOGO SECUNDARIO) ---
  void _abrirConfiguracionPatron(BuildContext parentContext) {
    showModalBottomSheet(
      context: parentContext, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 20, left: 20, right: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Patrón Base Recurrente', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal)),
                  const SizedBox(height: 10),
                  const Text('Define la regla general (ej. 2-2-3). Los cambios manuales que hagas en el calendario visual tendrán prioridad sobre esto.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 20),

                  // FECHA INICIO
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(backgroundColor: Colors.teal, child: Icon(Icons.calendar_today, color: Colors.white)),
                    title: const Text('Fecha de inicio del ciclo', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${_inicioCustodia.day}/${_inicioCustodia.month}/${_inicioCustodia.year}'),
                    trailing: TextButton(
                      onPressed: () async {
                        final d = await showDatePicker(context: context, initialDate: _inicioCustodia, firstDate: DateTime(2000), lastDate: DateTime(2030));
                        if (d != null) setModalState(() => _inicioCustodia = d);
                      },
                      child: const Text('CAMBIAR'),
                    ),
                  ),
                  const Divider(),
                  
                  // LISTA DE TRAMOS
                  const Text('Secuencia del ciclo:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 250),
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(8)),
                    child: ReorderableListView(
                      shrinkWrap: true,
                      children: [
                        for (int i = 0; i < _patronCustodia.length; i++)
                          ListTile(
                            key: ValueKey(i), // Clave única para reordenar
                            dense: true,
                            leading: CircleAvatar(
                              backgroundColor: _patronCustodia[i]['persona'] == miNombre ? Colors.blue.shade100 : Colors.orange.shade100,
                              child: Text('${_patronCustodia[i]['dias']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                            ),
                            title: Text('${_patronCustodia[i]['dias']} días con ${_patronCustodia[i]['persona']}'),
                            trailing: IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red), onPressed: () => setModalState(() => _patronCustodia.removeAt(i))),
                          )
                      ],
                      onReorder: (oldIndex, newIndex) {
                        setModalState(() {
                          if (oldIndex < newIndex) newIndex -= 1;
                          final item = _patronCustodia.removeAt(oldIndex);
                          _patronCustodia.insert(newIndex, item);
                        });
                      },
                    ),
                  ),
                  
                  // BOTÓN AÑADIR TRAMO
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () {
                      int dias = 2; String persona = miNombre;
                      showDialog(context: context, builder: (dialogContext) => StatefulBuilder(builder: (innerContext, setD) => AlertDialog(title: const Text('Añadir tramo'), content: Column(mainAxisSize: MainAxisSize.min, children: [Row(children: [const Text('Días: '), IconButton(onPressed: () => setD(() { if(dias>1) dias--; }), icon: const Icon(Icons.remove)), Text('$dias', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), IconButton(onPressed: () => setD(() => dias++), icon: const Icon(Icons.add))]), const SizedBox(height: 10), DropdownButton<String>(value: persona, isExpanded: true, items: [miNombre, otroNombre].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(), onChanged: (v) => setD(() => persona = v!))]), actions: [TextButton(onPressed: () => Navigator.pop(innerContext), child: const Text('Cancelar')), ElevatedButton(onPressed: () { setModalState(() => _patronCustodia.add({'dias': dias, 'persona': persona})); Navigator.pop(innerContext); }, child: const Text('Añadir'))])));
                    },
                    icon: const Icon(Icons.add), label: const Text('Añadir tramo al ciclo'), style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 45)),
                  ),

                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity, height: 50,
                    child: ElevatedButton(
                      onPressed: () { setState(() {}); Navigator.pop(context); }, 
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                      child: const Text('Guardar Configuración'),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          }
        );
      }
    );
  }

  void _solicitarEliminacion(Evento evento) {
    TextEditingController motivoCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Solicitar Eliminación'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('En Kindu nada se borra unilateralmente. Se enviará una solicitud al otro progenitor para que acepte la eliminación.', style: TextStyle(fontSize: 12, color: Colors.black87)),
            const SizedBox(height: 10),
            TextField(controller: motivoCtrl, decoration: const InputDecoration(labelText: 'Motivo (Obligatorio)', border: OutlineInputBorder(), hintText: 'Ej: Cambio de planes, error...')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Volver')),
          ElevatedButton(onPressed: () {
            if (motivoCtrl.text.isNotEmpty) {
              setState(() {
                // 1. Alerta Forense de "Fuera de Plazo"
                bool fueraDePlazo = DateTime.now().isAfter(evento.fecha);
                String suffix = fueraDePlazo ? " [ALERTA FORENSE: Acción realizada FUERA DE PLAZO. El evento ya había finalizado]." : "";

                evento.estado = EstadoEvento.solicitudEliminacion;
                evento.solicitanteCambio = miNombre;
                evento.motivoSolicitud = motivoCtrl.text;
                evento.chat.add(MensajeCalendario(autor: miNombre, texto: 'Solicitud de borrado: ${motivoCtrl.text}$suffix', fecha: DateTime.now()));
                if (fueraDePlazo) evento.logsTrazabilidad.add("Solicitud de borrado FUERA DE PLAZO el ${DateTime.now()}");
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Solicitud enviada a $otroNombre'), backgroundColor: Colors.orange));
            }
          }, style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: const Text('Enviar Solicitud'))
        ],
      )
    );
  }

  // --- DETALLE DEL EVENTO (He restaurado 100% tu UI) ---
  void _mostrarDetalleEvento(Evento evento) {
    TextEditingController chatCtrl = TextEditingController();
    bool esObserver = _rolUsuario == 'observer'; // JUGADA 4
    
    if (evento.creador != miNombre && evento.vistoPorOtro == null) {
      setState(() { evento.vistoPorOtro = DateTime.now(); });
    }

    // 🔄 ANTI-ZOMBI: Validación en Tiempo Real al abrir el detalle
    if (evento.idGastoAsociado != null) {
      int index = baseDatosGastosGlobal.indexWhere((g) => g.titulo == evento.idGastoAsociado);
      if (index == -1) {
        // Ya no existe en finanzas. Limpieza total.
        setState(() {
          evento.idGastoAsociado = null;
          evento.ticketsGasto.clear();
          evento.logsTrazabilidad.add('🗑️ ALERTA: Sistema detectó la eliminación del gasto en Finanzas el ${DateTime.now().toString().substring(0,16)}');
        });
      } else {
        // Sincronización de tickets en espejo con DETECCIÓN DE BORRADO
        int numTicketsAnterior = evento.ticketsGasto.length;
        int numTicketsNuevo = baseDatosGastosGlobal[index].rutasAdjuntos.length;
        
        setState(() {
          evento.ticketsGasto = List.from(baseDatosGastosGlobal[index].rutasAdjuntos);
          
          // Si detectamos que hay menos tickets que antes, alguien borró un ticket en Finanzas
          if (numTicketsNuevo < numTicketsAnterior) {
            evento.logsTrazabilidad.add('🗑️ ALERTA: Ticket económico eliminado desde Finanzas el ${DateTime.now().toString().substring(0,16)}');
            _registroAuditoria.add("🗑️ Evento '${evento.titulo}': Evidencia económica (ticket) eliminada desde Finanzas.");
          }
        });
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            bool haySolicitudBorrado = evento.estado == EstadoEvento.solicitudEliminacion;
            bool soyElSolicitante = evento.solicitanteCambio == miNombre;

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20), // Padding interno para que el scroll no corte el contenido
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(evento.titulo, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.teal))),
                        if (evento.estado == EstadoEvento.validado && !esObserver) // RBAC: Observer no borra
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () {
                              Navigator.pop(context);
                              _solicitarEliminacion(evento);
                            },
                            tooltip: 'Solicitar Borrado',
                          )
                      ],
                    ),
                    Text('${evento.fecha.day}/${evento.fecha.month} a las ${evento.fecha.hour}:${evento.fecha.minute.toString().padLeft(2,'0')}', style: const TextStyle(fontSize: 16, color: Colors.grey)),
                    const SizedBox(height: 10),
                    
                    // TU LISTTILE RESTAURADO
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.info_outline, color: Colors.teal),
                      title: Text('Responsable: ${evento.responsable}'),
                      subtitle: Text('Estado actual: ${evento.estado.name.toUpperCase()}'),
                    ),
                    const Divider(),
              
                    // JUGADA 2: VISUALIZACIÓN DE EVIDENCIA DOCUMENTAL
                    if (evento.adjuntos.isNotEmpty) ...[
                      const Text('📎 Evidencia Documental (Informes/Notas)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 5),
                      SizedBox(
                        height: 100, // Altura aumentada para que quepa el botón de borrar
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: evento.adjuntos.length,
                          // 4. Evidencias Ampliables a Pantalla Completa (Zoom)
                          itemBuilder: (ctx, i) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 10, right: 15),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => Dialog(
                                          backgroundColor: Colors.black87,
                                          insetPadding: EdgeInsets.zero,
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              InteractiveViewer(child: kIsWeb ? Image.network(evento.adjuntos[i]) : Image.file(File(evento.adjuntos[i]))),
                                              Positioned(top: 40, right: 20, child: IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 30), onPressed: () => Navigator.pop(ctx))),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      width: 80, height: 80,
                                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300), image: DecorationImage(image: kIsWeb ? NetworkImage(evento.adjuntos[i]) : FileImage(File(evento.adjuntos[i])) as ImageProvider, fit: BoxFit.cover)),
                                    ),
                                  ),
                                  if (!esObserver)
                                    Positioned(
                                      top: -8,
                                      right: -8,
                                      child: GestureDetector(
                                        onTap: () {
                                          setModalState(() {
                                            evento.adjuntos.removeAt(i);
                                            evento.logsTrazabilidad.add('🗑️ Evidencia eliminada por $miNombre el ${DateTime.now().toString().substring(0,16)}');
                                          });
                                        },
                                        child: const CircleAvatar(radius: 14, backgroundColor: Colors.white, child: CircleAvatar(radius: 12, backgroundColor: Colors.red, child: Icon(Icons.close, color: Colors.white, size: 14))),
                                      ),
                                    )
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    
                    // Botón para añadir más evidencia (Solo si no es observer)
                    if (!esObserver)
                      OutlinedButton.icon(
                        onPressed: () async {
                          try {
                            final List<XFile> fotos = await ImagePicker().pickMultiImage();
                            if (fotos.isNotEmpty) {
                              if (kIsWeb) await Future.delayed(const Duration(milliseconds: 300));
                              setModalState(() { 
                                evento.adjuntos.addAll(fotos.map((f) => f.path)); 
                                evento.logsTrazabilidad.add('📎 ${fotos.length} documentos añadidos por $miNombre el ${DateTime.now().toString().substring(0,16)}');
                              });
                            }
                          } catch (e) {
                            debugPrint('Error: $e');
                          }
                        },
                        icon: const Icon(Icons.add_a_photo, size: 16), label: const Text('Añadir Evidencia'), style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact)),
              
                    if (haySolicitudBorrado)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.red.shade200)),
                        child: Column(
                          children: [
                            Row(children: [
                              const Icon(Icons.warning_amber_rounded, color: Colors.red),
                              const SizedBox(width: 10),
                              Expanded(child: Text(soyElSolicitante ? 'Has solicitado borrar este evento.' : '$otroNombre quiere borrar este evento.', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)))
                            ]),
                            const SizedBox(height: 5),
                            Text('Motivo: "${evento.motivoSolicitud}"', style: const TextStyle(fontStyle: FontStyle.italic)),
                            const SizedBox(height: 10),
                            if (!soyElSolicitante) 
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(onPressed: () {
                                    setState(() {
                                      // 1. Alerta Forense de "Fuera de Plazo"
                                      bool fueraDePlazo = DateTime.now().isAfter(evento.fecha);
                                      String suffix = fueraDePlazo ? " [ALERTA FORENSE: Acción realizada FUERA DE PLAZO. El evento ya había finalizado]." : "";
                                      
                                      evento.estado = EstadoEvento.validado; 
                                      evento.chat.add(MensajeCalendario(autor: miNombre, texto: 'He rechazado la eliminación. El evento se mantiene.$suffix', fecha: DateTime.now()));
                                      if (fueraDePlazo) evento.logsTrazabilidad.add("⚠️ Rechazo de eliminación FUERA DE PLAZO el ${DateTime.now()}");
              
                                      evento.solicitanteCambio = null;
                                      evento.motivoSolicitud = null;
                                    });
                                    Navigator.pop(context);
                                  }, child: const Text('Rechazar', style: TextStyle(color: Colors.grey))),
                                  ElevatedButton(onPressed: () {
                                    setState(() {
                                      // 1. Alerta Forense de "Fuera de Plazo"
                                      bool fueraDePlazo = DateTime.now().isAfter(evento.fecha);
                                      String suffix = fueraDePlazo ? " [ALERTA FORENSE: Acción realizada FUERA DE PLAZO. El evento ya había finalizado]." : "";
              
                                      evento.estado = EstadoEvento.cancelado; 
                                      evento.chat.add(MensajeCalendario(autor: miNombre, texto: 'He aceptado la eliminación.$suffix', fecha: DateTime.now()));
                                      if (fueraDePlazo) evento.logsTrazabilidad.add("⚠️ Aceptación de eliminación FUERA DE PLAZO el ${DateTime.now()}");
                                    });
                                    Navigator.pop(context);
                                  }, style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: const Text('Aceptar Eliminación')),
                                ],
                              )
                            else
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      // 1. Alerta Forense de "Fuera de Plazo"
                                      bool fueraDePlazo = DateTime.now().isAfter(evento.fecha);
                                      String suffix = fueraDePlazo ? " [ALERTA FORENSE: Acción realizada FUERA DE PLAZO. El evento ya había finalizado]." : "";
                                      
                                      evento.estado = EstadoEvento.validado; 
                                      evento.chat.add(MensajeCalendario(autor: miNombre, texto: 'He cancelado la solicitud. Al final el evento se mantiene.$suffix', fecha: DateTime.now()));
                                      if (fueraDePlazo) evento.logsTrazabilidad.add("Cancelación de solicitud FUERA DE PLAZO el ${DateTime.now()}");
              
                                      evento.solicitanteCambio = null;
                                      evento.motivoSolicitud = null;
                                    });
                                    Navigator.pop(context);
                                  },
                                  icon: const Icon(Icons.restore, size: 18),
                                  label: const Text('Cancelar mi solicitud'),
                                  style: OutlinedButton.styleFrom(foregroundColor: Colors.teal, side: const BorderSide(color: Colors.teal)),
                                ),
                              ),
                          ],
                        ),
                      ),
              
                  // TRAZABILIDAD (LOGS)
                  if (evento.logsTrazabilidad.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text('📜 Trazabilidad Forense', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: evento.logsTrazabilidad.map((log) => Text(log, style: const TextStyle(fontSize: 10, fontFamily: 'Monospace'))).toList()),
                    )
                  ],
              
                  const SizedBox(height: 15),
                  
                  // ENLACE CON GASTOS (TRAZABILIDAD ECONÓMICA)
                  if (evento.idGastoAsociado == null)
                    OutlinedButton.icon(
                      onPressed: () {
                        TextEditingController importeCtrl = TextEditingController();
                        TextEditingController conceptoCtrl = TextEditingController(text: evento.titulo);
                        List<String> ticketsGasto = [];

                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                          builder: (dCtx) {
                            return StatefulBuilder(
                              builder: (innerContext, setSheetState) {
                                return Padding(
                                  padding: EdgeInsets.only(bottom: MediaQuery.of(innerContext).viewInsets.bottom, top: 20, left: 20, right: 20),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('Generar Gasto Compartido', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal)),
                                      const SizedBox(height: 10),
                                      const Text('Se creará un registro en Finanzas vinculado a este evento.', style: TextStyle(color: Colors.grey)),
                                      const SizedBox(height: 20),
                                      TextField(
                                        controller: conceptoCtrl,
                                        decoration: const InputDecoration(labelText: 'Concepto', border: OutlineInputBorder(), prefixIcon: Icon(Icons.description)),
                                      ),
                                      const SizedBox(height: 15),
                                      TextField(
                                        controller: importeCtrl,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        decoration: const InputDecoration(labelText: 'Importe (€)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.euro)),
                                      ),
                                      const SizedBox(height: 15),
                                      OutlinedButton.icon(
                                        onPressed: () async {
                                          try {
                                            final List<XFile> fotos = await ImagePicker().pickMultiImage();
                                            if (kIsWeb) await Future.delayed(const Duration(milliseconds: 500));
                                            if (fotos.isNotEmpty) {
                                              setSheetState(() {
                                                ticketsGasto.addAll(fotos.map((f) => f.path));
                                              });
                                            }
                                          } catch (e) {
                                            debugPrint('Error picker: $e');
                                          }
                                        },
                                        icon: const Icon(Icons.camera_alt),
                                        label: Text(ticketsGasto.isEmpty ? 'Adjuntar Tickets/Facturas' : '${ticketsGasto.length} Tickets adjuntos'),
                                      ),
                                      if (ticketsGasto.isNotEmpty) ...[
                                        const SizedBox(height: 15),
                                        SizedBox(
                                          height: 80,
                                          child: ListView.builder(
                                            scrollDirection: Axis.horizontal,
                                            itemCount: ticketsGasto.length,
                                            itemBuilder: (ctx, i) {
                                              return Padding(
                                                padding: const EdgeInsets.only(right: 12.0, top: 8.0),
                                                child: Stack(
                                                  clipBehavior: Clip.none,
                                                  children: [
                                                    GestureDetector(
                                                      onTap: () {
                                                        showDialog(
                                                          context: context,
                                                          builder: (ctx) => Dialog(
                                                            backgroundColor: Colors.black87,
                                                            insetPadding: EdgeInsets.zero,
                                                            child: Stack(
                                                              alignment: Alignment.center,
                                                              children: [
                                                                InteractiveViewer(
                                                                  child: kIsWeb 
                                                                    ? Image.network(ticketsGasto[i], errorBuilder: (c,e,s) => const Icon(Icons.broken_image, color: Colors.white, size: 50)) 
                                                                    : Image.file(File(ticketsGasto[i]), errorBuilder: (c,e,s) => const Icon(Icons.broken_image, color: Colors.white, size: 50))
                                                                ),
                                                                Positioned(top: 40, right: 20, child: IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 30), onPressed: () => Navigator.pop(ctx))),
                                                              ],
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                      child: Container(
                                                        width: 80, height: 80,
                                                        decoration: BoxDecoration(
                                                          borderRadius: BorderRadius.circular(8),
                                                          border: Border.all(color: Colors.grey.shade300),
                                                        ),
                                                        child: ClipRRect(
                                                          borderRadius: BorderRadius.circular(8),
                                                          child: kIsWeb 
                                                            ? Image.network(ticketsGasto[i], fit: BoxFit.cover, errorBuilder: (c,e,s) => const Icon(Icons.image_not_supported, color: Colors.grey)) 
                                                            : Image.file(File(ticketsGasto[i]), fit: BoxFit.cover, errorBuilder: (c,e,s) => const Icon(Icons.image_not_supported, color: Colors.grey)),
                                                        ),
                                                      ),
                                                    ),
                                                    Positioned(
                                                      top: -8,
                                                      right: -8,
                                                      child: GestureDetector(
                                                        onTap: () => setSheetState(() => ticketsGasto.removeAt(i)),
                                                        child: const CircleAvatar(radius: 12, backgroundColor: Colors.red, child: Icon(Icons.close, color: Colors.white, size: 14)),
                                                      ),
                                                    )
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                        )
                                      ],
                                      const SizedBox(height: 25),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: () {
                                            if (importeCtrl.text.isNotEmpty) {
                                              String catFinanzas = 'Otro';
                                              if (evento.categoria == 'Médico') catFinanzas = 'Salud';
                                              if (evento.categoria == 'Escuela') catFinanzas = 'Educación';
                                              if (evento.categoria == 'Ocio') catFinanzas = 'Ocio';

                                              double total = double.tryParse(importeCtrl.text.replaceAll(',', '.')) ?? 0.0;
                                              
                                              // 🆔 GENERAMOS EL ID AQUÍ PARA ENLAZARLO
                                              String nuevoIdGasto = 'G-${DateTime.now().millisecondsSinceEpoch}';
                                              
                                              final nuevoGasto = Gasto(
                                                id: nuevoIdGasto,
                                                titulo: conceptoCtrl.text,
                                                total: total,
                                                miParte: total / 2, 
                                                porcentaje: 50.0,
                                                soyDeudor: false,
                                                creador: miNombre,
                                                categoria: catFinanzas,
                                                fecha: evento.fecha,
                                                esRecurrente: false,
                                                esExtraordinario: false,
                                                ninosAsignados: evento.ninosAsignados,
                                                rutasAdjuntos: ticketsGasto,
                                                enDisputa: false,
                                                esCobroIntegro: false
                                              );

                                              baseDatosGastosGlobal.insert(0, nuevoGasto);

                                              setModalState(() {
                                                evento.idGastoAsociado = conceptoCtrl.text;
                                                evento.logsTrazabilidad.add("💸 Gasto de ${importeCtrl.text}€ generado con ${ticketsGasto.length} tickets adjuntos el ${DateTime.now().toString().substring(0,16)}");
                                                evento.ticketsGasto = List.from(ticketsGasto);
                                              });
                                              setState(() {
                                                _registroAuditoria.add("💸 Evento '${evento.titulo}': Gasto de ${importeCtrl.text}€ generado con evidencia.");
                                              });
                                              Navigator.pop(dCtx);
                                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gasto vinculado correctamente'), backgroundColor: Colors.teal));
                                            }
                                          },
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                                          child: const Text('Guardar'),
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                    ],
                                  ),
                                );
                              }
                            );
                          }
                        );
                      },
                      icon: const Icon(Icons.receipt_long, color: Colors.teal),
                      label: const Text('Generar Gasto Compartido', style: TextStyle(color: Colors.teal)),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.teal)),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.shade200)),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green),
                              const SizedBox(width: 10),
                              const Expanded(child: Text("Gasto asociado registrado en Finanzas.", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12))),
                              if (!esObserver)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: () {
                                    setModalState(() {
                                      baseDatosGastosGlobal.removeWhere((g) => g.titulo == evento.idGastoAsociado);
                                      evento.idGastoAsociado = null;
                                      evento.ticketsGasto.clear();
                                      evento.logsTrazabilidad.add('🗑️ Gasto eliminado desde el calendario el ${DateTime.now().toString().substring(0,16)}');
                                    });
                                    setState(() => _registroAuditoria.add("🗑️ Evento '${evento.titulo}': Gasto eliminado."));
                                  },
                                )
                            ],
                          ),
                        ),
                        // 📸 AQUI MOSTRAMOS LA MINIATURA DEL TICKET EN EL CALENDARIO
                        if (evento.ticketsGasto.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          const Text('📸 Tickets del gasto:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.teal)),
                          const SizedBox(height: 5),
                          SizedBox(
                            height: 80,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: evento.ticketsGasto.length,
                              itemBuilder: (ctx, i) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 12.0, top: 8.0),
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          showDialog(context: context, builder: (ctx) => Dialog(
                                            backgroundColor: Colors.black87,
                                            insetPadding: EdgeInsets.zero,
                                            child: Stack(alignment: Alignment.center, children: [
                                              InteractiveViewer(child: kIsWeb 
                                                ? Image.network(evento.ticketsGasto[i], errorBuilder: (c,e,s) => const Icon(Icons.broken_image, color: Colors.white)) 
                                                : Image.file(File(evento.ticketsGasto[i]), errorBuilder: (c,e,s) => const Icon(Icons.broken_image, color: Colors.white))),
                                              Positioned(top: 40, right: 20, child: IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 30), onPressed: () => Navigator.pop(ctx))),
                                            ]),
                                          ));
                                        },
                                        child: Container(
                                          width: 80, height: 80,
                                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                                          child: ClipRRect(borderRadius: BorderRadius.circular(8), child: kIsWeb 
                                            ? Image.network(evento.ticketsGasto[i], fit: BoxFit.cover, errorBuilder: (c,e,s) => const Icon(Icons.image_not_supported, color: Colors.grey)) 
                                            : Image.file(File(evento.ticketsGasto[i]), fit: BoxFit.cover, errorBuilder: (c,e,s) => const Icon(Icons.image_not_supported, color: Colors.grey))),
                                        ),
                                      ),
                                      if (!esObserver)
                                        Positioned(
                                          top: -8,
                                          right: -8,
                                          child: GestureDetector(
                                            onTap: () {
                                              setModalState(() {
                                                String ticketBorrado = evento.ticketsGasto.removeAt(i);
                                                int gIndex = baseDatosGastosGlobal.indexWhere((g) => g.titulo == evento.idGastoAsociado);
                                                if (gIndex != -1) baseDatosGastosGlobal[gIndex].rutasAdjuntos.remove(ticketBorrado);
                                                
                                                // Rastro en la Agenda (Detalle del evento)
                                                evento.logsTrazabilidad.add('🗑️ Ticket eliminado el ${DateTime.now().toString().substring(0,16)}');
                                              });
                                              
                                              // 🚀 FIX FORENSE: Rastro en el Calendario Visual (Global)
                                              setState(() {
                                                _registroAuditoria.add("🗑️ Evento '${evento.titulo}': Evidencia económica (ticket) eliminada.");
                                              });
                                            },
                                            child: const CircleAvatar(radius: 12, backgroundColor: Colors.white, child: CircleAvatar(radius: 10, backgroundColor: Colors.red, child: Icon(Icons.close, color: Colors.white, size: 10))),
                                          ),
                                        )
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ]
                      ],
                    ),

                  const SizedBox(height: 10),
                  const Text('Chat del Evento', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Container(
                    height: 200,
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
                    child: evento.chat.isEmpty 
                      ? const Center(child: Text('No hay mensajes', style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          padding: const EdgeInsets.all(10),
                          itemCount: evento.chat.length,
                          itemBuilder: (ctx, i) {
                            final msg = evento.chat[i];
                            bool esMio = msg.autor == miNombre;
                            return Align(
                              alignment: esMio ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: esMio ? Colors.teal.shade100 : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: esMio ? null : Border.all(color: Colors.grey.shade300)
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(msg.texto, style: const TextStyle(fontSize: 14)),
                                    Text('${msg.autor} - ${msg.fecha.hour}:${msg.fecha.minute}', style: TextStyle(fontSize: 10, color: Colors.grey.shade700))
                                  ],
                                ),
                              ),
                            );
                          }
                        ),
                  ),
                  
                  if (!esObserver) Padding( // RBAC: Observer no chatea
                    padding: const EdgeInsets.only(top: 10, bottom: 20),
                    child: Row(
                      children: [
                        Expanded(child: TextField(controller: chatCtrl, decoration: const InputDecoration(hintText: 'Escribir mensaje...', isDense: true, border: OutlineInputBorder()))),
                        IconButton(icon: const Icon(Icons.send, color: Colors.teal), onPressed: () {
                          if (chatCtrl.text.isNotEmpty) {
                            setState(() {
                              evento.chat.add(MensajeCalendario(autor: miNombre, texto: chatCtrl.text, fecha: DateTime.now()));
                            });
                            setModalState((){}); // Refrescar el modal
                            chatCtrl.clear();
                          }
                        })
                      ],
                    ),
                  )
                ],
                ),
              ),
            );
          }
        );
      }
    );
  }

  // --- NUEVO: MENÚ DE EXPORTACIÓN (Igual que FinanceTab) ---
  void _abrirMenuExportacion() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Exportar Calendario', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              
              // OPCIÓN 1: MES ACTUAL
              ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.teal, child: Icon(Icons.calendar_view_month, color: Colors.white)),
                title: const Text('Mes Actual'),
                subtitle: const Text('Calendario visual incluyendo anexo de trazabilidad'),
                onTap: () {
                  Navigator.pop(ctx);
                  final now = DateTime.now();
                  // Rango: Primer día del mes a último día del mes
                  final inicio = DateTime(now.year, now.month, 1);
                  final fin = DateTime(now.year, now.month + 1, 0);
                  _exportarConRango(DateTimeRange(start: inicio, end: fin));
                },
              ),
              
              // OPCIÓN 2: RANGO PERSONALIZADO
              ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.date_range, color: Colors.white)),
                title: const Text('Seleccionar Periodo'),
                subtitle: const Text('Elige varios meses o un año entero'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final DateTimeRange? rango = await showDateRangePicker(
                    context: context, 
                    locale: const Locale('es', 'ES'),
                    firstDate: DateTime(2023), 
                    lastDate: DateTime(2030),
                    helpText: 'SELECCIONA EL RANGO A IMPRIMIR',
                  );
                  if (rango != null) {
                    if (!mounted) return;
                    _exportarConRango(rango);
                  }
                },
              ),

              const Divider(),

              // OPCIÓN 3: INFORME LEGAL DETALLADO (EL BUENO)
              ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.indigo, child: Icon(Icons.gavel, color: Colors.white)),
                title: const Text('Informe Forense Detallado'),
                subtitle: const Text('Tabla con historial de chat y trazabilidad completa'),
                onTap: () {
                  Navigator.pop(ctx);
                  // Recogemos todos los eventos aplanando la lista
                  List<Evento> todosLosEventos = _eventos.values.expand((e) => e).toList();
                  
                  // LLAMAMOS A LA TABLA LEGAL (y le pasamos la auditoría)
                  PdfService().exportarInformeAgenda(context, todosLosEventos, null, _registroAuditoria);
                },
              ),
            ],
          ),
        );
      }
    );
  }

  void _exportarConRango(DateTimeRange rango) {
    // Convertimos el mapa de eventos a lista plana
    List<Evento> todosLosEventos = _eventos.values.expand((e) => e).toList();
    // Llamamos al nuevo servicio visual
    PdfService().exportarCalendarioVisual(context, todosLosEventos, rango, _getCustodio, _registroAuditoria);
  }

  // Helper para cambiar rol (Demo)
  void _cambiarRol() {
    setState(() {
      _rolUsuario = _rolUsuario == 'admin' ? 'observer' : 'admin';
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rol cambiado a: ${_rolUsuario.toUpperCase()}'), backgroundColor: Colors.indigo));
  }

  void _sincronizarConFinanzas() {
    // Barrido silencioso de todos los eventos para detectar si su gasto fue borrado
    for (var listaEventos in _eventos.values) {
      for (var evento in listaEventos) {
        if (evento.idGastoAsociado != null) {
          // Verificamos si el gasto sigue existiendo en Finanzas (Por Título, para coincidir con el enlace)
          bool existeEnFinanzas = baseDatosGastosGlobal.any((g) => g.titulo == evento.idGastoAsociado);
          
          if (!existeEnFinanzas) {
            // Si no existe, desenlazamos y limpiamos
            evento.idGastoAsociado = null;
            evento.ticketsGasto.clear();
            evento.logsTrazabilidad.add('🗑️ ALERTA: Gasto desvinculado/eliminado desde Finanzas el ${DateTime.now().toString().substring(0,16)}');
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _sincronizarConFinanzas();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendario', style: TextStyle(fontSize: 18, color: Colors.teal)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          // DEMO SWITCHER DE ROL
          IconButton(
            icon: Icon(_rolUsuario == 'admin' ? Icons.security : Icons.remove_red_eye, color: _rolUsuario == 'admin' ? Colors.blue : Colors.grey),
            onPressed: _cambiarRol,
            tooltip: 'Cambiar Rol (Admin/Observer)',
          ),
          // NUEVO BOTÓN DE EXPORTAR (Texto + Icono)
          TextButton.icon(
            onPressed: _abrirMenuExportacion,
            icon: const Icon(Icons.download, size: 18, color: Colors.teal),
            label: const Text('Exportar', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
          ),
          TextButton.icon(
            onPressed: _abrirConfiguracionCustodia,
            icon: const Icon(Icons.settings, size: 16, color: Colors.grey),
            label: const Text('Configurar Custodia', style: TextStyle(color: Colors.grey, fontSize: 12)),
          )
        ],
      ),
      // JUGADA 4: RBAC - Si es observer, no hay botón flotante de añadir
      floatingActionButton: _rolUsuario == 'observer' ? null : FloatingActionButton(
        onPressed: _abrirFormularioEvento,
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add, color: Colors.white), 
      ),
      body: Column(
        children: [
          TableCalendar<Evento>(
            locale: 'es_ES',
            firstDay: DateTime.utc(2023, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            eventLoader: _getEventosDelDia,
            calendarFormat: CalendarFormat.month,
            startingDayOfWeek: StartingDayOfWeek.monday,
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (_, day, __) => _buildCustodyDay(day, false),
              todayBuilder: (_, day, __) => _buildCustodyDay(day, false, isToday: true),
              selectedBuilder: (_, day, __) => _buildCustodyDay(day, true),
              markerBuilder: (_, __, events) {
                if (events.isEmpty) return null;
                return Positioned(
                  bottom: 1,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: events.take(4).map((e) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      width: 5, height: 5,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: _getColor(e.categoria)),
                    )).toList(),
                  ),
                );
              },
            ),
            calendarStyle: const CalendarStyle(outsideDaysVisible: false),
            headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
          ),
          
          // TU LEYENDA RESTAURADA
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildLegendItem('Médico', Colors.red.shade400),
                _buildLegendItem('Escuela', Colors.blue.shade400),
                _buildLegendItem('Ocio', Colors.orange.shade400),
              ],
            ),
          ),

          const SizedBox(height: 8),
          const Divider(),
          
          // TU CABECERA DE DÍA RESTAURADA
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Día ${_selectedDay!.day}/${_selectedDay!.month}: Turno de ${_getCustodio(_selectedDay!)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                
                // JUGADA 1: BOTÓN DE CHECK-IN GPS (Solo visible si es mi turno o si quiero registrar recogida)
                // Y JUGADA 4: RBAC (Observer no hace check-in)
                if (_rolUsuario != 'observer')
                  ActionChip(
                    avatar: const Icon(Icons.my_location, size: 16, color: Colors.white),
                    label: const Text('Check-in Entrega', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: Colors.indigo,
                    onPressed: _registrarCheckInGPS,
                  ),
                  
                // 2. Botón de Intercambio en Días Propios (Simplificación de Lógica)
                if (_rolUsuario != 'observer')
                  IconButton(
                    icon: const Icon(Icons.swap_horiz, color: Colors.teal),
                    tooltip: 'Solicitar Cambio',
                    onPressed: () => _solicitarCambioDiaEspecifico(_selectedDay!),
                  )
              ],
            ),
          ),

          Expanded(
            child: Builder(
              builder: (context) {
                final eventosDelDia = _getEventosDelDia(_selectedDay!);
                if (eventosDelDia.isEmpty) return const Center(child: Text('No hay eventos programados.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)));

                return ListView.builder(
                  itemCount: eventosDelDia.length,
                  itemBuilder: (context, index) {
                    final evento = eventosDelDia[index];
                    bool esCancelado = evento.estado == EstadoEvento.cancelado;
                    bool esPendiente = evento.estado == EstadoEvento.pendiente;
                    bool esSolicitudBorrado = evento.estado == EstadoEvento.solicitudEliminacion;

                    // TU DISEÑO DE TARJETA INTACTO
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      elevation: 2,
                      color: esCancelado ? Colors.grey.shade200 : (esSolicitudBorrado ? Colors.red.shade50 : (esPendiente ? Colors.orange.shade50 : Colors.white)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: esCancelado ? Colors.grey : (esSolicitudBorrado ? Colors.red : _getColor(evento.categoria).withOpacity(0.2)),
                          child: Icon(esCancelado ? Icons.block : (esSolicitudBorrado ? Icons.delete_forever : _getIcono(evento.categoria)), color: (esCancelado || esSolicitudBorrado) ? Colors.white : _getColor(evento.categoria)),
                        ),
                        title: Text(
                          evento.titulo, 
                          style: TextStyle(fontWeight: FontWeight.bold, decoration: esCancelado ? TextDecoration.lineThrough : null, color: esCancelado ? Colors.grey : Colors.black)
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${evento.fecha.hour}:${evento.fecha.minute.toString().padLeft(2,'0')} - Resp: ${evento.responsable}'),
                            // REQ 1: Mostrar niños implicados
                            if (evento.ninosAsignados.isNotEmpty) Text('Para: ${evento.ninosAsignados.join(", ")}', style: const TextStyle(color: Colors.teal, fontSize: 11, fontWeight: FontWeight.bold)),
                            if (esPendiente) const Text('Pendiente de aprobación (Fuera de turno)', style: TextStyle(color: Colors.deepOrange, fontSize: 11, fontWeight: FontWeight.bold)),
                            if (esSolicitudBorrado) Text('SOLICITUD DE BORRADO: ${evento.motivoSolicitud}', style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
                            if (esCancelado) const Text('EVENTO CANCELADO', style: TextStyle(color: Colors.grey, fontSize: 11, fontStyle: FontStyle.italic)),
                            if (!esCancelado && evento.creador == miNombre && evento.vistoPorOtro != null)
                              Text('👁 Visto por $otroNombre el ${evento.vistoPorOtro!.day}/${evento.vistoPorOtro!.month}', style: const TextStyle(color: Colors.blue, fontSize: 10)),
                            if (evento.adjuntos.isNotEmpty)
                              Text('📎 ${evento.adjuntos.length} documentos adjuntos', style: const TextStyle(color: Colors.indigo, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        trailing: esSolicitudBorrado 
                          ? const Icon(Icons.warning, color: Colors.red) 
                          : (esPendiente ? const Icon(Icons.hourglass_empty, color: Colors.orange) : const Icon(Icons.chevron_right, color: Colors.grey)),
                        onTap: () => _mostrarDetalleEvento(evento),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // WIDGET PARA PINTAR LOS DÍAS INTACTO
  Widget _buildCustodyDay(DateTime day, bool isSelected, {bool isToday = false, String Function(DateTime)? calculator}) {
    // Si le pasamos un calculador (el del borrador), usa ese. Si no, usa el real.
    String custodio = calculator != null ? calculator(day) : _getCustodio(day);
    bool esMio = custodio == miNombre;
    
    Color bgColor = esMio ? Colors.blue.shade50 : Colors.orange.shade50;
    Color textColor = esMio ? Colors.blue.shade900 : Colors.deepOrange.shade900;
    
    if (isSelected) {
      bgColor = esMio ? Colors.blue.shade300 : Colors.orange.shade300;
      textColor = Colors.white;
    } else if (isToday) {
      bgColor = esMio ? Colors.blue.shade100 : Colors.orange.shade100;
    }

    return Container(
      margin: const EdgeInsets.all(4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle, 
        border: isToday ? Border.all(color: textColor, width: 2) : null,
      ),
      child: Text('${day.day}', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(children: [
      Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
    ]);
  }
}

  