import 'package:flutter/material.dart';
import 'package:studyflow/screens/welcome_screen.dart';
import 'package:studyflow/screens/home_screen.dart';
import 'package:studyflow/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final authService = AuthService();

  Future<void> loginWithEmail() async {
    final email = emailController.text.trim();
    final senha = passwordController.text.trim();

    final user = await authService.signInWithEmail(email, senha);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao fazer login com email')),
      );
      return;
    }

    await authService.criarOuAtualizarUsuario(user);
    final primeiroLogin = await authService.isPrimeiroLogin(user);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => primeiroLogin
            ? WelcomeScreen(user: user)
            : const HomeScreen(),
      ),
    );
  }

  Future<void> loginWithGoogle() async {
    final user = await authService.signInWithGoogle();
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao autenticar com Google')),
      );
      return;
    }

    await authService.criarOuAtualizarUsuario(user);
    final primeiroLogin = await authService.isPrimeiroLogin(user);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => primeiroLogin
            ? WelcomeScreen(user: user)
            : const HomeScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'StudyFlow',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Senha',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: loginWithEmail,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Entrar', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: loginWithGoogle,
                icon: const Icon(Icons.login),
                label: const Text('Entrar com Google'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
