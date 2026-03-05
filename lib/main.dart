import 'package:flutter/material.dart';
import 'screens/login_screen.dart'; // Importamos tu nuevo login

void main() {
  // Arrancamos la interfaz visual directamente
  runApp(const KinduApp());
}

class KinduApp extends StatelessWidget {
  const KinduApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kindu',
      debugShowCheckedModeBanner: false, // Quitamos la etiqueta roja de "debug"
      theme: ThemeData(
        // Usamos Teal como color principal de la marca Kindu
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      // Aquí le decimos que la pantalla de inicio sea el Login
      home: const LoginScreen(), 
    );
  }
}