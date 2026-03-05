import 'package:flutter/material.dart';

class BaulTab extends StatelessWidget {
  const BaulTab({super.key});
  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      padding: const EdgeInsets.all(16),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      children: [
        _buildDocCard("DNI Niños", Icons.badge),
        _buildDocCard("Cartilla Vacunas", Icons.health_and_safety),
        _buildDocCard("Seguro Médico", Icons.medical_services),
        _buildDocCard("Libro Familia", Icons.menu_book),
      ],
    );
  }

  Widget _buildDocCard(String title, IconData icon) {
    return Card(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 50, color: Colors.teal),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}