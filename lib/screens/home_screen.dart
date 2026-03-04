import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart'; // ¡La nueva librería en acción!

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // Ya no es 'const' porque el calendario tiene estado (días seleccionados)
  late final List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();
    _widgetOptions = <Widget>[
      const CalendarTab(), // <-- Aquí llamamos a tu nuevo calendario real
      
      // 2. Finanzas (Gastos)
      Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.account_balance_wallet, size: 100, color: Colors.orange),
          Text('Módulo de Finanzas', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          Text('Balance de saldos'),
        ],
      )),

      // 3. Familia (Gestión y Código)
      Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.family_restroom, size: 100, color: Colors.blue),
          Text('Gestión de Familia', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          Text('Código de invitación: KINDU-2024'),
        ],
      )),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kindu App'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Calendario'),
          BottomNavigationBarItem(icon: Icon(Icons.monetization_on), label: 'Finanzas'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Familia'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.teal,
        onTap: _onItemTapped,
      ),
    );
  }
}

// --- SUB-PANTALLA: CALENDARIO DE KINDU ---
class CalendarTab extends StatefulWidget {
  const CalendarTab({super.key});

  @override
  State<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<CalendarTab> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TableCalendar(
          firstDay: DateTime.utc(2023, 1, 1), // Rango inicio
          lastDay: DateTime.utc(2030, 12, 31), // Rango fin
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) {
            return isSameDay(_selectedDay, day);
          },
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay; // Actualiza el mes si cambias de mes al hacer clic
            });
          },
          // Estilos con los colores de tu app
          calendarStyle: const CalendarStyle(
            todayDecoration: BoxDecoration(
              color: Color.fromARGB(150, 0, 150, 136), // Un Teal más clarito para hoy
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: Colors.teal, // Teal fuerte para el día seleccionado
              shape: BoxShape.circle,
            ),
          ),
          headerStyle: const HeaderStyle(
            formatButtonVisible: false, // Oculta un botón raro que viene por defecto
            titleCentered: true,
          ),
        ),
        const Expanded(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Text(
                'Aquí aparecerán los eventos de custodia del día seleccionado (ej: "Fin de semana con papá").',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ),
          ),
        ),
      ],
    );
  }
}