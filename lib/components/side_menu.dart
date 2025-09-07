// lib/components/side_menu.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/settings_screen.dart';
import '../screens/calendar_screen.dart';
import '../screens/study_schedule_screen.dart';
import '../screens/next_events_screen.dart';
import '../screens/study_session_screen.dart';
import '../screens/progress_screen.dart';
import '../services/auth_service.dart';
import '../screens/home_screen.dart';

class SideMenu extends StatelessWidget {
  /// Quando [disabled] for true, bloqueia taps e cinza os itens.
  final bool disabled;

  const SideMenu({Key? key, this.disabled = false}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final textColor = disabled ? Colors.grey : null;

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

          _buildTile(
            context,
            icon: Icons.home,
            label: 'Início',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            ),
            textColor: textColor,
          ),

          _buildTile(
            context,
            icon: Icons.dashboard_customize_rounded,
            label: 'Criar Agenda de Estudos',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StudyScheduleScreen()),
            ),
            textColor: textColor,
          ),

          _buildTile(
            context,
            icon: Icons.alarm,
            label: 'Próximas Seções',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NextEventsScreen()),
              );
            },
            textColor: textColor,
          ),

          _buildTile(
            context,
            icon: Icons.calendar_month,
            label: 'Calendário',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CalendarScreen()),
            ),
            textColor: textColor,
          ),

          _buildTile(
            context,
            icon: Icons.play_circle_fill,
            label: 'Iniciar Seção',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StudySessionScreen()),
              );
            },
            textColor: textColor,
          ),

          _buildTile(
            context,
            icon: Icons.bar_chart,
            label: 'Progresso',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProgressScreen()),
              );
            },
            textColor: textColor,
          ),

          _buildTile(
            context,
            icon: Icons.settings,
            label: 'Configurações',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
            textColor: textColor,
          ),

          const Divider(),

          _buildTile(
            context,
            icon: Icons.logout,
            label: 'Sair',
            onTap: () async {
              await AuthService().logout();
              Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
            },
            textColor: textColor,
          ),
        ],
      ),
    );
  }

  Widget _buildTile(
    BuildContext ctx, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: textColor),
      title: Text(label, style: TextStyle(color: textColor)),
      // desabilita tap quando `disabled == true`
      onTap: disabled ? null : onTap,
    );
  }
}
