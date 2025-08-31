import 'package:flutter/material.dart';
import 'package:studyflow/services/google_calendar_service.dart';

class StudyScheduleChart extends StatefulWidget {
  const StudyScheduleChart({super.key});

  @override
  State<StudyScheduleChart> createState() => _StudyScheduleChartState();
}

class _StudyScheduleChartState extends State<StudyScheduleChart> {
  TimeOfDay _inicio = const TimeOfDay(hour: 14, minute: 0);
  TimeOfDay _fim = const TimeOfDay(hour: 16, minute: 0);
  List<bool> _diasSelecionados = List.generate(7, (_) => false);
  int _semanas = 2;
  bool _manterSessoes = false;

  List<DateTime> _sessoesGeradas = [];
  List<int> _duracoesFoco = [];

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
                            TextSpan(text: ' (${pausaMinutos} min pausa)'),
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
                      final calendarService = GoogleCalendarService();

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
                          inicio,
                          focoMinutos,
                          pausaMinutos,
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
                      'Salvar Secoes',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
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
