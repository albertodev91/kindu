import 'package:flutter/material.dart';
import 'calendar_tab.dart';
import 'finance_tab.dart';
import 'avisos_tab.dart'; 
import 'baul_tab.dart';
import 'familia_tab.dart';
// IMPORTAMOS LA NUEVA PANTALLA
import 'notificaciones_screen.dart'; 

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const CalendarTab(),
    const FinanceTab(),
    const AvisosTab(),
    const BaulTab(),
    const FamiliaTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kindu App'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // --- LA CAMPANITA GLOBAL ---
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none, size: 28),
                onPressed: () async {
                  // 1. Abrimos la pantalla de notificaciones y ESPERAMOS el resultado
                  final int? tabDestino = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const NotificacionesScreen()),
                  );

                  // 2. Si la pantalla nos devuelve un número, cambiamos a esa pestaña
                  if (tabDestino != null) {
                    setState(() {
                      _selectedIndex = tabDestino;
                    });
                  }
                },
              ),
              Positioned(
                right: 12, top: 12,
                child: Container(
                  padding: const EdgeInsets.all(2), 
                  decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(6)), 
                  constraints: const BoxConstraints(minWidth: 10, minHeight: 10)
                ),
              )
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.teal,
        unselectedItemColor: Colors.grey.shade500,
        showUnselectedLabels: true,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today_outlined), activeIcon: Icon(Icons.calendar_today), label: 'Agenda'),
          BottomNavigationBarItem(icon: Icon(Icons.payments_outlined), activeIcon: Icon(Icons.payments), label: 'Gastos'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications_none_outlined), activeIcon: Icon(Icons.notifications_active), label: 'Avisos'),
          BottomNavigationBarItem(icon: Icon(Icons.folder_open_outlined), activeIcon: Icon(Icons.folder_shared), label: 'Documentos'),
          BottomNavigationBarItem(icon: Icon(Icons.people_outline), activeIcon: Icon(Icons.people), label: 'Familia'),
        ],
      ),
    );
  }
}