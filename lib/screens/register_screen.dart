import 'package:flutter/material.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crea tu cuenta Kindu')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            const Icon(Icons.person_add, size: 80, color: Colors.teal),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nombre Completo', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Contraseña', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirmar Contraseña', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  // Aquí irá la lógica de Firebase
                  print("Registrando usuario...");
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                child: const Text('REGISTRARME', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}