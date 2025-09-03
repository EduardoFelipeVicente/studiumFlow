import 'package:flutter/material.dart';
import 'package:studyflow/services/google_calendar_service.dart';
import 'package:studyflow/services/auth_service.dart';
import 'package:studyflow/services/constants.dart';

class StudyScheduleChart extends StatefulWidget {
  const StudyScheduleChart({super.key});

  @override
  State<StudyScheduleChart> createState() => _StudyScheduleChartState();
}

class _StudyScheduleChartState extends State<StudyScheduleChart> {


  // Controller e FocusNode para o título
  final TextEditingController _tituloController = TextEditingController(
    text: defaultStudySessionTitle,
  );
  final FocusNode _tituloFocusNode = FocusNode();

  // Controller e FocusNode para a descrição
  final TextEditingController _descricaoController = TextEditingController(
    text: defaultStudySessionDescription,
  );
  final FocusNode _descricaoFocusNode = FocusNode();

  final Map<String, Color> _coresGoogle = eventColorMap;

  // Agendas do usuário
  List<CalendarInfo> _agendasDisponiveis = [];
  String? _agendaSelecionada;

  // Configurações de alerta, cor, transparência e visibilidade
  int _alertaMinutos = 10;
  String _corSelecionada = '6';
  String _transparencia = 'opaque'; // 'opaque' ou 'transparent'
  String _visibilidade = 'default'; // 'default', 'public', 'private'

  TimeOfDay _inicio = const TimeOfDay(hour: 14, minute: 0);
  TimeOfDay _fim = const TimeOfDay(hour: 16, minute: 0);
  final List<bool> _diasSelecionados = List.generate(7, (_) => false);
  int _semanas = 2;
  bool _manterSessoes = false;

  List<DateTime> _sessoesGeradas = [];
  List<int> _duracoesFoco = [];

  void _criarListenersDeFoco() {
    // Listener do título
    _tituloFocusNode.addListener(() {
      if (_tituloFocusNode.hasFocus) {
        // Ao entrar: limpa somente se estiver no padrão
        if (_tituloController.text == defaultStudySessionTitle) {
          _tituloController.clear();
        }
      } else {
        // Ao sair: repõe padrão se vazio
        if (_tituloController.text.trim().isEmpty) {
          _tituloController.text = defaultStudySessionTitle;
        }
      }
    });

    // Listener da descrição
    _descricaoFocusNode.addListener(() {
      if (_descricaoFocusNode.hasFocus) {
        if (_descricaoController.text == defaultStudySessionDescription) {
          _descricaoController.clear();
        }
      } else {
        if (_descricaoController.text.trim().isEmpty) {
          _descricaoController.text = defaultStudySessionDescription;
        }
      }
    });
  }

  @override
  void dispose() {
    // liberar recursos
    _tituloFocusNode.dispose();
    _tituloController.dispose();
    _descricaoFocusNode.dispose();
    _descricaoController.dispose();
    super.dispose();
  }

  Future<void> _criarAgendaDeEstudos() async {
    final token = await AuthService().getGoogleAccessToken();
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao autenticar Google')),
      );
      return;
    }
    final service = GoogleCalendarService(token);

    // O nome que você quer dar à nova agenda
    const String summary = 'StudyFlow Agenda';

    // Cria no Google e retorna apenas o ID
    final String newId = await service.createCalendar(summary: summary);

    // Agora monte o objeto CalendarInfo completo
    final newCalInfo = CalendarInfo(id: newId, summary: summary);

    setState(() {
      // Adiciona o objeto CalendarInfo, não apenas a string
      _agendasDisponiveis.add(newCalInfo);

      // Mantém somente o ID selecionado
      _agendaSelecionada = newCalInfo.id;
    });
  }

  @override
  void initState() {
    super.initState();
    _carregarAgendas();
  }

  Future<void> _carregarAgendas() async {
    final token = await AuthService().getGoogleAccessToken();
    if (token == null) return;
    final service = GoogleCalendarService(token);

    final list = await service.listCalendars();
    setState(() {
      _agendasDisponiveis = list;
      _agendaSelecionada = list.first.id;
    });
  }

  void _gerarSessoesPomodoro() {
    final hoje = DateTime.now();
    final List<DateTime> novasSessoes = [];
    final List<int> novasDuracoes = [];

    if (!_manterSessoes) {
      _sessoesGeradas.clear();
      _duracoesFoco.clear();
    }

    const int minFoco = 20;
    const int maxFoco = 30;
    const int pausaCurta = 5;
    const int pausaLonga = 15;

    for (int semana = 0; semana < _semanas; semana++) {
      for (int i = 0; i < 7; i++) {
        if (_diasSelecionados[i]) {
          final diaBase = hoje.add(Duration(days: i + semana * 7));
          final inicioMinutos = _inicio.hour * 60 + _inicio.minute;
          final fimMinutos = _fim.hour * 60 + _fim.minute;
          int tempoDisponivel = fimMinutos - inicioMinutos;

          final List<int> blocos = [];
          int contadorFocoDia = 0;

          while (true) {
            int foco = maxFoco;
            while (foco >= minFoco) {
              if (tempoDisponivel >= foco + pausaCurta) break;
              foco--;
            }

            if (foco < minFoco || tempoDisponivel < foco + pausaCurta) break;

            blocos.add(foco);
            tempoDisponivel -= foco;
            contadorFocoDia++;

            final pausa = pausaCurta;
            if (tempoDisponivel >= pausa) {
              tempoDisponivel -= pausa;
            } else {
              break;
            }
          }

          int tempoAtual = inicioMinutos;
          for (int j = 0; j < blocos.length; j++) {
            final focoMinutos = blocos[j];
            final hora = tempoAtual ~/ 60;
            final minuto = tempoAtual % 60;
            final sessao = DateTime(
              diaBase.year,
              diaBase.month,
              diaBase.day,
              hora,
              minuto,
            );
            final focoFim = sessao.add(Duration(minutes: focoMinutos));

            // Verifica sobreposição
            final sobrepoe = _sessoesGeradas.any((s) {
              final fimExistente = s.add(
                Duration(minutes: _duracoesFoco[_sessoesGeradas.indexOf(s)]),
              );
              return (sessao.isBefore(fimExistente) && focoFim.isAfter(s));
            });

            if (!sobrepoe) {
              novasSessoes.add(sessao);
              novasDuracoes.add(focoMinutos);
            }

            tempoAtual += focoMinutos;
            final pausa = (blocos.length > 4 && (j + 1) % 4 == 0)
                ? pausaLonga
                : pausaCurta;
            tempoAtual += pausa;
          }
        }
      }
    }

    setState(() {
      if (_manterSessoes) {
        _sessoesGeradas.addAll(novasSessoes);
        _duracoesFoco.addAll(novasDuracoes);
      } else {
        _sessoesGeradas = novasSessoes;
        _duracoesFoco = novasDuracoes;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Criar Agenda de Estudos'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text(
              'Dias da semana:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Wrap(
              spacing: 8,
              children: List.generate(7, (i) {
                final dias = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sab', 'Dom'];
                return FilterChip(
                  label: Text(dias[i]),
                  selected: _diasSelecionados[i],
                  onSelected: (val) =>
                      setState(() => _diasSelecionados[i] = val),
                );
              }),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    title: const Text('Inicio'),
                    subtitle: Text(_inicio.format(context)),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _inicio,
                      );
                      if (picked != null) setState(() => _inicio = picked);
                    },
                  ),
                ),
                Expanded(
                  child: ListTile(
                    title: const Text('Fim'),
                    subtitle: Text(_fim.format(context)),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _fim,
                      );
                      if (picked != null) setState(() => _fim = picked);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Repetir por:'),
                const SizedBox(width: 12),
                DropdownButton<int>(
                  value: _semanas,
                  items: List.generate(
                    8,
                    (i) => DropdownMenuItem(
                      value: i + 1,
                      child: Text('${i + 1} semanas'),
                    ),
                  ),
                  onChanged: (val) => setState(() => _semanas = val!),
                ),
              ],
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('Manter secoes geradas anteriormente'),
              value: _manterSessoes,
              onChanged: (val) => setState(() => _manterSessoes = val!),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 24),

            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Configurações do Evento',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Título do evento
                  TextField(
                    controller: _tituloController,
                    focusNode: _tituloFocusNode,
                    decoration: const InputDecoration(
                      labelText: 'Título do Evento',
                      hintText: 'Ex: Matemática, História...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Descrição opcional
                  TextField(
                    controller: _descricaoController,
                    focusNode: _descricaoFocusNode,
                    decoration: const InputDecoration(
                      labelText: 'Descrição (opcional)',
                      hintText: 'Sessão gerada automaticamente pelo StudyFlow',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),

                  // Escolha da agenda
                  DropdownButtonFormField<String>(
                    value: _agendaSelecionada,
                    decoration: const InputDecoration(
                      labelText: 'Agenda do Google Calendar',
                      border: OutlineInputBorder(),
                    ),
                    items: _agendasDisponiveis.map((cal) {
                      return DropdownMenuItem<String>(
                        value: cal.id, // mantém o id como value
                        child: Text(cal.summary), // exibe o summary (apelido)
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _agendaSelecionada = v),
                  ),
                  TextButton(
                    onPressed: _criarAgendaDeEstudos,
                    child: const Text(
                      'Criar agenda de estudos',
                      style: TextStyle(
                        color: Colors.deepPurple,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Tempo de alerta
                  DropdownButtonFormField<int>(
                    value: _alertaMinutos,
                    items: [5, 10, 15, 30].map((min) {
                      return DropdownMenuItem(
                        value: min,
                        child: Text('$min minutos antes'),
                      );
                    }).toList(),
                    onChanged: (value) =>
                        setState(() => _alertaMinutos = value ?? 10),
                    decoration: const InputDecoration(
                      labelText: 'Alerta antes da sessão',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    value: _corSelecionada,
                    decoration: const InputDecoration(
                      labelText: 'Cor do Evento',
                      border: OutlineInputBorder(),
                    ),
                    items: _coresGoogle.entries.map((entry) {
                      final id = entry.key;
                      final color = entry.value;
                      final name = eventColorNames[id]!;

                      // Cor do Evento
                      return DropdownMenuItem<String>(
                        value: id,
                        child: Row(
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Text(name),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) =>
                        setState(() => _corSelecionada = value ?? '6'),
                  ),
                  const SizedBox(height: 12),

                  // Transparência
                  DropdownButtonFormField<String>(
                    value: _transparencia,
                    items: const [
                      DropdownMenuItem(value: 'opaque', child: Text('Ocupado')),
                      DropdownMenuItem(
                        value: 'transparent',
                        child: Text('Livre'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _transparencia = value ?? 'opaque'),
                    decoration: const InputDecoration(
                      labelText: 'Disponibilidade',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Visibilidade
                  DropdownButtonFormField<String>(
                    value: _visibilidade,
                    items: const [
                      DropdownMenuItem(value: 'default', child: Text('Padrão')),
                      DropdownMenuItem(value: 'public', child: Text('Público')),
                      DropdownMenuItem(
                        value: 'private',
                        child: Text('Particular'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _visibilidade = value ?? 'default'),
                    decoration: const InputDecoration(
                      labelText: 'Visibilidade',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _sessoesGeradas.clear();
                        _duracoesFoco.clear();
                      });
                    },
                    icon: const Icon(Icons.delete, color: Colors.white),
                    label: const Text(
                      'Limpa Secoes',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[700],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _gerarSessoesPomodoro,
                    icon: const Icon(Icons.play_arrow, color: Colors.white),
                    label: const Text(
                      'Gerar Secoes',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_sessoesGeradas.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Secoes geradas:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ..._sessoesGeradas.asMap().entries.map((entry) {
                    final index = entry.key;
                    final focoInicio = entry.value;
                    final focoMinutos = _duracoesFoco[index];
                    final focoFim = focoInicio.add(
                      Duration(minutes: focoMinutos),
                    );

                    final diaAtual = DateTime(
                      focoInicio.year,
                      focoInicio.month,
                      focoInicio.day,
                    );
                    final sessoesDoDia = _sessoesGeradas
                        .where(
                          (s) =>
                              s.year == diaAtual.year &&
                              s.month == diaAtual.month &&
                              s.day == diaAtual.day,
                        )
                        .toList();

                    final indexNoDia = sessoesDoDia.indexOf(focoInicio);
                    final pausaMinutos =
                        (sessoesDoDia.length > 4 && (indexNoDia + 1) % 4 == 0)
                        ? 15
                        : 5;
                    final pausaFim = focoFim.add(
                      Duration(minutes: pausaMinutos),
                    );

                    final dia =
                        '${focoInicio.day.toString().padLeft(2, '0')}/${focoInicio.month.toString().padLeft(2, '0')}';
                    final horaFocoInicio =
                        '${focoInicio.hour.toString().padLeft(2, '0')}:${focoInicio.minute.toString().padLeft(2, '0')}';
                    final horaFocoFim =
                        '${focoFim.hour.toString().padLeft(2, '0')}:${focoFim.minute.toString().padLeft(2, '0')}';
                    final horaPausa =
                        '${pausaFim.hour.toString().padLeft(2, '0')}:${pausaFim.minute.toString().padLeft(2, '0')}';

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(color: Colors.black),
                          children: [
                            TextSpan(
                              text: '$dia * $horaFocoInicio–$horaFocoFim–',
                            ),
                            TextSpan(
                              text: horaPausa,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextSpan(text: ' ($pausaMinutos min pausa)'),
                          ],
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 16),
                  Text(
                    'Total de sessoes: ${_sessoesGeradas.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () async {
                      // 1) Pega o token do Google já autenticado pelo AuthService
                      final token = await AuthService().getGoogleAccessToken();
                      if (token == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Não foi possível obter token do Google',
                            ),
                          ),
                        );
                        return;
                      }

                      // 2) Cria instância do CalendarService com o token
                      final calendarService = GoogleCalendarService(token);

                      // 3) Insere todas as sessões no Google Calendar
                      for (int i = 0; i < _sessoesGeradas.length; i++) {
                        final inicio = _sessoesGeradas[i];
                        final focoMinutos = _duracoesFoco[i];

                        final sessoesDoDia = _sessoesGeradas
                            .where(
                              (s) =>
                                  s.year == inicio.year &&
                                  s.month == inicio.month &&
                                  s.day == inicio.day,
                            )
                            .toList();

                        final indexNoDia = sessoesDoDia.indexOf(inicio);
                        final pausaMinutos =
                            (sessoesDoDia.length > 4 &&
                                (indexNoDia + 1) % 4 == 0)
                            ? 15
                            : 5;

                        await calendarService.insertStudySession(
                          start: inicio,
                          focoMinutos: focoMinutos,
                          pausaMinutos: pausaMinutos,
                          titulo: _tituloController.text.trim(),
                          descricao: _descricaoController.text.trim(),
                          calendarId: _agendaSelecionada!,
                          alertaMinutos: _alertaMinutos,
                          colorId: _corSelecionada,
                          transparency: _transparencia,
                          visibility: _visibilidade,
                        );
                      }

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Sessões salvas no Google Calendar!'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.save, color: Colors.white),
                    label: const Text(
                      'Salvar Sessões',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
