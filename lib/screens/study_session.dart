// lib/screens/study_session.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';

import '../components/side_menu.dart';
import '../services/auth_service.dart';
import '../services/google_auth_client.dart';
import '../services/google_calendar_service.dart';
import '../services/constants.dart';

class StudySessionScreen extends StatefulWidget {
  const StudySessionScreen({Key? key}) : super(key: key);

  @override
  _StudySessionScreenState createState() => _StudySessionScreenState();
}

class _StudySessionScreenState extends State<StudySessionScreen> {
  final _authService = AuthService();
  late GoogleCalendarService _calendarService;

  calendar.Event? _currentSession;
  bool _isLoading = true;

  DateTime? _sessionStart;
  Duration _focusTime = Duration.zero;
  Duration _pauseTime = Duration.zero;

  late final Stopwatch _stopwatch;
  Timer? _timer;

  String _sessionState = 'aguardando'; // 'foco', 'pausa', 'finalizado'

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_stopwatch.isRunning) {
        setState(() {
          if (_sessionState == 'foco') {
            _focusTime += const Duration(seconds: 1);
          } else if (_sessionState == 'pausa') {
            _pauseTime += const Duration(seconds: 1);
          }
        });
      }
    });
    _init();
  }

  Future<void> _init() async {
    // 1) Pega headers de autenticação
    final headers = await _authService.getAuthHeaders();
    if (headers == null) {
      _showError('Não foi possível autenticar com o Google.');
      return;
    }

    // 2) Cria client autenticado e serviço
    final client = GoogleAuthClient(headers);
    _calendarService = GoogleCalendarService(client);

    // 3) Carrega sessão atual
    await _checkCurrentSession();
  }

  Future<void> _checkCurrentSession() async {
    try {
      final now = DateTime.now();
      final items = await _calendarService.fetchNextStudySessions(
        maxResults: 10,
        privateExtendedProperties: ['type=${typeSection[1]}'],
      );

      final current = items.firstWhereOrNull((ev) {
        final start = ev.start?.dateTime?.toLocal();
        final end = ev.end?.dateTime?.toLocal();
        return start != null &&
            end != null &&
            now.isAfter(start) &&
            now.isBefore(end);
      });

      setState(() {
        _currentSession = current;
        _isLoading = false;
      });
    } catch (e) {
      _showError('Erro ao buscar sessão atual: $e');
      setState(() => _isLoading = false);
    }
  }

  void _startSession() {
    _stopwatch
      ..reset()
      ..start();
    _sessionStart = DateTime.now();
    setState(() => _sessionState = 'foco');
  }

  void _togglePause() {
    if (_sessionState == 'foco') {
      setState(() => _sessionState = 'pausa');
    } else if (_sessionState == 'pausa') {
      setState(() => _sessionState = 'foco');
    }
  }

  void _finalizeSession() {
    _stopwatch.stop();
    setState(() => _sessionState = 'finalizado');
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('HH:mm');

    return Scaffold(
      drawer: const SideMenu(),
      appBar: AppBar(
        title: const Text('Iniciar Seção'),
        backgroundColor: Colors.deepPurple,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentSession == null
          ? const Center(child: Text('Nenhuma seção agendada no momento.'))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentSession!.summary ?? 'Sessão de Estudo',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${fmt.format(_currentSession!.start!.dateTime!.toLocal())}'
                    ' – ${fmt.format(_currentSession!.end!.dateTime!.toLocal())}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  if (_sessionStart != null)
                    Text(
                      'Início da sessão: ${fmt.format(_sessionStart!)}',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildTotalBox('Foco', _focusTime),
                      _buildTotalBox('Pausa', _pauseTime),
                      _buildTotalBox('Total', _focusTime + _pauseTime),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (_sessionState == 'aguardando')
                    ElevatedButton(
                      onPressed: _startSession,
                      child: const Text('Iniciar Seção'),
                    )
                  else if (_sessionState == 'foco' || _sessionState == 'pausa')
                    ElevatedButton(
                      onPressed: _togglePause,
                      child: Text(
                        _sessionState == 'foco'
                            ? 'Iniciar Pausa'
                            : 'Retomar Foco',
                      ),
                    )
                  else
                    const Center(child: Text('Sessão finalizada')),
                  const SizedBox(height: 12),
                  if (_sessionState != 'finalizado' &&
                      _sessionState != 'aguardando')
                    TextButton(
                      onPressed: _finalizeSession,
                      child: const Text('Finalizar Sessão'),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildTotalBox(String label, Duration d) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 4),
        Text(
          _formatDuration(d),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
