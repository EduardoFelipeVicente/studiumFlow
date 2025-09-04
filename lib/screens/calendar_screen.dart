import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import '../services/google_calendar_service.dart';
import '../services/auth_service.dart';
import '../services/constants.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late GoogleCalendarService _calendarService;
  List<Appointment> _appointments = [];
  CalendarView _view = CalendarView.week;

  @override
  void initState() {
    super.initState();
    _initCalendar();
  }

  Future<void> _initCalendar() async {
    final token = await AuthService().getGoogleAccessToken();
    if (token == null) return;
    _calendarService = GoogleCalendarService(token);
    await _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    final events = await _calendarService.fetchAllEvents();
    setState(() {
      _appointments = events
          .map(
            (e) => Appointment(
              startTime: e.start!.dateTime!.toLocal(),
              endTime: e.end!.dateTime!.toLocal(),
              subject: e.summary ?? '',
              notes: e.description,
              id: e.id,
              color: eventColorMap[e.colorId] ?? Colors.deepPurple,
            ),
          )
          .toList();
    });
  }

  void _onTap(CalendarTapDetails details) {
    final appt = details.appointments?.firstOrNull;
    if (appt != null)
      _showDetailsDialog(appt);
    else
      _openEventDialog(details.date!);
  }

  void _showDetailsDialog(Appointment appt) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(appt.subject),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${appt.startTime} – ${appt.endTime}'),
            if (appt.notes != null) Text(appt.notes!),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
          TextButton(
            onPressed: () => _openEventDialog(appt.startTime, appt: appt),
            child: const Text('Editar'),
          ),
          TextButton(
            onPressed: () => _deleteEvent(appt),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteEvent(Appointment appt) async {
    Navigator.pop(context);
    await _calendarService.deleteEvent(appt.id as String);
    await _loadAppointments();
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

    int typeIndex = 4;
    int statusIndex = 1;

    if (appt != null && appt.id is String) {
      final props = await _calendarService.getEventExtendedProperties(
        appt.id as String,
      );
      typeIndex = typeSection.entries
          .firstWhere(
            (e) => e.value == props['type'],
            orElse: () => const MapEntry(4, 'Outros'),
          )
          .key;
      statusIndex = statusSection.entries
          .firstWhere(
            (e) => e.value == props['status'],
            orElse: () => const MapEntry(1, 'Agendado'),
          )
          .key;
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
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Título'),
                ),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Descrição'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: start,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked == null) return;
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(start),
                    );
                    if (time == null) return;
                    setState(
                      () => start = DateTime(
                        picked.year,
                        picked.month,
                        picked.day,
                        time.hour,
                        time.minute,
                      ),
                    );
                  },
                  child: Text('Início: ${start.toLocal()}'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: end,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked == null) return;
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(end),
                    );
                    if (time == null) return;
                    setState(
                      () => end = DateTime(
                        picked.year,
                        picked.month,
                        picked.day,
                        time.hour,
                        time.minute,
                      ),
                    );
                  },
                  child: Text('Fim: ${end.toLocal()}'),
                ),
                DropdownButtonFormField<String>(
                  value: colorId,
                  decoration: const InputDecoration(labelText: 'Cor'),
                  items: eventColorNames.keys.map((id) {
                    return DropdownMenuItem(
                      value: id,
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: eventColorMap[id],
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(eventColorNames[id]!),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => colorId = v!),
                ),
                DropdownButtonFormField<int>(
                  value: typeIndex,
                  decoration: const InputDecoration(
                    labelText: 'Tipo da Sessão',
                  ),
                  items: typeSection.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => typeIndex = v!),
                ),
                DropdownButtonFormField<int>(
                  value: statusIndex,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: statusSection.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => statusIndex = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
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
          IconButton(
            icon: const Icon(Icons.calendar_view_day),
            onPressed: () => setState(() => _view = CalendarView.day),
          ),
          IconButton(
            icon: const Icon(Icons.view_week),
            onPressed: () => setState(() => _view = CalendarView.week),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () => setState(() => _view = CalendarView.month),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SfCalendar(
              view: _view,
              dataSource: AppointmentDataSource(_appointments),
              onTap: _onTap,
              initialDisplayDate: DateTime.now(),
            ),
          ),
        ],
      ),
    );
  }
}

class AppointmentDataSource extends CalendarDataSource {
  AppointmentDataSource(List<Appointment> source) {
    appointments = source;
  }
}
