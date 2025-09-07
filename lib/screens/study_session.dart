// lib/screens/study_session.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // para HapticFeedback
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'package:audioplayers/audioplayers.dart'; // para tocar alert.mp3

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
  bool get _sessionActive =>
      _sessionState == 'foco' || _sessionState == 'pausa';
  final _authService = AuthService();
  late GoogleCalendarService _calendarService;

  calendar.Event? _currentSession;
  bool _isLoading = true;

  DateTime? _sessionStart;
  Duration _focusTime = Duration.zero;
  Duration _pauseTime = Duration.zero;

  late final Stopwatch _stopwatch;
  Timer? _timer;

  // Audio player para alertas
  late final AudioPlayer _audioPlayer;

  String _sessionState = 'aguardando'; // 'foco', 'pausa', 'finalizado'

  // controle de ciclos de Pomodoro
  int _focusCycles = 0;
  Duration _focusSinceLastPause = Duration.zero;
  Duration _pauseSinceLastBreak = Duration.zero;
  bool _alertedFocus = false;
  bool _alertedPause = false;
  Duration _currentPausePeriod = kShortPausePeriod;

  @override
  void initState() {
    super.initState();

    // inicializa player de áudio
    _audioPlayer = AudioPlayer()..setReleaseMode(ReleaseMode.stop);

    _stopwatch = Stopwatch();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_stopwatch.isRunning) return;

      setState(() {
        if (_sessionState == 'foco') {
          _focusTime += const Duration(seconds: 1);
          _focusSinceLastPause += const Duration(seconds: 1);

          if (!_alertedFocus && _focusSinceLastPause >= kFocusPeriod) {
            _alertedFocus = true;
            _notifyUser(
              'Tempo de foco atingido (${_formatPeriod(kFocusPeriod)}). Hora da pausa!',
            );
          }
        } else if (_sessionState == 'pausa') {
          _pauseTime += const Duration(seconds: 1);
          _pauseSinceLastBreak += const Duration(seconds: 1);

          if (!_alertedPause && _pauseSinceLastBreak >= _currentPausePeriod) {
            _alertedPause = true;
            _notifyUser(
              'Pausa de ${_formatPeriod(_currentPausePeriod)} concluída. Retome o foco!',
            );
          }
        }
      });
    });

    _init();
  }

  Future<void> _init() async {
    final headers = await _authService.getAuthHeaders();
    if (headers == null) {
      _showError('Não foi possível autenticar com o Google.');
      return;
    }
    final client = GoogleAuthClient(headers);
    _calendarService = GoogleCalendarService(client);
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
    _focusTime = Duration.zero;
    _pauseTime = Duration.zero;
    _focusSinceLastPause = Duration.zero;
    _pauseSinceLastBreak = Duration.zero;
    _alertedFocus = false;
    _alertedPause = false;
    _focusCycles = 0;
    _currentPausePeriod = kShortPausePeriod;
    setState(() => _sessionState = 'foco');
    _audioPlayer.stop();
  }

  void _togglePause() {
    if (_sessionState == 'foco') {
      _focusCycles++;
      _currentPausePeriod = (_focusCycles % 3 == 0)
          ? kLongPausePeriod
          : kShortPausePeriod;
      _pauseSinceLastBreak = Duration.zero;
      _alertedPause = false;
      _audioPlayer.stop();
      setState(() => _sessionState = 'pausa');
    } else if (_sessionState == 'pausa') {
      _focusSinceLastPause = Duration.zero;
      _alertedFocus = false;
      setState(() => _sessionState = 'foco');
    }
  }

  Future<void> _finalizeSession() async {
    _stopwatch.stop();
    setState(() => _sessionState = 'finalizado');

    try {
      await _calendarService.alterEventOnCalendar(
        calendarId: 'primary',
        eventId: _currentSession!.id!,
        statusSectionIndex: 2, // Concluído
        focusDuration: _focusTime,
        pauseDuration: _pauseTime,
        actualStart: _sessionStart,
        // start e end ficam nulos e o serviço vai reaproveitar os originais
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sessão finalizada com sucesso!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao finalizar sessão: $e')));
    }
  }

  void _notifyUser(String msg) {
    // Háptico
    HapticFeedback.vibrate();

    // Som de alerta via AudioPlayer
    _audioPlayer.play(AssetSource('sounds/alert.mp3'));

    // SnackBar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 4)),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('HH:mm');

    return Scaffold(
      drawer: SideMenu(disabled: _sessionActive),
      drawerEnableOpenDragGesture: !_sessionActive,

      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        centerTitle: true,
        title: const Text(
          'Iniciar Sessão',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentSession == null
          ? const Center(child: Text('Nenhuma sessão agendada no momento.'))
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
                      child: const Text('Iniciar Sessão'),
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
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 4),
        Text(
          '$m:$s',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  String _formatPeriod(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
