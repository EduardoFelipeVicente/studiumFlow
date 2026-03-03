// lib/screens/auth_gate.dart
// AuthGate: responsável por decidir qual tela mostrar
// dependendo do estado de autenticação do usuário.
// - Mostra Login se não houver usuário
// - Mostra WelcomeScreen se for primeiro login
// - Mostra HomeScreen se já estiver autenticado

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Telas
import '../screens/login_screen.dart';
import '../screens/welcome_screen.dart';
import '../screens/home_screen.dart';

// Serviço
import '../services/auth_service.dart' as auth_service;

class AuthGate extends StatelessWidget {
  const AuthGate({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1) Enquanto carrega o estado de autenticação
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Colors.deepPurple),
            ),
          );
        }

        // 2) Sem usuário logado → mostra LoginScreen
        final user = snapshot.data;
        if (user == null) {
          return const LoginScreen();
        }

        // 3) Usuário logado → verifica se é o primeiro acesso
        return FutureBuilder<bool>(
          future: auth_service.AuthService().isPrimeiroLogin(user),
          builder: (context, userSnap) {
            if (userSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(color: Colors.deepPurple),
                ),
              );
            }
            if (userSnap.hasError) {
              return const Scaffold(
                body: Center(
                  child: Text('Não foi possível carregar os dados do usuário'),
                ),
              );
            }

            final primeiroLogin = userSnap.data ?? false;
            if (primeiroLogin) {
              return WelcomeScreen(user: user);
            }
            return const HomeScreen();
          },
        );
      },
    );
  }
}