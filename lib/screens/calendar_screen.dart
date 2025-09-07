// lib/screens/calendar_screen.dart

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:intl/intl.dart';

import '../components/side_menu.dart';
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
  // Controller que realmente comanda a troca de view no SfCalendar
  final CalendarController _calendarController = CalendarController();

  @override
  void initState() {
    super.initState();
    // Sincroniza o controller com a _view inicial
    _calendarController.view = _view;
    _initCalendar();
  }

  Future<void> _initCalendar() async {
    final headers = await _authService.getAuthHeaders();
    if (headers == null) {
      _showError('Não foi possível autenticar com o Google.');
      return;
    }

    _calendarService = GoogleCalendarService(GoogleAuthClient(headers));
    await _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    setState(() => _isLoading = true);
    try {
      final events = await _calendarService.fetchAllEvents();
      _appointments = events.map((e) {
        final start = e.start!.dateTime!.toLocal();
        final end = e.end!.dateTime!.toLocal();
        return Appointment(
          startTime: start,
          endTime: end,
          subject: e.summary ?? 'Sem título',
          notes: e.description,
          id: e.id,
          color: eventColorMap[e.colorId] ?? Colors.deepPurple,
        );
      }).toList();
    } catch (e) {
      _showError('Erro ao carregar eventos: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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

    Future<int> _getTypeIndex() async {
      try {
        final props = await _calendarService.getEventExtendedProperties(
          appt.id as String,
        );
        return typeSection.entries
            .firstWhere(
              (e) => e.value == props['type'],
              orElse: () => const MapEntry(0, 'Nenhum'),
            )
            .key;
      } catch (_) {
        return 0;
      }
    }

    final colorEntry = eventColorMap.entries.firstWhere(
      (e) => e.value == appt.color,
      orElse: () => const MapEntry('6', Colors.deepPurple),
    );

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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _openEventDialog(appt.startTime, appt: appt);
            },
            child: const Text('Editar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final typeIdx = await _getTypeIndex();
              await _calendarService.alterEventOnCalendar(
                eventId: appt.id as String,
                start: appt.startTime,
                end: appt.endTime,
                novoTitulo: appt.subject,
                novaDescricao: appt.notes ?? '',
                typeSectionIndex: typeIdx,
                statusSectionIndex: 2, // Concluído
                calendarId: 'primary',
                colorId: colorEntry.key,
              );
              await _loadAppointments();
            },
            child: const Text('Concluir'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final typeIdx = await _getTypeIndex();
              await _calendarService.alterEventOnCalendar(
                eventId: appt.id as String,
                start: appt.startTime,
                end: appt.endTime,
                novoTitulo: appt.subject,
                novaDescricao: appt.notes ?? '',
                typeSectionIndex: typeIdx,
                statusSectionIndex: 4, // Cancelado
                calendarId: 'primary',
                colorId: colorEntry.key,
              );
              await _loadAppointments();
            },
            child: const Text('Cancelar'),
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

  Future<void> _openEventDialog(
    DateTime initialDate, {
    Appointment? appt,
  }) async {
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
        final props = await _calendarService.getEventExtendedProperties(
          appt.id as String,
        );
        typeIndex = typeSection.entries
            .firstWhere(
              (e) => e.value == props['type'],
              orElse: () => const MapEntry(0, 'Nenhum'),
            )
            .key;
        statusIndex = statusSection.entries
            .firstWhere(
              (e) => e.value == props['status'],
              orElse: () => const MapEntry(1, 'Agendado'),
            )
            .key;
      } catch (_) {}
    }

    await showDialog(
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
                const SizedBox(height: 8),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Descrição'),
                ),
                const SizedBox(height: 12),

                ElevatedButton(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: start,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (d == null) return;
                    final t = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(start),
                    );
                    if (t == null) return;
                    setState(() {
                      start = DateTime(
                        d.year,
                        d.month,
                        d.day,
                        t.hour,
                        t.minute,
                      );
                      if (appt == null)
                        end = start.add(const Duration(hours: 1));
                    });
                  },
                  child: Text(
                    'Início: ${DateFormat('dd/MM/yyyy HH:mm').format(start)}',
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: end,
                      firstDate: DateTime(2000),
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
                  child: Text(
                    'Fim:    ${DateFormat('dd/MM/yyyy HH:mm').format(end)}',
                  ),
                ),
                const SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  value: colorId,
                  decoration: const InputDecoration(labelText: 'Cor'),
                  items: eventColorMap.entries.map((e) {
                    return DropdownMenuItem(
                      value: e.key,
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: e.value,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(eventColorNames[e.key]!),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => colorId = v!),
                ),
                const SizedBox(height: 12),

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
                const SizedBox(height: 12),

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
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
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
                    start: start,
                    end: end,
                    novoTitulo: titleCtrl.text.trim(),
                    novaDescricao: descCtrl.text.trim(),
                    typeSectionIndex: typeIndex,
                    statusSectionIndex: statusIndex,
                    calendarId: 'primary',
                    colorId: colorId,
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
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');
    final timeFmt = DateFormat('HH:mm');

    // prepara próximos 5 eventos
    final now = DateTime.now();
    final upcoming =
        _appointments.where((a) => a.startTime.isAfter(now)).toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));

    return Scaffold(
      drawer: const SideMenu(),
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        centerTitle: true,
        title: const Text(
          'Agenda',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ToggleButtons Dia / Semana / Mês
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: ToggleButtons(
                    borderRadius: BorderRadius.circular(4),
                    selectedColor: Colors.white,
                    fillColor: Colors.deepPurple,
                    color: Colors.deepPurple,
                    isSelected: [
                      _view == CalendarView.day,
                      _view == CalendarView.week,
                      _view == CalendarView.month,
                    ],
                    onPressed: (i) {
                      final views = [
                        CalendarView.day,
                        CalendarView.week,
                        CalendarView.month,
                      ];
                      _changeView(views[i]);
                    },
                    children: const [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Icon(Icons.calendar_view_day),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Icon(Icons.view_week),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Icon(Icons.calendar_month),
                      ),
                    ],
                  ),
                ),

                // Calendário Syncfusion
                Expanded(
                  child: SfCalendar(
                    controller: _calendarController,
                    dataSource: AppointmentDataSource(_appointments),
                    onTap: _onTap,
                    firstDayOfWeek: 1,
                  ),
                ),

                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Próximos eventos',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (upcoming.isEmpty)
                        const Text('Nenhum evento futuro.')
                      else
                        ...upcoming.take(5).map((a) {
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(a.subject),
                            subtitle: Text(
                              '${dateFmt.format(a.startTime)} até ${timeFmt.format(a.endTime)}',
                            ),
                            onTap: () => _showDetailsDialog(a),
                          );
                        }),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  void _changeView(CalendarView view) {
    setState(() => _view = view);
    _calendarController.view = view;
  }
}

class AppointmentDataSource extends CalendarDataSource {
  AppointmentDataSource(List<Appointment> source) {
    appointments = source;
  }
}
