import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
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
            .update({
          'primeiroLogin': false,
          'loginManual': false,
        });
        return true;
      }

      return false;
    } catch (e) {
      print('Erro ao verificar primeiro login: $e');
      return false;
    }
  }

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
  }
}
