import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:studyflow/screens/login_screen.dart';
import 'package:studyflow/screens/home_screen.dart';
import 'package:studyflow/screens/welcome_screen.dart';
import 'package:studyflow/services/auth_service.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return const LoginScreen();
        }

        return FutureBuilder<bool>(
          future: AuthService().isPrimeiroLogin(user),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (userSnapshot.hasError) {
              return const Scaffold(
                body: Center(child: Text('Erro ao carregar dados do usuário')),
              );
            }

            final isPrimeiroLogin = userSnapshot.data ?? false;
            if (isPrimeiroLogin) {
              return WelcomeScreen(user: user);
            }

            return const HomeScreen();
          },
        );
      },
    );
  }
}
