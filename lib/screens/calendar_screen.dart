// lib/screens/calendar_screen.dart

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:intl/intl.dart';

import '../services/auth_service.dart';
import '../services/google_auth_client.dart';
import '../services/google_calendar_service.dart';
import '../services/constants.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({Key? key}) : super(key: key);

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final _authService = AuthService();
  late GoogleCalendarService _calendarService;

  bool _isLoading = true;
  List<Appointment> _appointments = [];
  CalendarView _view = CalendarView.week;

  @override
  void initState() {
    super.initState();
    _initCalendar();
  }

  Future<void> _initCalendar() async {
    final headers = await _authService.getAuthHeaders();
    if (headers == null) {
      _showError('Não foi possível autenticar com o Google.');
      return;
    }
    final client = GoogleAuthClient(headers);
    _calendarService = GoogleCalendarService(client);
    await _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    setState(() => _isLoading = true);
    try {
      final events = await _calendarService.fetchAllEvents();
      _appointments = events.map((e) {
        final s = e.start!.dateTime!.toLocal();
        final t = e.end!.dateTime!.toLocal();
        return Appointment(
          startTime: s,
          endTime: t,
          subject: e.summary ?? 'Sem título',
          notes: e.description,
          id: e.id,
          color: eventColorMap[e.colorId] ?? Colors.deepPurple,
        );
      }).toList();
      setState(() {});
    } catch (e) {
      _showError('Erro ao carregar eventos: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  void _changeView(CalendarView view) {
    setState(() => _view = view);
  }

  void _onTap(CalendarTapDetails details) {
    final appt = details.appointments?.first as Appointment?;
    if (appt != null) {
      _showDetailsDialog(appt);
    } else {
      _openEventDialog(details.date!);
    }
  }

  void _showDetailsDialog(Appointment appt) {
    final fmt = DateFormat('dd/MM/yyyy HH:mm');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(appt.subject),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Início: ${fmt.format(appt.startTime)}'),
            Text('Fim:     ${fmt.format(appt.endTime)}'),
            if (appt.notes != null) ...[
              const SizedBox(height: 8),
              const Text('Descrição:'),
              Text(appt.notes!),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _openEventDialog(appt.startTime, appt: appt);
            },
            child: const Text('Editar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteEvent(appt);
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteEvent(Appointment appt) async {
    try {
      await _calendarService.deleteEvent(appt.id as String);
      await _loadAppointments();
    } catch (e) {
      _showError('Erro ao excluir evento: $e');
    }
  }

  void _openEventDialog(DateTime initialDate, {Appointment? appt}) async {
    final titleCtrl = TextEditingController(text: appt?.subject ?? '');
    final descCtrl = TextEditingController(text: appt?.notes ?? '');
    DateTime start = appt?.startTime ?? initialDate;
    DateTime end = appt?.endTime ?? initialDate.add(const Duration(hours: 1));
    String colorId = eventColorMap.entries
            .firstWhere(
              (e) => e.value == appt?.color,
              orElse: () => const MapEntry('6', Colors.deepPurple),
            )
            .key;

    int typeIndex = 0;
    int statusIndex = 1;

    if (appt != null) {
      try {
        final props = await _calendarService.getEventExtendedProperties(appt.id as String);
        typeIndex = typeSection.entries
            .firstWhere((e) => e.value == props['type'], orElse: () => const MapEntry(0, 'Nenhum'))
            .key;
        statusIndex = statusSection.entries
            .firstWhere((e) => e.value == props['status'], orElse: () => const MapEntry(1, 'Agendado'))
            .key;
      } catch (_) { /* ignora se não encontrar */ }
    }

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(appt == null ? 'Novo Evento' : 'Editar Evento'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Título
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Título')),
                const SizedBox(height: 8),
                // Descrição
                TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Descrição')),
                const SizedBox(height: 12),
                // Início
                ElevatedButton(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: start,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (d == null) return;
                    final t = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(start),
                    );
                    if (t == null) return;
                    setState(() {
                      start = DateTime(d.year, d.month, d.day, t.hour, t.minute);
                      if (appt == null) end = start.add(const Duration(hours: 1));
                    });
                  },
                  child: Text('Início: ${start.toLocal()}'),
                ),
                const SizedBox(height: 8),
                // Fim
                ElevatedButton(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: end,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (d == null) return;
                    final t = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(end),
                    );
                    if (t == null) return;
                    setState(() {
                      end = DateTime(d.year, d.month, d.day, t.hour, t.minute);
                    });
                  },
                  child: Text('Fim: ${end.toLocal()}'),
                ),
                const SizedBox(height: 12),
                // Cor
DropdownButtonFormField<String>(
  value: colorId,
  decoration: const InputDecoration(labelText: 'Cor'),
  items: eventColorMap.entries.map((entry) {
    final id = entry.key;
    final color = entry.value;
    final name = eventColorNames[id]!;
    return DropdownMenuItem(
      value: id,
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,           // agora é um Color de verdade
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(name),
        ],
      ),
    );
  }).toList(),
  onChanged: (v) => setState(() => colorId = v!),
),
                const SizedBox(height: 12),
                // Tipo
                DropdownButtonFormField<int>(
                  value: typeIndex,
                  decoration: const InputDecoration(labelText: 'Tipo da Sessão'),
                  items: typeSection.entries
                      .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                      .toList(),
                  onChanged: (v) => setState(() => typeIndex = v!),
                ),
                const SizedBox(height: 12),
                // Status
                DropdownButtonFormField<int>(
                  value: statusIndex,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: statusSection.entries
                      .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                      .toList(),
                  onChanged: (v) => setState(() => statusIndex = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  if (appt == null) {
                    await _calendarService.insertEventOnCalendar(
                      start: start,
                      duracaoMinutos: end.difference(start).inMinutes,
                      titulo: titleCtrl.text.trim(),
                      descricao: descCtrl.text.trim(),
                      sectionTypeIndex: typeIndex,
                      statusSectionIndex: statusIndex,
                      calendarId: 'primary',
                      colorId: colorId,
                    );
                  } else {
                    await _calendarService.alterEventOnCalendar(
                      eventId: appt.id as String,
                      calendarId: 'primary',
                      novaDescricao: descCtrl.text.trim(),
                      statusSectionIndex: statusIndex,
                    );
                  }
                  await _loadAppointments();
                } catch (e) {
                  _showError('Erro ao salvar evento: $e');
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda'),
        actions: [
          IconButton(icon: const Icon(Icons.calendar_view_day), onPressed: () => _changeView(CalendarView.day)),
          IconButton(icon: const Icon(Icons.view_week), onPressed: () => _changeView(CalendarView.week)),
          IconButton(icon: const Icon(Icons.calendar_month), onPressed: () => _changeView(CalendarView.month)),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAppointments),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SfCalendar(
              view: _view,
              dataSource: AppointmentDataSource(_appointments),
              onTap: _onTap,
              firstDayOfWeek: 1,
            ),
    );
  }
}

class AppointmentDataSource extends CalendarDataSource {
  AppointmentDataSource(List<Appointment> source) {
    appointments = source;
  }
}