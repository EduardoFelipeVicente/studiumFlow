// lib/services/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ----- ATENÇÃO: use aqui o Client ID do tipo WEB -----
  static const _webClientId =
      '109345613312-80fvn4s8sk24f047ndnnqrcv7oitf8p3.apps.googleusercontent.com';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: _webClientId,
    scopes: [
      'email',
      calendar
          .CalendarApi
          .calendarScope, // https://www.googleapis.com/auth/calendar
    ],
  );

  /// Login com Google e retorno do usuário Firebase
  Future<User?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCred = await _auth.signInWithCredential(credential);
      return userCred.user;
    } catch (e) {
      print('Erro ao fazer login com Google: $e');
      return null;
    }
  }

  /// Login com email/senha e retorno do usuário Firebase
  Future<User?> signInWithEmail(String email, String senha) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: senha,
      );
      return cred.user;
    } catch (e) {
      print('Erro ao fazer login com email: $e');
      return null;
    }
  }

  /// Cria ou atualiza documento do usuário no Firestore
  Future<void> criarOuAtualizarUsuario(User user) async {
    final docRef = FirebaseFirestore.instance
        .collection('usuarios')
        .doc(user.uid);
    final doc = await docRef.get();
    if (!doc.exists) {
      await docRef.set({
        'nome': user.displayName,
        'email': user.email,
        'primeiroLogin': true,
        'loginManual': true,
      });
    } else {
      await docRef.update({'loginManual': true});
    }
  }

  /// Retorna true se for o primeiro login (e já atualiza as flags no Firestore)
  Future<bool> isPrimeiroLogin(User user) async {
    try {
      final docRef = FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid);
      final snapshot = await docRef.get();
      final dados = snapshot.data();
      if (dados == null) return false;

      final primeiro = dados['primeiroLogin'] ?? false;
      final manual = dados['loginManual'] ?? false;

      if (primeiro && manual) {
        // após detectar o primeiro login, zera as flags
        await docRef.update({'primeiroLogin': false, 'loginManual': false});
        return true;
      }
      return false;
    } catch (e) {
      print('Erro ao verificar primeiro login: $e');
      return false;
    }
  }

  /// Logout de Firebase e Google
  Future<void> logout() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  /// Retorna os headers de Authorization para chamadas REST (ou null se não autenticou)
  Future<Map<String, String>?> getAuthHeaders() async {
    GoogleSignInAccount? user = await _googleSignIn.signInSilently();
    user ??= await _googleSignIn.signIn();
    if (user == null) return null;

    final auth = await user.authentication;
    return {
      'Authorization': 'Bearer ${auth.accessToken}',
      'Content-Type': 'application/json',
    };
  }
}
