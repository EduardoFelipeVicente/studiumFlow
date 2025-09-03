// lib/screens/calendar_screen.dart

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:intl/intl.dart';
import 'package:studyflow/components/side_menu.dart';
import 'package:studyflow/services/auth_service.dart';
import 'package:studyflow/services/google_calendar_service.dart';
import 'package:studyflow/services/constants.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final _authService = AuthService();
  CalendarView _currentView = CalendarView.month;
  bool _isLoading = true;
  List<Appointment> _appointments = [];

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    setState(() => _isLoading = true);

    final token = await _authService.getGoogleAccessToken();
    if (token == null) {
      _showError('Não foi possível obter token do Google');
      setState(() => _isLoading = false);
      return;
    }

    try {
      final service = GoogleCalendarService(token);
      final events = await service.fetchAppointments();
      setState(() => _appointments = events);
    } catch (e) {
      _showError('Erro carregando eventos: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _changeView(CalendarView view) {
    setState(() => _currentView = view);
    _loadAppointments();
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _confirmDelete(Appointment appt) async {
    final token = await _authService.getGoogleAccessToken();
    if (token == null || appt.id == null) {
      _showError('Não foi possível excluir a sessão.');
      return;
    }
    final service = GoogleCalendarService(token);
    await service.deleteSession(appt.id as String);
    await _loadAppointments();
  }

  void _openEditDialog(Appointment appt) {
    final titleCtrl = TextEditingController(text: appt.subject);
    DateTime newStart = appt.startTime;
    DateTime newEnd = appt.endTime;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Editar Sessão'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Título'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                final pickedDate = await showDatePicker(
                  context: context,
                  initialDate: newStart,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (pickedDate == null) return;
                final pickedTime = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(newStart),
                );
                if (pickedTime == null) return;
                newStart = DateTime(
                  pickedDate.year,
                  pickedDate.month,
                  pickedDate.day,
                  pickedTime.hour,
                  pickedTime.minute,
                );
              },
              child: const Text('Alterar Início'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                final pickedDate = await showDatePicker(
                  context: context,
                  initialDate: newEnd,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (pickedDate == null) return;
                final pickedTime = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(newEnd),
                );
                if (pickedTime == null) return;
                newEnd = DateTime(
                  pickedDate.year,
                  pickedDate.month,
                  pickedDate.day,
                  pickedTime.hour,
                  pickedTime.minute,
                );
              },
              child: const Text('Alterar Fim'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final token = await _authService.getGoogleAccessToken();
              if (token == null || appt.id == null) {
                _showError('Não foi possível editar a sessão.');
                return;
              }
              final service = GoogleCalendarService(token);
              await service.updateSession(
                eventId: appt.id as String,
                newStart: newStart,
                newEnd: newEnd,
                newSummary: titleCtrl.text.trim(),
                newDescription: appt.notes,
              );
              await _loadAppointments();
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  void _showAppointmentDetails(Appointment appt) {
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(appt.subject),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Início: ${dateFmt.format(appt.startTime)}'),
            Text('Fim:    ${dateFmt.format(appt.endTime)}'),
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
              _openEditDialog(appt);
            },
            child: const Text('Editar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _confirmDelete(appt);
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _onCalendarTap(CalendarTapDetails details) {
    final appts = details.appointments;
    if (appts != null && appts.isNotEmpty) {
      final Appointment appt = appts.first as Appointment;
      _showAppointmentDetails(appt);
    } else if (details.targetElement == CalendarElement.calendarCell ||
        details.targetElement == CalendarElement.viewHeader) {
      _openAddDialog(details.date!);
    }
  }

  void _openAddDialog(DateTime initialDate) {
    final titleCtrl = TextEditingController();
    final descriptionCtrl = TextEditingController();
    DateTime newStart = initialDate;
    DateTime newEnd = initialDate.add(const Duration(hours: 1));
    String selectedColor = '6';
    String selectedVisibility = 'default';

    final dateFmt = DateFormat('dd/MM/yyyy');
    final timeFmt = DateFormat('HH:mm');

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Novo Evento'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Título
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Título'),
                ),

                const SizedBox(height: 12),

                // Descrição
                TextField(
                  controller: descriptionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Descrição (opcional)',
                  ),
                  maxLines: 2,
                ),

                const SizedBox(height: 12),

                // Cor do Evento
                DropdownButtonFormField<String>(
                  initialValue: selectedColor,
                  decoration: const InputDecoration(labelText: 'Cor do Evento'),
                  items: eventColorNames.keys.map((id) {
                    return DropdownMenuItem<String>(
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
                  onChanged: (v) => setState(() => selectedColor = v!),
                ),

                const SizedBox(height: 12),

                // Visibilidade
                DropdownButtonFormField<String>(
                  initialValue: selectedVisibility,
                  decoration: const InputDecoration(labelText: 'Visibilidade'),
                  items: const [
                    DropdownMenuItem(value: 'default', child: Text('Padrão')),
                    DropdownMenuItem(value: 'private', child: Text('Privado')),
                    DropdownMenuItem(value: 'public', child: Text('Público')),
                  ],
                  onChanged: (v) => setState(() => selectedVisibility = v!),
                ),

                const SizedBox(height: 12),

                // Início
                ElevatedButton(
                  onPressed: () async {
                    final pickedDate = await showDatePicker(
                      context: context,
                      initialDate: newStart,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (pickedDate == null) return;
                    final pickedTime = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(newStart),
                    );
                    if (pickedTime == null) return;
                    setState(() {
                      newStart = DateTime(
                        pickedDate.year,
                        pickedDate.month,
                        pickedDate.day,
                        pickedTime.hour,
                        pickedTime.minute,
                      );
                      newEnd = newStart.add(const Duration(hours: 1));
                    });
                  },
                  child: Text(
                    'Início: ${dateFmt.format(newStart)} ${timeFmt.format(newStart)}',
                  ),
                ),

                const SizedBox(height: 12),

                // Fim
                ElevatedButton(
                  onPressed: () async {
                    final pickedDate = await showDatePicker(
                      context: context,
                      initialDate: newEnd,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (pickedDate == null) return;
                    final pickedTime = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(newEnd),
                    );
                    if (pickedTime == null) return;
                    setState(() {
                      newEnd = DateTime(
                        pickedDate.year,
                        pickedDate.month,
                        pickedDate.day,
                        pickedTime.hour,
                        pickedTime.minute,
                      );
                    });
                  },
                  child: Text(
                    'Fim:    ${dateFmt.format(newEnd)} ${timeFmt.format(newEnd)}',
                  ),
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
                final token = await _authService.getGoogleAccessToken();
                if (token == null) {
                  _showError('Não foi possível obter token.');
                  return;
                }
                final service = GoogleCalendarService(token);
                await service.insertStudySession(
                  start: newStart,
                  focoMinutos: newEnd.difference(newStart).inMinutes,
                  pausaMinutos: 0,
                  titulo: titleCtrl.text.trim(),
                  descricao: descriptionCtrl.text.trim(),
                  sectionTypeIndex: 0,
                  statusSectionIndex: 0,
                  calendarId: 'primary',
                  alertaMinutos: 10,
                  colorId: selectedColor,
                  transparency: 'opaque',
                  visibility: selectedVisibility,
                );
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
        title: const Text('Calendário de Estudos'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Mês',
            onPressed: () => _changeView(CalendarView.month),
          ),
          IconButton(
            icon: const Icon(Icons.view_week),
            tooltip: 'Semana',
            onPressed: () => _changeView(CalendarView.week),
          ),
          IconButton(
            icon: const Icon(Icons.view_day),
            tooltip: 'Dia',
            onPressed: () => _changeView(CalendarView.day),
          ),
          IconButton(
            icon: const Icon(Icons.list),
            tooltip: 'Próximos eventos',
            onPressed: () {
              final now = DateTime.now();
              final upcoming =
                  _appointments.where((a) => a.startTime.isAfter(now)).toList()
                    ..sort((a, b) => a.startTime.compareTo(b.startTime));
              showModalBottomSheet(
                context: context,
                builder: (_) => ListView.builder(
                  itemCount: upcoming.length,
                  itemBuilder: (ctx, i) {
                    final e = upcoming[i];
                    final fmt = DateFormat('dd/MM HH:mm');
                    return ListTile(
                      title: Text(e.subject),
                      subtitle: Text(
                        '${fmt.format(e.startTime)} → ${fmt.format(e.endTime)}',
                      ),
                    );
                  },
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recarregar',
            onPressed: _loadAppointments,
          ),
        ],
      ),
      drawer: const SideMenu(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () => _changeView(CalendarView.day),
                  child: const Text('Dia'),
                ),
                TextButton(
                  onPressed: () => _changeView(CalendarView.week),
                  child: const Text('Semana'),
                ),
                TextButton(
                  onPressed: () => _changeView(CalendarView.month),
                  child: const Text('Mês'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SfCalendar(
                    view: _currentView,
                    firstDayOfWeek: 1,
                    dataSource: MeetingDataSource(_appointments),
                    appointmentTextStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      overflow: TextOverflow.ellipsis,
                    ),
                    monthViewSettings: const MonthViewSettings(
                      appointmentDisplayMode:
                          MonthAppointmentDisplayMode.appointment,
                    ),
                    onTap: _onCalendarTap,
                  ),
          ),
        ],
      ),
    );
  }
}

class MeetingDataSource extends CalendarDataSource {
  MeetingDataSource(List<Appointment> source) {
    appointments = source;
  }
}
