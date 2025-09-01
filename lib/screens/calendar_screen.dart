// lib/screens/calendar_screen.dart

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:studyflow/screens/components/side_menu.dart';
import 'package:studyflow/services/auth_service.dart';
import 'package:studyflow/services/google_calendar_service.dart';
import 'package:intl/intl.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({Key? key}) : super(key: key);

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

  // Ajuste: ignora targetElement para abrir detalhes também no Mês
  void _onCalendarTap(CalendarTapDetails details) {
    final appts = details.appointments;
    if (appts != null && appts.isNotEmpty) {
      final Appointment appt = appts.first as Appointment;
      _showAppointmentDetails(appt);
    }
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
        ],
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendário de Estudos'),
        backgroundColor: Colors.deepPurple,
        actions: [
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
          // Seletor de visualização
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

          // Loader ou calendário
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SfCalendar(
                    view: _currentView,
                    firstDayOfWeek: 1,
                    dataSource: MeetingDataSource(_appointments),
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
