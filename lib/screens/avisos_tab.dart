import 'package:flutter/material.dart';
import 'calendar_tab.dart'; // Para acceder a registroAuditoriaGlobal

// 1. CLASE MODELO AVISO
class AvisoUsuario {
  final String id;
  final String titulo;
  final String descripcion;
  final String tipo;
  final DateTime fechaCreacion;
  bool enterado;

  AvisoUsuario({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.tipo,
    required this.fechaCreacion,
    this.enterado = false,
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

  @override
  void initState() {
    super.initState();
    // Inyectar aviso de prueba
    avisos.add(AvisoUsuario(
      id: 'AVISO-001',
      titulo: 'Aviso Escolar',
      descripcion: 'Reunión de tutoría trimestral.',
      tipo: 'Escolar',
      fechaCreacion: DateTime.now(),
      enterado: false
    ));
  }

  void _abrirFormularioAviso(BuildContext context) {
    String titulo = '';
    String descripcion = '';
    String tipoSeleccionado = 'Escolar'; // Por defecto

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
                  const Text('Crear Nuevo Aviso', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal)),
                  const SizedBox(height: 20),
                  
                  // SELECCIONAR CATEGORÍA
                  DropdownButtonFormField<String>(
                    initialValue: tipoSeleccionado,
                    decoration: InputDecoration(labelText: 'Categoría', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                    items: ['Escolar', 'Médico', 'Urgente'].map((String categoria) {
                      return DropdownMenuItem(value: categoria, child: Text(categoria));
                    }).toList(),
                    onChanged: (String? newValue) {
                      setModalState(() => tipoSeleccionado = newValue!);
                    },
                  ),
                  const SizedBox(height: 15),

                  TextField(
                    onChanged: (val) => titulo = val,
                    decoration: InputDecoration(labelText: 'Título del aviso', prefixIcon: const Icon(Icons.title), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                  ),
                  const SizedBox(height: 15),
                  
                  TextField(
                    onChanged: (val) => descripcion = val,
                    maxLines: 3,
                    decoration: InputDecoration(labelText: 'Detalles...', prefixIcon: const Icon(Icons.description), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                  ),
                  const SizedBox(height: 20),
                  
                  SizedBox(
                    width: double.infinity, height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (titulo.isNotEmpty) {
                          // AÑADE EL AVISO A LA LISTA REAL Y ACTUALIZA LA PANTALLA
                          setState(() {
                            avisos.insert(0, AvisoUsuario(
                              id: 'AVISO-${DateTime.now().millisecondsSinceEpoch}',
                              titulo: titulo,
                              descripcion: descripcion,
                              tipo: tipoSeleccionado,
                              fechaCreacion: DateTime.now(),
                              enterado: false
                            ));
                            // Log Forense
                            registroAuditoriaGlobal.add("📝 Aviso: El usuario creó un aviso $tipoSeleccionado titulado '$titulo'.");
                          });
                          Navigator.pop(context);
                        }
                      },
                      icon: const Icon(Icons.save), label: const Text('Guardar Aviso', style: TextStyle(fontSize: 16)),
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
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: avisos.length + 1, // +1 por el título
        itemBuilder: (context, index) {
          if (index == 0) {
            return const Padding(
              padding: EdgeInsets.only(bottom: 15),
              child: Text('Centro de Avisos', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.teal)),
            );
          }
          final aviso = avisos[index - 1];
          // 2. FECHAS EN LA UI
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
                ],
              ),
              // 3. ACUSE DE RECIBO (DOBLE CHECK)
              trailing: IconButton(
                icon: Icon(Icons.done_all, color: aviso.enterado ? Colors.green : Colors.grey),
                tooltip: aviso.enterado ? 'Confirmado y Leído' : 'Marcar como Enterado',
                onPressed: aviso.enterado ? null : () {
                  setState(() {
                    aviso.enterado = true;
                    // Log Forense de Lectura
                    registroAuditoriaGlobal.add("🔔 Aviso: El usuario confirmó lectura del aviso '${aviso.titulo}'.");
                  });
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Confirmación de lectura registrada.'), backgroundColor: Colors.green));
                },
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _abrirFormularioAviso(context),
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}