import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:studyflow/screens/login_screen.dart';
import 'package:studyflow/screens/calendar_screen.dart';
import 'package:studyflow/screens/study_schedule_screen.dart';
import 'package:google_sign_in/google_sign_in.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('StudyFlow'),
        backgroundColor: Colors.deepPurple,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.deepPurple),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.person,
                      size: 32,
                      color: Colors.deepPurple,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Olá, Eduardo!',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('Criar Agenda de Estudos'),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const StudyScheduleChart()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('Próximas Sessões'),
              onTap: () {
                // Navegar para sessões futuras
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('Calendário'),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CalendarScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart),
              title: const Text('Progresso'),
              onTap: () {
                // Navegar para progresso
              },
            ),
            ListTile(
              leading: const Icon(Icons.check_circle),
              title: const Text('Seções realizadas'),
              onTap: () {
                // Navegar para histórico
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Configurações'),
              onTap: () {
                // Navegar para configurações
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                Navigator.of(context).pop(); // Fecha o Drawer

                try {
                  final googleSignIn = GoogleSignIn();

                  // Força o logout do Google se estiver logado
                  final isSignedIn = await googleSignIn.isSignedIn();
                  if (isSignedIn) {
                    await googleSignIn.signOut();
                  }

                  // Firebase logout
                  await FirebaseAuth.instance.signOut();

                  // Redireciona para LoginScreen
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                } catch (e) {
                  debugPrint('Erro ao fazer logout: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Erro ao sair da conta')),
                  );
                }
              },
            ),
          ],
        ),
      ),
      body: const Center(
        child: Text(
          'Bem-vindo ao seu painel de estudos!',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
