import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Controladores de texto
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Variable para ocultar/mostrar contraseña
  bool _isObscure = true;

  // ¡Buena práctica! Liberar memoria cuando la pantalla se cierra
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 1. Logo
              const Icon(
                Icons.family_restroom_rounded,
                size: 100,
                color: Colors.teal,
              ),
              const SizedBox(height: 10),
              
              // 2. Títulos
              const Text(
                'Kindu',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                  letterSpacing: 2,
                ),
              ),
              const Text(
                'Gestión familiar compartida',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
              const SizedBox(height: 50),

              // 3. Campo de Correo
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Correo electrónico',
                  hintText: 'ejemplo@correo.com',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 4. Campo de Contraseña
              TextField(
                controller: _passwordController,
                obscureText: _isObscure,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_isObscure ? Icons.visibility : Icons.visibility_off),
                    onPressed: () {
                      setState(() {
                        _isObscure = !_isObscure;
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // 5. Botón de Entrar -> Va a HomeScreen
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () {
                    // Navegación directa a la Home
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const HomeScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'INICIAR SESIÓN',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 6. Botón de Registro -> Va a RegisterScreen
              TextButton(
                onPressed: () {
                  // Navegación a la pantalla de Registro
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const RegisterScreen()),
                  );
                },
                child: const Text(
                  '¿Aún no tienes cuenta? Regístrate aquí',
                  style: TextStyle(color: Colors.teal, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}