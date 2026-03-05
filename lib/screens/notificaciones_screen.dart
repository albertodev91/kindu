import 'package:flutter/material.dart';

class NotificacionesScreen extends StatelessWidget {
  const NotificacionesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // --- SIMULACIÓN DE BASE DE DATOS DE NOTIFICACIONES ---
    // tabIndex: 0 = Agenda, 1 = Gastos, 2 = Avisos, 3 = Baúl, 4 = Familia
    final List<Map<String, dynamic>> notificaciones = [
      {
        'icono': Icons.gavel, 'color': Colors.red, 
        'titulo': 'Gasto en Disputa', 
        'mensaje': 'Yaiza ha rechazado el gasto "Excursión Granja".', 
        'tiempo': 'Hace 2 min', 
        'tabIndex': 1 // Nos llevará a Finanzas
      },
      {
        'icono': Icons.folder_shared, 'color': Colors.blue, 
        'titulo': 'Nuevo Documento', 
        'mensaje': 'Yaiza ha subido "Boletín de Notas 1º Trimestre".', 
        'tiempo': 'Hace 1 hora', 
        'tabIndex': 3 // Nos llevará al Baúl
      },
      {
        'icono': Icons.calendar_today, 'color': Colors.orange, 
        'titulo': 'Cambio en el Calendario', 
        'mensaje': 'Yaiza ha añadido "Cita Dentista Hugo".', 
        'tiempo': 'Ayer', 
        'tabIndex': 0 // Nos llevará a la Agenda
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: ListView.separated(
        itemCount: notificaciones.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final notif = notificaciones[index];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: notif['color'].withOpacity(0.15),
              child: Icon(notif['icono'], color: notif['color']),
            ),
            title: Text(notif['titulo'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(notif['mensaje'], style: const TextStyle(color: Colors.black87)),
            ),
            trailing: Text(notif['tiempo'], style: const TextStyle(color: Colors.grey, fontSize: 12)),
            onTap: () {
              // LA MAGIA: Cierra esta pantalla y le "lanza" al Home el número de pestaña
              Navigator.pop(context, notif['tabIndex']);
            },
          );
        },
      ),
    );
  }
}