// lib/screens/study_schedule_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/auth_service.dart';
import '../services/google_auth_client.dart';
import '../services/google_calendar_service.dart';

class StudyScheduleScreen extends StatefulWidget {
  const StudyScheduleScreen({Key? key}) : super(key: key);

  @override
  State<StudyScheduleScreen> createState() => _StudyScheduleScreenState();
}

class _StudyScheduleScreenState extends State<StudyScheduleScreen> {
  final _authService = AuthService();
  late final GoogleCalendarService _calendarService;
  bool _calendarInitialized = false;

  // Configurações de agendamento (iniciadas com defaults)
  int _semanas = 4;
  TimeOfDay _inicio = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _fim = const TimeOfDay(hour: 10, minute: 0);
  List<bool> _diasSelecionados = List.filled(7, false);
  bool _manterSessoes = false;
  final String _agendaId = 'primary';

  // Resultados
  List<DateTime> _sessoesGeradas = [];
  List<int> _duracoes = [];
  List<String> _conflitos = [];

  bool _isLoading = false;

  static const _weekDays = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

  @override
  void initState() {
    super.initState();
    _initCalendarService();
  }

  Future<void> _initCalendarService() async {
    final headers = await _authService.getAuthHeaders();
    if (headers == null) {
      _showError('Não foi possível autenticar com o Google.');
      return;
    }
    final client = GoogleAuthClient(headers);
    _calendarService = GoogleCalendarService(client);
    setState(() => _calendarInitialized = true);
  }

  Future<void> _pickStartTime() async {
    final t = await showTimePicker(context: context, initialTime: _inicio);
    if (t != null) setState(() => _inicio = t);
  }

  Future<void> _pickEndTime() async {
    final t = await showTimePicker(context: context, initialTime: _fim);
    if (t != null) setState(() => _fim = t);
  }

  Future<void> _gerarSessoes() async {
    if (!_calendarInitialized) {
      _showError('Aguarde a inicialização da agenda.');
      return;
    }
    setState(() => _isLoading = true);

    final hoje = DateTime.now();
    final novas = <DateTime>[];
    final duracoes = <int>[];
    final conflitos = <String>[];

    for (int semana = 0; semana < _semanas; semana++) {
      for (int i = 0; i < 7; i++) {
        if (!_diasSelecionados[i]) continue;

        final offset = (i + 1 - hoje.weekday + 7) % 7;
        final dia = hoje.add(Duration(days: offset + semana * 7));

        final inicioMin = _inicio.hour * 60 + _inicio.minute;
        final fimMin = _fim.hour * 60 + _fim.minute;
        final dur = fimMin - inicioMin;
        if (dur <= 0) continue;

        final start = DateTime(
          dia.year,
          dia.month,
          dia.day,
          inicioMin ~/ 60,
          inicioMin % 60,
        );
        final end = start.add(Duration(minutes: dur));

        final evs = await _calendarService.fetchEventsBetween(
          start: start,
          end: end,
          calendarId: _agendaId,
        );
        if (evs.isNotEmpty) {
          final ev = evs.first;
          final fmt = DateFormat('dd/MM HH:mm');
          final ini = fmt.format(ev.start!.dateTime!.toLocal());
          final fi = fmt.format(ev.end!.dateTime!.toLocal());
          final ttl = ev.summary ?? '(Sem título)';
          conflitos.add(
            '⚠️ ${fmt.format(start)} conflita com "$ttl" ($ini–$fi)',
          );
        } else {
          conflitos.add('');
        }

        novas.add(start);
        duracoes.add(dur);
      }
    }

    setState(() {
      if (_manterSessoes) {
        _sessoesGeradas.addAll(novas);
        _duracoes.addAll(duracoes);
        _conflitos.addAll(conflitos);
      } else {
        _sessoesGeradas = novas;
        _duracoes = duracoes;
        _conflitos = conflitos;
      }
      _isLoading = false;
    });
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final horaFmt = DateFormat.Hm();
    return Scaffold(
      appBar: AppBar(title: const Text('Gerador de Sessões')),
      body: !_calendarInitialized
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Número de semanas
                  Row(
                    children: [
                      const Text('Semanas:'),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Slider(
                          min: 1,
                          max: 12,
                          divisions: 11,
                          label: '$_semanas',
                          value: _semanas.toDouble(),
                          onChanged: (v) =>
                              setState(() => _semanas = v.toInt()),
                        ),
                      ),
                      Text('$_semanas'),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Horário Início e Fim
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _pickStartTime,
                          child: Text('Início: ${_inicio.format(context)}'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _pickEndTime,
                          child: Text('Fim: ${_fim.format(context)}'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Dias da semana
                  Text('Dias da semana:'),
                  Wrap(
                    spacing: 8,
                    children: List.generate(7, (i) {
                      return FilterChip(
                        label: Text(_weekDays[i]),
                        selected: _diasSelecionados[i],
                        onSelected: (sel) {
                          setState(() => _diasSelecionados[i] = sel);
                        },
                      );
                    }),
                  ),

                  const SizedBox(height: 12),

                  // Manter sessões anteriores
                  Row(
                    children: [
                      const Text('Manter sessões anteriores'),
                      Switch(
                        value: _manterSessoes,
                        onChanged: (v) => setState(() => _manterSessoes = v),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Botão gerar
                  ElevatedButton(
                    onPressed: _isLoading ? null : () => _gerarSessoes(),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Gerar Sessões'),
                  ),

                  const SizedBox(height: 16),

                  // Resultados
                  Expanded(
                    child: _sessoesGeradas.isEmpty
                        ? const Center(child: Text('Nenhuma sessão gerada.'))
                        : ListView.separated(
                            itemCount: _sessoesGeradas.length,
                            separatorBuilder: (_, __) => const Divider(),
                            itemBuilder: (ctx, i) {
                              final dt = _sessoesGeradas[i];
                              final dur = _duracoes[i];
                              final msg = _conflitos[i];
                              return ListTile(
                                title: Text(
                                  '${DateFormat('dd/MM/yyyy HH:mm').format(dt)}'
                                  ' — $dur min',
                                ),
                                subtitle: msg.isEmpty ? null : Text(msg),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
