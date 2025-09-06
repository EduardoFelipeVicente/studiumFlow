// lib/screens/study_schedule_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/auth_service.dart';
import '../services/google_auth_client.dart';
import '../services/google_calendar_service.dart';
import '../components/side_menu.dart';
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

  // Título e descrição
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late FocusNode _titleFocus;
  late FocusNode _descFocus;

  // Configurações de agendamento
  int _semanas = 4;
  TimeOfDay _inicio = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _fim = const TimeOfDay(hour: 10, minute: 0);
  List<bool> _diasSelecionados = List.filled(7, false);
  bool _manterSessoes = false;
  final String _agendaId = 'primary';

  // Resultados
  List<DateTime> _sessoesGeradas = [];
  List<int> _duracoesGeradas = [];
  List<String> _titulosGerados = [];
  List<String> _descricoesGeradas = [];
  List<String> _conflitosGerados = [];

  bool _isLoading = false;
  bool _isSaving = false;

  static const _weekDays = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

  // Estilo de botão Deep Purple / branco / negrito
  late final ButtonStyle _buttonStyle = ElevatedButton.styleFrom(
    backgroundColor: Colors.deepPurple,
    foregroundColor: Colors.white,
    textStyle: const TextStyle(fontWeight: FontWeight.bold),
  );

  @override
  void initState() {
    super.initState();
    // controllers de título e descrição
    _titleController = TextEditingController(text: defaultStudySessionTitle);
    _descController = TextEditingController(text: defaultStudySessionDes);
    _titleFocus = FocusNode()..addListener(_onTitleFocusChange);
    _descFocus = FocusNode()..addListener(_onDescFocusChange);
    _initCalendarService();
  }

  void _onTitleFocusChange() {
    if (_titleFocus.hasFocus &&
        _titleController.text == defaultStudySessionTitle) {
      _titleController.clear();
    } else if (!_titleFocus.hasFocus && _titleController.text.trim().isEmpty) {
      _titleController.text = defaultStudySessionTitle;
    }
  }

  void _onDescFocusChange() {
    if (_descFocus.hasFocus && _descController.text == defaultStudySessionDes) {
      _descController.clear();
    } else if (!_descFocus.hasFocus && _descController.text.trim().isEmpty) {
      _descController.text = defaultStudySessionDes;
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

    // 1) Título e descrição digitados pelo usuário no momento da geração
    final userTitle = _titleController.text.trim();
    final userDesc = _descController.text.trim();

    // 2) Se não for acumular (_manterSessoes == false), limpar tudo antes
    if (!_manterSessoes) {
      _sessoesGeradas.clear();
      _duracoesGeradas.clear();
      _titulosGerados.clear();
      _descricoesGeradas.clear();
      _conflitosGerados.clear();
    }

    final hoje = DateTime.now();
    final novas = <DateTime>[];
    final duracoes = <int>[];
    final titulos = <String>[];
    final descrs = <String>[];
    final conflitos = <String>[];

    final fmtDt = DateFormat('dd/MM/yyyy');
    final fmtTm = DateFormat('HH:mm');

    // 3) Loop de semanas e dias selecionados
    for (int semana = 0; semana < _semanas; semana++) {
      for (int i = 0; i < 7; i++) {
        if (!_diasSelecionados[i]) continue;

        // calcula o próximo dia daquela semana
        final offset = (i + 1 - hoje.weekday + 7) % 7;
        final dia = hoje.add(Duration(days: offset + semana * 7));

        // intervalo em minutos
        final inicioMin = _inicio.hour * 60 + _inicio.minute;
        final fimMin = _fim.hour * 60 + _fim.minute;
        final dur = fimMin - inicioMin;
        if (dur <= 0) continue;

        // instantes
        final start = DateTime(
          dia.year,
          dia.month,
          dia.day,
          inicioMin ~/ 60,
          inicioMin % 60,
        );
        final end = start.add(Duration(minutes: dur));

        // verifica conflitos no Calendar
        final evs = await _calendarService.fetchEventsBetween(
          start: start,
          end: end,
          calendarId: _agendaId,
        );

        // 4) monta título e descrição sempre a partir do input
        final tituloSessao = userTitle.isNotEmpty
            ? userTitle
            : 'Sessão ${fmtDt.format(start)} ${fmtTm.format(start)}';
        final descricaoSessao = userDesc;

        // 5) prepara texto de conflito (ou string vazia se não houver)
        if (evs.isNotEmpty) {
          final ev = evs.first;
          final ini = fmtTm.format(ev.start!.dateTime!.toLocal());
          final fi = fmtTm.format(ev.end!.dateTime!.toLocal());
          conflitos.add(
            '⚠️ Conflito em ${fmtDt.format(start)} '
            '${fmtTm.format(start)}–${fmtTm.format(end)}: '
            '"${ev.summary ?? '(Sem título)'}" ($ini–$fi)',
          );
        } else {
          conflitos.add(''); // sem conflito
        }

        // 6) acumula nos arrays temporários
        novas.add(start);
        duracoes.add(dur);
        titulos.add(tituloSessao);
        descrs.add(descricaoSessao);
      }
    }

    // 7) persiste no estado, acumulando ou sobrescrevendo conforme a flag
    setState(() {
      _sessoesGeradas.addAll(novas);
      _duracoesGeradas.addAll(duracoes);
      _titulosGerados.addAll(titulos);
      _descricoesGeradas.addAll(descrs);
      _conflitosGerados.addAll(conflitos);
      _isLoading = false;
    });
  }

  Future<void> _salvarSessoes() async {
    if (_sessoesGeradas.isEmpty) {
      _showError('Nenhuma sessão foi gerada para poder salvar!');
      return;
    }
    setState(() => _isSaving = true);

    // 1) detecta índices que têm conflito
    final conflictIdx = <int>[];
    for (var i = 0; i < _conflitosGerados.length; i++) {
      if (_conflitosGerados[i].contains('⚠️')) {
        conflictIdx.add(i);
      }
    }

    // 2) se houver conflito, pergunta ao usuário
    String? decision = 'all';
    if (conflictIdx.isNotEmpty) {
      decision = await _confirmarConflitos();
    }

    // 3) se o usuário cancelar ou escolher 'none', aborta
    if (decision == null || decision == 'none') {
      setState(() => _isSaving = false);
      return;
    }

    // 4) monta a lista de índices que serão efetivamente salvos
    final allIdx = List.generate(_sessoesGeradas.length, (i) => i);
    late final List<int> toSave;
    if (decision == 'partial') {
      toSave = allIdx.where((i) => !conflictIdx.contains(i)).toList();
    } else {
      toSave = allIdx;
    }

    // 5) insere cada sessão no calendário usando título/descrição individuais
    try {
      for (final i in toSave) {
        await _calendarService.insertEventOnCalendar(
          start: _sessoesGeradas[i],
          duracaoMinutos: _duracoesGeradas[i],
          titulo: _titulosGerados[i],
          descricao: _descricoesGeradas[i],
          sectionTypeIndex: 1, // Seção Estudo
          statusSectionIndex: 1, // Agendado
          calendarId: _agendaId,
        );
      }

      // 6) feedback de sucesso
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sessões salvas com sucesso!')),
      );

      // 7) remove dos buffers apenas os itens que foram salvos
      setState(() {
        for (final i in toSave.reversed) {
          _sessoesGeradas.removeAt(i);
          _duracoesGeradas.removeAt(i);
          _titulosGerados.removeAt(i);
          _descricoesGeradas.removeAt(i);
          _conflitosGerados.removeAt(i);
        }
      });
    } catch (e) {
      _showError('Erro ao salvar sessões: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _clearSessoes() {
    setState(() {
      _sessoesGeradas.clear();
      _duracoesGeradas.clear();
      _conflitosGerados.clear();
    });
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd/MM/yyyy');
    final timeFmt = DateFormat('HH:mm');

    return Scaffold(
      drawer: const SideMenu(),
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Gerar Sessões de Estudo',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: !_calendarInitialized
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Título e descrição
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
                              onChanged: (v) =>
                                  setState(() => _semanas = v.toInt()),
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
                        onPressed: (i) => setState(
                          () => _diasSelecionados[i] = !_diasSelecionados[i],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        selectedBorderColor: Colors.deepPurple,
                        selectedColor: Colors.white,
                        fillColor: Colors.deepPurple,
                        color: Colors.deepPurple,
                        children: _weekDays
                            .map(
                              (d) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Text(
                                  d,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            )
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
                            onChanged: (v) =>
                                setState(() => _manterSessoes = v),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Limpar Sessões & Gerar Sessões
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: _buttonStyle,
                              onPressed: _clearSessoes,
                              child: const Text('Limpar Sessões'),
                            ),
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
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Gerar Sessões'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Salvar Sessões no Calendar
                      ElevatedButton(
                        style: _buttonStyle,
                        onPressed: _isSaving || _sessoesGeradas.isEmpty
                            ? null
                            : _salvarSessoes,
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Salvar Sessões no Calendar'),
                      ),
                      const SizedBox(height: 16),

                      // Título "Sessões Geradas"
                      const Text(
                        'Sessões Geradas',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // lista de sessões geradas
                      if (_sessoesGeradas.isEmpty)
                        const Text('Nenhuma sessão gerada.')
                      else
                        for (int i = 0; i < _sessoesGeradas.length; i++) ...[
                          Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // título
                                  Text(
                                    _titulosGerados[i],
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),

                                  // data e intervalo
                                  Text(
                                    '${dateFmt.format(_sessoesGeradas[i])} '
                                    '${timeFmt.format(_sessoesGeradas[i])} até '
                                    '${timeFmt.format(_sessoesGeradas[i].add(Duration(minutes: _duracoesGeradas[i])))}',
                                    style: const TextStyle(color: Colors.grey),
                                  ),

                                  // descrição
                                  if (_descricoesGeradas[i].isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(_descricoesGeradas[i]),
                                  ],

                                  // conflito (se houver)
                                  if (_conflitosGerados[i].contains('⚠️')) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      _conflitosGerados[i],
                                      style: const TextStyle(color: Colors.red),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                    ],
                  ),
                ),

                // overlay de carregamento/salvamento
                if (_isLoading || _isSaving) ...[
                  const Opacity(
                    opacity: 0.6,
                    child: ModalBarrier(
                      dismissible: false,
                      color: Colors.black,
                    ),
                  ),
                  const Center(child: CircularProgressIndicator()),
                ],
              ],
            ),
    );
  }

  Future<String?> _confirmarConflitos() {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Conflitos detectados'),
        content: const Text(
          'Existem conflitos nas sessões agendadas com eventos já registrados no calendário.',
        ),
        actions: [
          TextButton(
            child: const Text('Retornar'),
            onPressed: () => Navigator.of(ctx).pop('none'),
          ),
          TextButton(
            child: const Text('Gravar não conflitantes'),
            onPressed: () => Navigator.of(ctx).pop('partial'),
          ),
          TextButton(
            child: const Text('Gravar mesmo assim'),
            onPressed: () => Navigator.of(ctx).pop('all'),
          ),
        ],
      ),
    );
  }
}
