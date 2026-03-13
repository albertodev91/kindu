import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/pdf_service.dart';
import 'calendar_tab.dart'; // Para acceder a registroAuditoriaGlobal

// 1. CLASE MODELO AVISO
class AvisoUsuario {
  final String id;
  final String titulo;
  final String descripcion;
  final String tipo;
  final DateTime fechaCreacion;
  bool enterado;
  List<String> rutasArchivos; // Soporte para evidencias

  AvisoUsuario({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.tipo,
    required this.fechaCreacion,
    this.enterado = false,
    this.rutasArchivos = const [],
  });
}

class AvisosTab extends StatefulWidget {
  const AvisosTab({super.key});

  @override
  State<AvisosTab> createState() => _AvisosTabState();
}

class _AvisosTabState extends State<AvisosTab> {
  // LISTA REAL DE AVISOS
  List<AvisoUsuario> avisos = [];

  // Simulación de Rol (Igual que en otras tabs)
  String _rolUsuario = 'admin';

 

  void _abrirFormularioAviso(BuildContext context, {AvisoUsuario? avisoEditar}) {
    bool esEdicion = avisoEditar != null;
    String titulo = esEdicion ? avisoEditar.titulo : '';
    String descripcion = esEdicion ? avisoEditar.descripcion : '';
    String tipoSeleccionado = esEdicion ? avisoEditar.tipo : 'Escolar'; // Por defecto
    List<String> adjuntosTemporales = esEdicion ? List.from(avisoEditar.rutasArchivos) : []; // Para las fotos nuevas

    // Controladores para precargar texto si es edición
    final TextEditingController tituloCtrl = TextEditingController(text: titulo);
    final TextEditingController descCtrl = TextEditingController(text: descripcion);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        // StatefulBuilder permite que el menú desplegable (Dropdown) funcione dentro de la ventana
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 20, left: 20, right: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(esEdicion ? 'Editar Aviso' : 'Crear Nuevo Aviso', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal)),
                  const SizedBox(height: 20),
                  
                  // SELECCIONAR CATEGORÍA
                  DropdownButtonFormField<String>(
                    initialValue: tipoSeleccionado,
                    decoration: InputDecoration(labelText: 'Categoría', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                    items: ['Escolar', 'Médico', 'Urgente', 'Otros'].map((String categoria) {
                      return DropdownMenuItem(value: categoria, child: Text(categoria));
                    }).toList(),
                    onChanged: (String? newValue) {
                      setModalState(() => tipoSeleccionado = newValue!);
                    },
                  ),
                  const SizedBox(height: 15),

                  TextField(
                    controller: tituloCtrl,
                    decoration: InputDecoration(labelText: 'Título del aviso', prefixIcon: const Icon(Icons.title), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                  ),
                  const SizedBox(height: 15),
                  
                  TextField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(labelText: 'Detalles...', prefixIcon: const Icon(Icons.description), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                  ),
                  const SizedBox(height: 20),
                  
                  // BOTÓN DE CÁMARA (EVIDENCIAS)
                  OutlinedButton.icon(
                    onPressed: () async {
                      final List<XFile> fotos = await ImagePicker().pickMultiImage();
                      if (fotos.isNotEmpty) {
                        if (kIsWeb) await Future.delayed(const Duration(milliseconds: 300));
                        setModalState(() {
                          adjuntosTemporales.addAll(fotos.map((f) => f.path));
                        });
                      }
                    },
                    icon: const Icon(Icons.camera_alt, color: Colors.teal),
                    label: Text(adjuntosTemporales.isEmpty ? 'Adjuntar Fotos / Evidencias' : '${adjuntosTemporales.length} Fotos adjuntas', style: const TextStyle(color: Colors.teal)),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 45)),
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity, height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (tituloCtrl.text.isNotEmpty) {
                          // AÑADE EL AVISO A LA LISTA REAL Y ACTUALIZA LA PANTALLA
                          setState(() {
                            if (esEdicion) {
                              // EDITAR EXISTENTE
                              // Buscamos el índice del aviso original
                              int index = avisos.indexOf(avisoEditar!);
                              if (index != -1) {
                                avisos[index] = AvisoUsuario(
                                  id: avisoEditar.id, // Mismo ID
                                  titulo: tituloCtrl.text,
                                  descripcion: descCtrl.text,
                                  tipo: tipoSeleccionado,
                                  fechaCreacion: avisoEditar.fechaCreacion, // Misma fecha creación
                                  enterado: avisoEditar.enterado, // Mismo estado
                                  rutasArchivos: adjuntosTemporales,
                                );
                                // Log Forense de Edición
                                registroAuditoriaGlobal.add("✏️ Aviso: El usuario editó el aviso '${tituloCtrl.text}' (Evidencias: ${adjuntosTemporales.length}).");
                              }
                            } else {
                              // CREAR NUEVO
                              avisos.insert(0, AvisoUsuario(
                                id: 'AVISO-${DateTime.now().millisecondsSinceEpoch}',
                                titulo: tituloCtrl.text,
                                descripcion: descCtrl.text,
                                tipo: tipoSeleccionado,
                                fechaCreacion: DateTime.now(),
                                enterado: false,
                                rutasArchivos: adjuntosTemporales
                              ));
                              // Log Forense de Creación
                              registroAuditoriaGlobal.add("📝 Aviso: El usuario creó un aviso $tipoSeleccionado titulado '${tituloCtrl.text}' con ${adjuntosTemporales.length} evidencias.");
                            }
                          });
                          Navigator.pop(context);
                          if (esEdicion) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aviso actualizado correctamente'), backgroundColor: Colors.teal));
                          }
                        }
                      },
                      icon: const Icon(Icons.save), 
                      label: Text(esEdicion ? 'Guardar Cambios' : 'Guardar Aviso', style: const TextStyle(fontSize: 16)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          }
        );
      },
    );
  }

  // VISOR DE EVIDENCIAS (MODAL) - Usa dart:io (File)
  void _verEvidencias(AvisoUsuario aviso) {
    // Log de auditoría al abrir
    registroAuditoriaGlobal.add("👁️ Aviso: El usuario consultó la evidencia del aviso '${aviso.titulo}' el ${DateTime.now()}");

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, scrollController) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              return Container(
                decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text("Evidencias Adjuntas", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
                    const SizedBox(height: 10),
                    Expanded(
                      child: aviso.rutasArchivos.isEmpty 
                        ? const Center(child: Text("No hay evidencias adjuntas", style: TextStyle(color: Colors.grey)))
                        : GridView.builder(
                            controller: scrollController,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10),
                            itemCount: aviso.rutasArchivos.length,
                            itemBuilder: (context, index) {
                              final path = aviso.rutasArchivos[index];
                              return Stack(
                                fit: StackFit.expand,
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
                                              InteractiveViewer(child: kIsWeb ? Image.network(path) : Image.file(File(path))),
                                              Positioned(top: 40, right: 20, child: IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 30), onPressed: () => Navigator.pop(ctx))),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: kIsWeb ? Image.network(path, fit: BoxFit.cover) : Image.file(File(path), fit: BoxFit.cover),
                                    ),
                                  ),
                                  // Botón Borrar (Solo si no está confirmado)
                                  if (!aviso.enterado)
                                    Positioned(
                                      top: 5, right: 5,
                                      child: GestureDetector(
                                        onTap: () {
                                          setModalState(() {
                                            aviso.rutasArchivos.removeAt(index);
                                          });
                                          setState(() {}); // Actualiza la vista padre
                                          registroAuditoriaGlobal.add("🗑️ Aviso: El usuario eliminó una evidencia del aviso '${aviso.titulo}'.");
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Evidencia eliminada'), backgroundColor: Colors.red));
                                        },
                                        child: const CircleAvatar(radius: 12, backgroundColor: Colors.red, child: Icon(Icons.close, color: Colors.white, size: 14)),
                                      ),
                                    )
                                ],
                              );
                            },
                          ),
                    ),
                    const SizedBox(height: 20),
                    if (!aviso.enterado) // Bloqueo legal forense
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            try {
                              final List<XFile> nuevasFotos = await ImagePicker().pickMultiImage();
                              if (nuevasFotos.isNotEmpty) {
                                if (kIsWeb) await Future.delayed(const Duration(milliseconds: 300));
                                
                                setModalState(() {
                                  aviso.rutasArchivos.addAll(nuevasFotos.map((f) => f.path));
                                });
                                // Actualizar la pantalla principal por si cambia el contador
                                setState(() {}); 
                                
                                // Log forense
                                registroAuditoriaGlobal.add("📎 Aviso: El usuario añadió ${nuevasFotos.length} evidencia(s) al aviso '${aviso.titulo}'.");
                              }
                            } catch (e) {
                              debugPrint('Error picker: $e');
                            }
                          },
                          icon: const Icon(Icons.add_a_photo, color: Colors.teal),
                          label: Text(aviso.rutasArchivos.isEmpty ? 'Adjuntar Evidencias' : 'Añadir más evidencias', style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.teal), 
                            padding: const EdgeInsets.symmetric(vertical: 15)
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        }
      ),
    );
  }

  // Define colores e iconos según el tipo real
  IconData _getIcono(String tipo) {
    if (tipo == 'Médico') return Icons.medical_services;
    if (tipo == 'Urgente') return Icons.warning_amber_rounded;
    return Icons.school; // Escolar por defecto
  }

  Color _getColor(String tipo) {
    if (tipo == 'Médico') return Colors.red.shade400;
    if (tipo == 'Urgente') return Colors.orange.shade600;
    return Colors.blue.shade400; // Escolar por defecto
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // CABECERA ESTÁNDAR (Usa PdfService y _rolUsuario)
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.teal.withOpacity(0.05),
            child: Row(
              children: [
                const Icon(Icons.notifications_active, color: Colors.teal),
                const SizedBox(width: 10),
                const Expanded(child: Text("Centro de Comunicaciones", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal))),
                
                // BOTÓN CAMBIAR ROL
                IconButton(
                  icon: Icon(_rolUsuario == 'admin' ? Icons.security : Icons.remove_red_eye, color: Colors.grey),
                  onPressed: () {
                    setState(() => _rolUsuario = _rolUsuario == 'admin' ? 'observer' : 'admin');
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cambio de vista de custodia realizado'), backgroundColor: Colors.indigo));
                  },
                  tooltip: 'Cambiar Rol',
                ),

                // BOTÓN EXPORTAR
                TextButton.icon(
                  onPressed: () {
                    PdfService().exportarInformeAvisos(context, avisos, registroAuditoriaGlobal);
                  },
                  icon: const Icon(Icons.download, color: Colors.teal),
                  label: const Text('Exportar', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: avisos.length, 
              itemBuilder: (context, index) {
                final aviso = avisos[index];
                String fechaStr = '${aviso.fechaCreacion.day}/${aviso.fechaCreacion.month}/${aviso.fechaCreacion.year} ${aviso.fechaCreacion.hour}:${aviso.fechaCreacion.minute.toString().padLeft(2,'0')}';

                return Card(
                  elevation: 3, margin: const EdgeInsets.only(bottom: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(15),
                    leading: CircleAvatar(
                      backgroundColor: _getColor(aviso.tipo).withOpacity(0.1),
                      child: Icon(_getIcono(aviso.tipo), color: _getColor(aviso.tipo)),
                    ),
                    title: Text(aviso.titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(padding: const EdgeInsets.only(top: 4.0), child: Text(aviso.descripcion)),
                        const SizedBox(height: 5),
                        Text(fechaStr, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        
                        // VISOR DE EVIDENCIAS EN EL LISTTILE
                        if (aviso.rutasArchivos.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: InkWell(
                              onTap: () => _verEvidencias(aviso),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade300)),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.attach_file, size: 14, color: Colors.teal),
                                    const SizedBox(width: 5),
                                    Text('Ver ${aviso.rutasArchivos.length} evidencias adjuntas', style: const TextStyle(color: Colors.teal, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                          )
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Botón de Editar (Solo si no está confirmado)
                        if (!aviso.enterado)
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            tooltip: 'Editar Aviso',
                            onPressed: () => _abrirFormularioAviso(context, avisoEditar: aviso),
                          ),
                        // Botón de Confirmación de Lectura
                        IconButton(
                          icon: Icon(Icons.done_all, color: aviso.enterado ? Colors.green : Colors.grey),
                          tooltip: aviso.enterado ? 'Confirmado y Leído' : 'Marcar como Enterado',
                          onPressed: aviso.enterado ? null : () {
                            setState(() {
                              aviso.enterado = true;
                              registroAuditoriaGlobal.add("🔔 Aviso: El usuario confirmó lectura del aviso '${aviso.titulo}'.");
                            });
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Confirmación de lectura registrada.'), backgroundColor: Colors.green));
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _abrirFormularioAviso(context), // Crear nuevo
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}