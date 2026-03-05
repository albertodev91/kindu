import 'package:flutter/material.dart';

class AvisosTab extends StatefulWidget {
  const AvisosTab({super.key});

  @override
  State<AvisosTab> createState() => _AvisosTabState();
}

class _AvisosTabState extends State<AvisosTab> {
  // LISTA REAL DE AVISOS
  List<Map<String, dynamic>> avisos = [
    {'titulo': 'Aviso Escolar', 'desc': 'Reunión de tutoría trimestral.', 'tipo': 'Escolar'},
  ];

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
                            avisos.insert(0, {'titulo': titulo, 'desc': descripcion, 'tipo': tipoSeleccionado});
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
          return Card(
            elevation: 3, margin: const EdgeInsets.only(bottom: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              contentPadding: const EdgeInsets.all(15),
              leading: CircleAvatar(
                backgroundColor: _getColor(aviso['tipo']).withOpacity(0.1),
                child: Icon(_getIcono(aviso['tipo']), color: _getColor(aviso['tipo'])),
              ),
              title: Text(aviso['titulo'], style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Padding(padding: const EdgeInsets.only(top: 8.0), child: Text(aviso['desc'])),
              trailing: const Icon(Icons.push_pin_outlined, size: 20, color: Colors.grey),
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