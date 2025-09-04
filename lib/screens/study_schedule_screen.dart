import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/google_calendar_service.dart';
import '../services/auth_service.dart';
import '../services/constants.dart';

class StudyScheduleScreen extends StatefulWidget {
  const StudyScheduleScreen({super.key});
  @override
  State<StudyScheduleScreen> createState() => _StudyScheduleScreenState();
}

class _StudyScheduleScreenState extends State<StudyScheduleScreen> {
  final _tituloCtrl = TextEditingController(text: defaultStudySessionTitle);
  final _descricaoCtrl = TextEditingController(text: defaultStudySessionDescription);
  final _diasSelecionados = List.generate(7, (_) => false);
  final _sessoesGeradas = <DateTime>[];
  final _duracoes = <int>[];
  final _conflitos = <String>[];

  TimeOfDay _inicio = const TimeOfDay(hour: 14, minute: 0);
  TimeOfDay _fim = const TimeOfDay(hour: 18, minute: 0);
  int _semanas = 2;
  bool _manterSessoes = false;
  String _cor = '6', _visibilidade = 'default';
  int _alertaMinutos = 10;
  String _agendaId = 'primary';

  Future<void> _gerarSessoes() async {
    final hoje = DateTime.now();
    final novasSessoes = <DateTime>[];
    final novasDuracoes = <int>[];
    final novosConflitos = <String>[];

    final token = await AuthService().getGoogleAccessToken();
    if (token == null) return;
    final service = GoogleCalendarService(token);

    for (int semana = 0; semana < _semanas; semana++) {
      for (int i = 0; i < 7; i++) {
        if (_diasSelecionados[i]) {
          final dia = hoje.add(Duration(days: i + semana * 7));
          final inicioMin = _inicio.hour * 60 + _inicio.minute;
          final fimMin = _fim.hour * 60 + _fim.minute;
          final duracao = fimMin - inicioMin;
          final hora = inicioMin ~/ 60, minuto = inicioMin % 60;
          final inicio = DateTime(dia.year, dia.month, dia.day, hora, minuto);
          final fim = inicio.add(Duration(minutes: duracao));

          final eventosExistentes = await service.fetchEventsBetween(
            start: inicio,
            end: fim,
            calendarId: _agendaId,
          );

          if (eventosExistentes.isNotEmpty) {
            final ev = eventosExistentes.first;
            final evInicio = DateFormat('HH:mm').format(ev.start!.dateTime!.toLocal());
            final evFim = DateFormat('HH:mm').format(ev.end!.dateTime!.toLocal());
            final titulo = ev.summary ?? '(Sem título)';
            novosConflitos.add('⚠️ ${DateFormat('dd/MM HH:mm').format(inicio)} conflita com "$titulo" ($evInicio–$evFim)');
          }

          novasSessoes.add(inicio);
          novasDuracoes.add(duracao);
        }
      }
    }

    setState(() {
      if (_manterSessoes) {
        _sessoesGeradas.addAll(novasSessoes);
        _duracoes.addAll(novasDuracoes);
        _conflitos.addAll(novosConflitos);
      } else {
        _sessoesGeradas
          ..clear()
          ..addAll(novasSessoes);
        _duracoes
          ..clear()
          ..addAll(novasDuracoes);
        _conflitos
          ..clear()
          ..addAll(novosConflitos);
      }
    });
  }

  Future<void> _salvarSessoes() async {
    if (_conflitos.isNotEmpty) {
      final continuar = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Conflitos detectados'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Há sessões que conflitam com eventos existentes:'),
              const SizedBox(height: 8),
              ..._conflitos.map((c) => Text(c, style: const TextStyle(fontSize: 13))),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Verificar')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continuar')),
          ],
        ),
      );
      if (continuar != true) return;
    }

    final token = await AuthService().getGoogleAccessToken();
    if (token == null) return;
    final service = GoogleCalendarService(token);

    for (int i = 0; i < _sessoesGeradas.length; i++) {
      await service.insertEventOnCalendar(
        start: _sessoesGeradas[i],
        duracaoMinutos: _duracoes[i],
        titulo: _tituloCtrl.text.trim(),
        descricao: _descricaoCtrl.text.trim(),
        sectionTypeIndex: 1,
        statusSectionIndex: 1,
        calendarId: _agendaId,
        alertaMinutos: _alertaMinutos,
        colorId: _cor,
        transparency: 'opaque',
        visibility: _visibilidade,
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sessões salvas com sucesso!')));
  }

  Widget _buildListaSessoes() {
    final dateFmt = DateFormat('dd/MM');
    final timeFmt = DateFormat('HH:mm');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Seções geradas:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ..._sessoesGeradas.asMap().entries.map((entry) {
          final i = entry.key;
          final inicio = entry.value;
          final fim = inicio.add(Duration(minutes: _duracoes[i]));
          final conflito = _conflitos.length > i ? _conflitos[i] : null;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              conflito ??
                  '${dateFmt.format(inicio)} • ${timeFmt.format(inicio)}–${timeFmt.format(fim)} (${_duracoes[i]} min)',
              style: TextStyle(fontSize: 14, color: conflito != null ? Colors.red : Colors.black),
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Criar Agenda de Estudos')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _tituloCtrl, decoration: const InputDecoration(labelText: 'Título')),
            TextField(controller: _descricaoCtrl, decoration: const InputDecoration(labelText: 'Descrição')),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _gerarSessoes, child: const Text('Gerar Seções')),
            const SizedBox(height: 12),
            Expanded(child: SingleChildScrollView(child: _buildListaSessoes())),
            ElevatedButton(onPressed: _salvarSessoes, child: const Text('Salvar Sessões')),
          ],
        ),
      ),
    );
  }
}