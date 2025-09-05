// lib/screens/next_events.dart

import 'package:flutter/material.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:intl/intl.dart';

import '../services/auth_service.dart';
import '../services/google_auth_client.dart';
import '../services/google_calendar_service.dart';

class NextEventsScreen extends StatefulWidget {
  const NextEventsScreen({Key? key}) : super(key: key);

  @override
  State<NextEventsScreen> createState() => _NextEventsScreenState();
}

class _NextEventsScreenState extends State<NextEventsScreen> {
  final _authService = AuthService();
  late GoogleCalendarService _service;
  bool _isLoading = true;
  List<calendar.Event> _events = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() => _isLoading = true);

    // Pega os headers de autenticação
    final headers = await _authService.getAuthHeaders();
    if (headers == null) {
      _showError('Não foi possível obter credenciais Google.');
      setState(() => _isLoading = false);
      return;
    }

    // Constrói o client e o serviço
    final client = GoogleAuthClient(headers);
    _service = GoogleCalendarService(client);

    await _loadEvents();
  }

  Future<void> _loadEvents() async {
    try {
      // Exemplo: filtra sessões de estudo via extendedProperties.private['type']
      _events = await _service.fetchNextStudySessions(
        privateExtendedProperties: ['type=Seção Estudo'],
      );
    } catch (e) {
      _showError('Erro ao carregar próximos eventos: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');
    final timeFmt = DateFormat('HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Próximos Eventos'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadEvents),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _events.length,
              itemBuilder: (ctx, i) {
                final e = _events[i];
                final start = e.start?.dateTime?.toLocal();
                final end = e.end?.dateTime?.toLocal();
                return ListTile(
                  title: Text(e.summary ?? 'Sem título'),
                  subtitle: (start != null && end != null)
                      ? Text(
                          '${dateFmt.format(start)} → ${timeFmt.format(end)}',
                        )
                      : null,
                );
              },
            ),
    );
  }
}
