import 'package:flutter/material.dart';

class FamiliaTab extends StatelessWidget {
  const FamiliaTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircleAvatar(radius: 50, backgroundColor: Colors.teal, child: Icon(Icons.person, size: 60, color: Colors.white)),
          const SizedBox(height: 20),
          const Text('Alberto Dev', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const Text('Padre / Gestor', style: TextStyle(color: Colors.grey)),
          const Divider(height: 40),
          const Text('VINCULACIÓN FAMILIAR', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
            child: const Text('KINDU-2026', 
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 3, color: Colors.blue)),
          ),
          const SizedBox(height: 10),
          const Text('Comparte este código con el otro progenitor para sincronizar datos.', 
            textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () {}, 
            icon: const Icon(Icons.logout), 
            label: const Text('Cerrar Sesión'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade100, foregroundColor: Colors.red),
          )
        ],
      ),
    );
  }
}