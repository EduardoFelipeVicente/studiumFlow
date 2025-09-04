import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:studyflow/screens/settings_screen.dart';
import 'package:studyflow/screens/calendar_screen.dart';
import 'package:studyflow/screens/study_schedule_screen.dart';
import 'package:studyflow/services/auth_service.dart';
import 'package:studyflow/screens/next_events.dart';
import 'package:studyflow/screens/study_session.dart';

class SideMenu extends StatelessWidget {
  const SideMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(user?.displayName ?? 'Usuário'),
            accountEmail: Text(user?.email ?? ''),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                user?.displayName?.substring(0, 1).toUpperCase() ?? 'U',
                style: const TextStyle(fontSize: 24, color: Colors.deepPurple),
              ),
            ),
            decoration: const BoxDecoration(color: Colors.deepPurple),
          ),

          ListTile(
            leading: const Icon(Icons.schedule),
            title: const Text('Criar Agenda de Estudos'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StudyScheduleChart()),
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.access_time),
            title: const Text('Próximas Seções'),
            onTap: () {
              // 1. Fecha a drawer (se estiver dentro de um Drawer)
              Navigator.pop(context);

              // 2. Navega para NextEventsScreen
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NextEventsScreen()),
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.calendar_month),
            title: const Text('Calendário'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CalendarScreen()),
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.play_circle_fill),
            title: const Text('Iniciar Seção'),
            onTap: () {
              Navigator.pop(context); // fecha o drawer
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StudySessionScreen()),
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.bar_chart),
            title: const Text('Progresso'),
            onTap: () {
              // TODO: Implementar tela de progresso
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Funcionalidade em desenvolvimento'),
                ),
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.check_circle),
            title: const Text('Seções Realizadas'),
            onTap: () {
              // TODO: Implementar tela de histórico de seções
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Funcionalidade em desenvolvimento'),
                ),
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Configurações'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),

          const Divider(),

          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sair'),
            onTap: () async {
              await AuthService().logout();
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/', (route) => false);
            },
          ),
        ],
      ),
    );
  }
}
