import 'package:flutter/material.dart';
import 'package:studyflow/components/side_menu.dart';
import 'package:studyflow/services/google_calendar_service.dart';
import 'package:studyflow/services/auth_service.dart';
import 'package:studyflow/services/google_auth_client.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _auth = AuthService();
  late GoogleCalendarService _calendarService;

  @override
  void initState() {
    super.initState();
    print('initState');

    _initAndUpdateLateEvents();
  }

  Future<void> _initAndUpdateLateEvents() async {
    final headers = await _auth.getAuthHeaders();
    final client = GoogleAuthClient(headers!);
    _calendarService = GoogleCalendarService(client);
    print('initAndUpdateLateEvents.');

    await _calendarService.updateLateEvents();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('StudyFlow'),
        backgroundColor: Colors.deepPurple,
      ),
      drawer: const SideMenu(),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Bem-vindo ao seu painel de estudos!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              'Use o menu lateral para acessar sua agenda, progresso e configurações.',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
