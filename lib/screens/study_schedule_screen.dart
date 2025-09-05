// lib/screens/study_schedule_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/google_auth_client.dart';
import '../services/google_calendar_service.dart';
import '../services/constants.dart';

class StudyScheduleScreen extends StatefulWidget {
  const StudyScheduleScreen({Key? key}) : super(key: key);

  @override
  State<StudyScheduleScreen> createState() => _StudyScheduleScreenState();
}

class _StudyScheduleScreenState extends State<StudyScheduleScreen> {
  final _authService = AuthService();
  late final GoogleCalendarService _calendarService;
  bool _calendarInitialized = false;

  // campo de título e descrição com textos padrão
  //static const defaultStudySessionTitle = '[StudyFlow] Sessão de Estudo';
  //static const defaultStudySessionDes  = 'Sessão de estudos gerada pelo StudyFlow';
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late FocusNode _titleFocus;
  late FocusNode _descFocus;

  // Configurações de agendamento
  int _semanas = 4;
  TimeOfDay _inicio = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _fim    = const TimeOfDay(hour: 10, minute: 0);
  List<bool> _diasSelecionados = List.filled(7, false);
  bool _manterSessoes = false;
  final String _agendaId = 'primary';

  // Resultados
  List<DateTime> _sessoesGeradas = [];
  List<int>      _duracoes        = [];
  List<String>   _conflitos       = [];

  bool _isLoading = false;
  bool _isSaving  = false;

  static const _weekDays = ['Seg','Ter','Qua','Qui','Sex','Sáb','Dom'];

  // estilo padrão deep purple / branco / negrito
  late final ButtonStyle _buttonStyle = ElevatedButton.styleFrom(
    backgroundColor: Colors.deepPurple,
    foregroundColor: Colors.white,
    textStyle: const TextStyle(fontWeight: FontWeight.bold),
  );

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: defaultStudySessionTitle);
    _descController  = TextEditingController(text: defaultStudySessionDes);
    _titleFocus = FocusNode()..addListener(_onTitleFocusChange);
    _descFocus  = FocusNode()..addListener(_onDescFocusChange);
    _initCalendarService();
  }

  void _onTitleFocusChange() {
    if (_titleFocus.hasFocus) {
      if (_titleController.text == defaultStudySessionTitle) {
        _titleController.clear();
      }
    } else {
      if (_titleController.text.trim().isEmpty) {
        _titleController.text = defaultStudySessionTitle;
      }
    }
  }

  void _onDescFocusChange() {
    if (_descFocus.hasFocus) {
      if (_descController.text == defaultStudySessionDes) {
        _descController.clear();
      }
    } else {
      if (_descController.text.trim().isEmpty) {
        _descController.text = defaultStudySessionDes;
      }
    }
  }

  @override
  void dispose() {
    _titleFocus.dispose();
    _descFocus.dispose();
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _initCalendarService() async {
    final headers = await _authService.getAuthHeaders();
    if (headers == null) {
      _showError('Não foi possível autenticar com o Google.');
      return;
    }
    _calendarService = GoogleCalendarService(GoogleAuthClient(headers));
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
          dia.year, dia.month, dia.day,
          inicioMin ~/ 60, inicioMin % 60,
        );
        final end = start.add(Duration(minutes: dur));

        final evs = await _calendarService.fetchEventsBetween(
          start: start, end: end, calendarId: _agendaId);
        if (evs.isNotEmpty) {
          final ev = evs.first;
          final fmt = DateFormat('dd/MM HH:mm');
          final ini = fmt.format(ev.start!.dateTime!.toLocal());
          final fi  = fmt.format(ev.end!.dateTime!.toLocal());
          final ttl = ev.summary ?? '(Sem título)';
          conflitos.add('⚠️ ${fmt.format(start)} conflita com "$ttl" ($ini–$fi)');
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

  Future<void> _salvarSessoes() async {
    if (_sessoesGeradas.isEmpty) {
      _showError('Gere sessões antes de salvar.');
      return;
    }
    setState(() => _isSaving = true);
    try {
      for (int i = 0; i < _sessoesGeradas.length; i++) {
        await _calendarService.insertEventOnCalendar(
          start: _sessoesGeradas[i],
          duracaoMinutos: _duracoes[i],
          titulo: _titleController.text.trim(),
          descricao: _descController.text.trim(),
          sectionTypeIndex: 1,
          statusSectionIndex: 1,
          calendarId: _agendaId,
        );
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sessões salvas com sucesso!')));
    } catch (e) {
      _showError('Erro ao salvar sessões: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _clearSessoes() {
    setState(() {
      _sessoesGeradas.clear();
      _duracoes.clear();
      _conflitos.clear();
    });
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gerador de Sessões')),
      body: !_calendarInitialized
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Título e Descrição
                  TextField(
                    controller: _titleController,
                    focusNode: _titleFocus,
                    decoration: const InputDecoration(
                      labelText: 'Título',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descController,
                    focusNode: _descFocus,
                    decoration: const InputDecoration(
                      labelText: 'Descrição',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),

                  // Semanas
                  Row(
                    children: [
                      const Text('Semanas:'),
                      Expanded(
                        child: Slider(
                          min: 1,
                          max: 12,
                          divisions: 11,
                          label: '$_semanas',
                          value: _semanas.toDouble(),
                          activeColor: Colors.deepPurple,
                          onChanged: (v) => setState(() => _semanas = v.toInt()),
                        ),
                      ),
                      Text('$_semanas'),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Horários
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: _buttonStyle,
                          onPressed: _pickStartTime,
                          child: Text('Início: ${_inicio.format(context)}'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          style: _buttonStyle,
                          onPressed: _pickEndTime,
                          child: Text('Fim: ${_fim.format(context)}'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Dias da semana
                  const Text('Dias da semana:'),
                  const SizedBox(height: 8),
                  ToggleButtons(
                    isSelected: _diasSelecionados,
                    onPressed: (i) =>
                        setState(() => _diasSelecionados[i] = !_diasSelecionados[i]),
                    borderRadius: BorderRadius.circular(8),
                    selectedBorderColor: Colors.deepPurple,
                    selectedColor: Colors.white,
                    fillColor: Colors.deepPurple,
                    color: Colors.deepPurple,
                    children: _weekDays
                        .map((d) => Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child:
                                  Text(d, style: const TextStyle(fontWeight: FontWeight.bold)),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 12),

                  // Manter sessões anteriores
                  Row(
                    children: [
                      const Text('Manter sessões anteriores'),
                      const Spacer(),
                      Switch(
                        activeColor: Colors.deepPurple,
                        value: _manterSessoes,
                        onChanged: (v) => setState(() => _manterSessoes = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Limpar / Gerar / Salvar
                  Row(
                    children: [
                      ElevatedButton(
                        style: _buttonStyle,
                        onPressed: _clearSessoes,
                        child: const Text('Limpar'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          style: _buttonStyle,
                          onPressed: _isLoading ? null : _gerarSessoes,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Gerar Sessões'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    style: _buttonStyle.copyWith(
                        backgroundColor: MaterialStateProperty.all(Colors.green)),
                    onPressed:
                        _isSaving || _sessoesGeradas.isEmpty ? null : _salvarSessoes,
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Salvar Sessões no Calendar'),
                  ),
                  const SizedBox(height: 16),

                  // Lista de resultados
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
                                  '${DateFormat('dd/MM/yyyy HH:mm').format(dt)} — $dur min',
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