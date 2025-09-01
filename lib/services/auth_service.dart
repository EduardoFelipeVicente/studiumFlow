import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _googleSignIn = GoogleSignIn();

  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      return userCredential.user;
    } catch (e) {
      print('Erro ao fazer login com Google: $e');
      return null;
    }
  }

  Future<User?> signInWithEmail(String email, String senha) async {
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: senha,
      );
      return credential.user;
    } catch (e) {
      print('Erro ao fazer login com email: $e');
      return null;
    }
  }

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

  Future<bool> isPrimeiroLogin(User user) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();

      final dados = snapshot.data() as Map<String, dynamic>?;

      if (dados == null) return false;

      final primeiroLogin = dados['primeiroLogin'] ?? false;
      final loginManual = dados['loginManual'] ?? false;

      if (primeiroLogin && loginManual) {
        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(user.uid)
            .update({'primeiroLogin': false, 'loginManual': false});
        return true;
      }

      return false;
    } catch (e) {
      print('Erro ao verificar primeiro login: $e');
      return false;
    }
  }

  Future<void> logout() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  Future<String?> getGoogleAccessToken() async {
    final googleUser = await _googleSignIn.signInSilently();
    final googleAuth = await googleUser?.authentication;
    return googleAuth?.accessToken;
  }
}
