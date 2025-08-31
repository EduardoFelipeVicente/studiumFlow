import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:studyflow/screens/welcome_screen.dart';
import 'package:studyflow/screens/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  Future<void> loginWithEmail() async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      debugPrint('Erro: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao fazer login com email')),
      );
    }
  }

  Future<void> loginWithGoogle() async {
    final googleSignIn = GoogleSignIn(
      scopes: ['email'],
      // Adicione seu client ID para Web aqui se necessário:
      // serverClientId: 'SEU_CLIENT_ID_WEB.apps.googleusercontent.com',
    );

    // Garante que não há sessão ativa
    final isSignedIn = await googleSignIn.isSignedIn();
    if (isSignedIn) {
      await googleSignIn.signOut();
    }

    final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
    
    if (googleUser == null) return;

    final googleAuth = await googleUser.authentication;

    if (googleAuth.idToken == null || googleAuth.accessToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao autenticar com Google')),
      );
      return;
    }

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken!,
      idToken: googleAuth.idToken!,
    );

    await FirebaseAuth.instance.signInWithCredential(credential);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docRef = FirebaseFirestore.instance
        .collection('usuarios')
        .doc(user.uid);
    final doc = await docRef.get();

    if (!mounted) return;

    if (!doc.exists) {
      await docRef.set({
        'nome': user.displayName,
        'email': user.email,
        'primeiroLogin': true,
        'loginManual': true,
      });

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => WelcomeScreen(user: user)),
      );
    } else {
      await docRef.update({'loginManual': true});

      final dados = doc.data() as Map<String, dynamic>;
      final primeiroLogin = dados['primeiroLogin'] ?? false;

      if (primeiroLogin) {
        await docRef.update({'primeiroLogin': false, 'loginManual': false});
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => WelcomeScreen(user: user)),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    }
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
