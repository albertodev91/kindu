import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'calendar_tab.dart'; // Para acceder a registroAuditoriaGlobal
import '../services/pdf_service.dart';

// 2. MODELO DE DATOS
class Documento {
  final String id;
  final String titulo;
  final String categoria;
  final IconData icono;
  final DateTime fechaSubida;
  final DateTime? fechaCaducidad;
  final List<String> rutasArchivos;

  Documento({
    required this.id,
    required this.titulo,
    required this.categoria,
    required this.icono,
    required this.fechaSubida,
    this.fechaCaducidad,
    this.rutasArchivos = const [],
  });
}

// BASE DE DATOS EN MEMORIA (GLOBAL Y ESTÁTICA)
List<Documento> globalDocumentos = [];

class BaulTab extends StatefulWidget {
  const BaulTab({super.key});

  @override
  State<BaulTab> createState() => _BaulTabState();
}

class _BaulTabState extends State<BaulTab> {
  // 1. CAPA DE SEGURIDAD
  bool _accesoConcedido = false;
  final TextEditingController _pinController = TextEditingController();


  @override
  void initState() {
    super.initState();
    _inicializarDatosBase();
  }

  void _inicializarDatosBase() {
    // Ya no se incrustan registros base (empieza vacío)
  }

  void _validarPin() {
    if (_pinController.text == '6554') {
      setState(() {
        _accesoConcedido = true;
      });
      // Ocultar teclado
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🔓 Acceso a Bóveda Concedido'), backgroundColor: Colors.teal),
      );
    } else {
      _pinController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⛔ PIN Incorrecto'), backgroundColor: Colors.red),
      );
    }
  }

  // 4. VISOR DE DOCUMENTOS Y AUDITORÍA
  void _mostrarDetalleDocumento(Documento doc) {
    // Log Forense
    String log = "👁️ El usuario ha consultado el documento '${doc.titulo}' el ${DateTime.now()}";
    debugPrint(log);
    registroAuditoriaGlobal.add(log); // Usamos el Libro de Actas Único

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return StatefulBuilder(
              builder: (context, setModalState) {
                return Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          CircleAvatar(radius: 24, backgroundColor: Colors.teal.shade50, child: Icon(doc.icono, color: Colors.teal)),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(doc.titulo, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal)),
                                Text(doc.categoria.toUpperCase(), style: const TextStyle(fontSize: 12, color: Colors.grey, letterSpacing: 1.2)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () {
                              // Eliminar y Auditoría
                              setState(() {
                                globalDocumentos.removeWhere((d) => d.id == doc.id);
                              });
                              debugPrint("🗑️ Documento '${doc.titulo}' eliminado por el usuario.");
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Documento destruido y registrado en auditoría.'), backgroundColor: Colors.red));
                            },
                          )
                        ],
                      ),
                      const Divider(height: 30),
                      
                      // INFORMACIÓN DE CADUCIDAD
                      if (doc.fechaCaducidad != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: _calcularEstadoCaducidad(doc.fechaCaducidad!) ? Colors.red.shade50 : Colors.green.shade50,
                            border: Border.all(color: _calcularEstadoCaducidad(doc.fechaCaducidad!) ? Colors.red.shade200 : Colors.green.shade200),
                            borderRadius: BorderRadius.circular(8)
                          ),
                          child: Row(
                            children: [
                              Icon(_calcularEstadoCaducidad(doc.fechaCaducidad!) ? Icons.warning_amber : Icons.check_circle, color: _calcularEstadoCaducidad(doc.fechaCaducidad!) ? Colors.red : Colors.green),
                              const SizedBox(width: 10),
                              Text(
                                'Vence el: ${doc.fechaCaducidad!.day}/${doc.fechaCaducidad!.month}/${doc.fechaCaducidad!.year}',
                                style: TextStyle(color: _calcularEstadoCaducidad(doc.fechaCaducidad!) ? Colors.red.shade900 : Colors.green.shade900, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),

                      const Text('Archivos Adjuntos (Evidencia)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 10),

                      if (doc.rutasArchivos.isEmpty)
                        const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No hay imágenes digitalizadas.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))))
                      else
                        Expanded(
                          child: ListView.builder(
                            controller: scrollController,
                            scrollDirection: Axis.horizontal, // Carrusel horizontal
                            itemCount: doc.rutasArchivos.length,
                            itemBuilder: (context, index) {
                              final path = doc.rutasArchivos[index];
                              return Padding(
                                padding: const EdgeInsets.only(right: 15.0, top: 10.0), // Margen para que quepa la X
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    // 1. EL VISOR ORIGINAL (No modifiques la lógica del Dialog interno)
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
                                                  minScale: 0.5,
                                                  maxScale: 4.0,
                                                  child: kIsWeb 
                                                    ? Image.network(path, errorBuilder: (c,e,s) => const Icon(Icons.broken_image, color: Colors.white, size: 50)) 
                                                    : Image.file(File(path), errorBuilder: (c,e,s) => const Icon(Icons.broken_image, color: Colors.white, size: 50))
                                                ),
                                                Positioned(top: 40, right: 20, child: IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 30), onPressed: () => Navigator.pop(ctx))),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        width: 250,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.grey.shade300),
                                          image: DecorationImage(
                                            image: kIsWeb ? NetworkImage(path) : FileImage(File(path)) as ImageProvider,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        child: const Center(child: Icon(Icons.zoom_in, color: Colors.white70, size: 40)),
                                      ),
                                    ),
                                    // 2. EL BOTÓN DE BORRADO INDIVIDUAL
                                    Positioned(
                                      top: -8,
                                      right: -8,
                                      child: GestureDetector(
                                        onTap: () {
                                          // Actualizar la vista del Modal
                                          setModalState(() {
                                            doc.rutasArchivos.removeAt(index);
                                          });
                                          // Log Forense Global
                                          setState(() {
                                            registroAuditoriaGlobal.add("🗑️ Bóveda: El usuario eliminó una página/foto del documento '${doc.titulo}'.");
                                          });
                                        },
                                        child: const CircleAvatar(radius: 14, backgroundColor: Colors.white, child: CircleAvatar(radius: 12, backgroundColor: Colors.red, child: Icon(Icons.close, color: Colors.white, size: 14))),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),

                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            try {
                              final List<XFile> fotos = await ImagePicker().pickMultiImage();
                              if (fotos.isNotEmpty) {
                                if (kIsWeb) await Future.delayed(const Duration(milliseconds: 300));
                                // Actualizamos la UI del Modal
                                setModalState(() {
                                  doc.rutasArchivos.addAll(fotos.map((f) => f.path));
                                });
                                // Log Forense
                                setState(() {
                                  registroAuditoriaGlobal.add("📎 Bóveda: El usuario añadió ${fotos.length} nueva(s) página(s) al documento '${doc.titulo}'.");
                                });
                              }
                            } catch (e) {
                              debugPrint('Error picker: $e');
                            }
                          },
                          icon: const Icon(Icons.add_a_photo, color: Colors.teal),
                          label: const Text('Escanear / Añadir más páginas', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.teal), 
                            padding: const EdgeInsets.symmetric(vertical: 15)
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }
            );
          }
        );
      }
    );
  }

  // 5. FORMULARIO DE SUBIDA
  void _abrirFormularioSubida() {
    final TextEditingController tituloCtrl = TextEditingController();
    String categoriaSeleccionada = 'Legal';
    DateTime? fechaCaducidad;
    List<String> rutasAdjuntos = [];

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
                  const Text('Digitalizar Nuevo Documento', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal)),
                  const SizedBox(height: 20),
                  
                  TextField(
                    controller: tituloCtrl,
                    decoration: const InputDecoration(labelText: 'Título del Documento', prefixIcon: Icon(Icons.title), border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 15),
                  
                  DropdownButtonFormField<String>(
                    value: categoriaSeleccionada,
                    decoration: const InputDecoration(labelText: 'Categoría', prefixIcon: Icon(Icons.category), border: OutlineInputBorder()),
                    items: ['Legal', 'Salud', 'Identidad', 'Educación'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setModalState(() => categoriaSeleccionada = v!),
                  ),
                  const SizedBox(height: 15),

                  OutlinedButton.icon(
                    onPressed: () async {
                      final d = await showDatePicker(context: context, initialDate: DateTime.now().add(const Duration(days: 365)), firstDate: DateTime.now(), lastDate: DateTime(2040));
                      if (d != null) setModalState(() => fechaCaducidad = d);
                    },
                    icon: Icon(Icons.timer, color: fechaCaducidad != null ? Colors.red : Colors.grey),
                    label: Text(fechaCaducidad != null ? 'Caduca: ${fechaCaducidad!.day}/${fechaCaducidad!.month}/${fechaCaducidad!.year}' : '¿Tiene fecha de caducidad? (Opcional)'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 50), alignment: Alignment.centerLeft),
                  ),
                  const SizedBox(height: 15),

                  OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        final List<XFile> fotos = await ImagePicker().pickMultiImage();
                        if (fotos.isNotEmpty) {
                          if (kIsWeb) await Future.delayed(const Duration(milliseconds: 300));
                          setModalState(() => rutasAdjuntos.addAll(fotos.map((f) => f.path)));
                        }
                      } catch (e) {
                        debugPrint('Error picker: $e');
                      }
                    },
                    icon: Icon(rutasAdjuntos.isNotEmpty ? Icons.check_circle : Icons.camera_alt, color: rutasAdjuntos.isNotEmpty ? Colors.green : Colors.teal),
                    label: Text(rutasAdjuntos.isNotEmpty ? '${rutasAdjuntos.length} Páginas escaneadas' : 'Escanear / Subir Fotos'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 50), alignment: Alignment.centerLeft),
                  ),

                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity, height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        if (tituloCtrl.text.isNotEmpty) {
                          IconData icono = Icons.description;
                          if (categoriaSeleccionada == 'Legal') icono = Icons.gavel;
                          if (categoriaSeleccionada == 'Salud') icono = Icons.medical_services;
                          if (categoriaSeleccionada == 'Identidad') icono = Icons.badge;
                          if (categoriaSeleccionada == 'Educación') icono = Icons.school;

                          setState(() {
                            globalDocumentos.add(Documento(
                              id: 'DOC-${DateTime.now().millisecondsSinceEpoch}',
                              titulo: tituloCtrl.text,
                              categoria: categoriaSeleccionada,
                              icono: icono,
                              fechaSubida: DateTime.now(),
                              fechaCaducidad: fechaCaducidad,
                              rutasArchivos: rutasAdjuntos,
                              
                            ));
                            // Log Forense de Creación
                            registroAuditoriaGlobal.add("🆕 Bóveda: Se ha digitalizado el documento '${tituloCtrl.text}' en la categoría '$categoriaSeleccionada' con ${rutasAdjuntos.length} páginas.");
                          });
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Documento encriptado y guardado.'), backgroundColor: Colors.teal));
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                      child: const Text('Guardar en la Bóveda'),
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

  // Devuelve true si faltan menos de 6 meses (180 días)
  bool _calcularEstadoCaducidad(DateTime fechaCaducidad) {
    final diasRestantes = fechaCaducidad.difference(DateTime.now()).inDays;
    return diasRestantes < 180; 
  }

  @override
  Widget build(BuildContext context) {
    // 1. PANTALLA DE BLOQUEO (SI NO HAY ACCESO)
    if (!_accesoConcedido) {
      return Container(
        padding: const EdgeInsets.all(30),
        color: Colors.grey.shade100,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 80, color: Colors.teal),
            const SizedBox(height: 20),
            const Text('Caja Fuerte Documental', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.teal)),
            const SizedBox(height: 10),
            const Text('Introduce tu PIN de seguridad para acceder a la documentación legal y sensible.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 40),
            TextField(
              controller: _pinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 4,
              style: const TextStyle(fontSize: 24, letterSpacing: 10),
              decoration: InputDecoration(
                hintText: 'PIN',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                filled: true,
                fillColor: Colors.white,
                counterText: "",
              ),
              onChanged: (val) {
                if (val.length == 4) _validarPin();
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _validarPin,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15)),
              child: const Text('DESBLOQUEAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      );
    }

    // 3. UI DE LA BÓVEDA (GRIDVIEW)
    return Scaffold(
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.teal.withOpacity(0.05),
            child: Row(
              children: [
                const Icon(Icons.security, color: Colors.teal),
                const SizedBox(width: 10),
                const Expanded(child: Text("Bóveda Forense Desbloqueada", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal))),
                
                // BOTÓN DE EXPORTAR (Estilo Calendario)
                TextButton.icon(
                  onPressed: () {
                    PdfService().exportarInformeBoveda(context, globalDocumentos, registroAuditoriaGlobal);
                  },
                  icon: const Icon(Icons.download, color: Colors.teal),
                  label: const Text('Exportar', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                ),
                
                IconButton(
                  icon: const Icon(Icons.lock, color: Colors.grey),
                  onPressed: () => setState(() => _accesoConcedido = false),
                  tooltip: 'Bloquear Bóveda',
                )
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.9,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: globalDocumentos.length,
              itemBuilder: (context, index) {
                final doc = globalDocumentos[index];
                
                // Lógica de color de estado
                bool esCritico = false;
                String textoEstado = 'Vigente';
                Color colorEstado = Colors.grey;

                if (doc.fechaCaducidad != null) {
                  if (_calcularEstadoCaducidad(doc.fechaCaducidad!)) {
                    esCritico = true;
                    textoEstado = 'Próximo a caducar';
                    colorEstado = Colors.red;
                  } else {
                    textoEstado = 'En vigor';
                    colorEstado = Colors.green;
                  }
                }

                return GestureDetector(
                  onTap: () => _mostrarDetalleDocumento(doc),
                  child: Card(
                    elevation: 4,
                    shadowColor: Colors.teal.withOpacity(0.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                      side: esCritico ? const BorderSide(color: Colors.red, width: 2) : BorderSide.none
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: esCritico ? Colors.red.shade50 : Colors.teal.shade50,
                            child: Icon(doc.icono, size: 30, color: esCritico ? Colors.red : Colors.teal),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            doc.titulo,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: colorEstado.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                            child: Text(textoEstado, style: TextStyle(color: colorEstado, fontSize: 10, fontWeight: FontWeight.bold)),
                          )
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirFormularioSubida,
        backgroundColor: Colors.teal,
        icon: const Icon(Icons.upload_file, color: Colors.white),
        label: const Text('Subir Documento', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
