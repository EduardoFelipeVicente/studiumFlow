// lib/screens/progress_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/auth_service.dart';
import '../services/google_auth_client.dart';
import '../services/google_calendar_service.dart';
import '../services/constants.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({Key? key}) : super(key: key);

  @override
  _ProgressScreenState createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final _authService = AuthService();
  late GoogleCalendarService _calendarService;

  bool _isLoading = true;

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  final Map<int, bool> _typeFilters = {
    for (var i = 0; i < typeSection.length; i++) i: true,
  };

  int _scheduledCount = 0;
  int _completedCount = 0;
  int _scheduledFocusSecs = 0;
  int _actualFocusSecs = 0;

  final DateFormat _dateFmt = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _initAndLoad();
  }

  Future<void> _initAndLoad() async {
    final headers = await _authService.getAuthHeaders();
    final client = GoogleAuthClient(headers!);
    _calendarService = GoogleCalendarService(client);
    await _loadProgress();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _startDate : _endDate;
    final first = DateTime.now().subtract(const Duration(days: 365));
    final last = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked != null) {
      setState(() {
        if (isStart)
          _startDate = picked;
        else
          _endDate = picked;
      });
      await _loadProgress();
    }
  }

  Future<void> _loadProgress() async {
    setState(() => _isLoading = true);

    // Monta filtros de tipo
    final filters = <String>[];
    _typeFilters.forEach((idx, enabled) {
      if (enabled) filters.add('type=${typeSection[idx]}');
    });

    // Busca eventos no intervalo e com tipos selecionados
    final events = await _calendarService.fetchStudySessions(
      timeMin: _startDate.toUtc(),
      timeMax: _endDate.toUtc(),
      privateExtendedProperties: filters,
    );

    // Contagem de agendados vs concluídos
    final scheduledCount = events.length;
    final completedEvents = events.where((ev) {
      final status = ev.extendedProperties?.private?['status'];
      return status == statusSection[2];
    }).toList();
    final completedCount = completedEvents.length;

    // Durações agendada vs real de foco
    int scheduledSecs = 0;
    int actualSecs = 0;
    for (var ev in events) {
      final start = ev.start?.dateTime;
      final end = ev.end?.dateTime;
      if (start != null && end != null) {
        scheduledSecs += end.difference(start).inSeconds;
      }
      final ft = ev.extendedProperties?.private?['focusTime'];
      if (ft != null) {
        actualSecs += _parseToSeconds(ft);
      }
    }

    setState(() {
      _scheduledCount = scheduledCount;
      _completedCount = completedCount;
      _scheduledFocusSecs = scheduledSecs;
      _actualFocusSecs = actualSecs;
      _isLoading = false;
    });
  }

  int _parseToSeconds(String hhmmss) {
    final parts = hhmmss.split(':').map(int.parse).toList();
    return parts[0] * 3600 + parts[1] * 60 + parts[2];
  }

  double _safeRatio(int num, int den) {
    return den == 0 ? 0.0 : num / den;
  }

  String _formatSecs(int seconds) {
    final h = (seconds ~/ 3600).toString().padLeft(2, '0');
    final m = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final totalTypes = _typeFilters.length;
    final selectedTypes = _typeFilters.values.where((v) => v).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Progresso'),
        backgroundColor: Colors.deepPurple,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Seletor de Período
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    icon: const Icon(Icons.date_range),
                    label: Text('De: ${_dateFmt.format(_startDate)}'),
                    onPressed: () => _pickDate(isStart: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton.icon(
                    icon: const Icon(Icons.date_range),
                    label: Text('Até: ${_dateFmt.format(_endDate)}'),
                    onPressed: () => _pickDate(isStart: false),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            // Seletor de Tipos
            ExpansionTile(
              title: Text('Tipos ($selectedTypes de $totalTypes)'),
              children: [
                for (var i = 0; i < typeSection.length; i++)
                  CheckboxListTile(
                    title: Text(typeSection[i]!),
                    value: _typeFilters[i],
                    onChanged: (v) {
                      setState(() => _typeFilters[i] = v!);
                    },
                  ),
              ],
            ),

            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
              // Cartão: sessões concluídas vs agendadas
              _buildStatCard(
                title: 'Seções Concluídas',
                value: '$_completedCount / $_scheduledCount',
                ratio: _safeRatio(_completedCount, _scheduledCount),
                activeColor: Colors.green,
              ),

              const SizedBox(height: 16),
              // Cartão: foco real vs programado
              _buildStatCard(
                title: 'Foco Real vs Programado (hh:mm:ss)',
                value:
                    '${_formatSecs(_actualFocusSecs)} / ${_formatSecs(_scheduledFocusSecs)}',
                ratio: _safeRatio(_actualFocusSecs, _scheduledFocusSecs),
                activeColor: Colors.blue,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required double ratio,
    required Color activeColor,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              backgroundColor: Colors.grey.shade300,
              color: activeColor,
              minHeight: 8,
            ),
          ],
        ),
      ),
    );
  }
}
