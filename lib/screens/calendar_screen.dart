// lib/screens/calendar_screen.dart

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:studyflow/screens/components/side_menu.dart';
import 'package:studyflow/services/auth_service.dart';
import 'package:studyflow/services/google_calendar_service.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({Key? key}) : super(key: key);

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final _authService = AuthService();
  CalendarView _currentView = CalendarView.month;
  DateTime _focusedDay = DateTime.now();
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
      setState(() {
        _appointments = events;
      });
    } catch (e) {
      _showError('Erro carregando eventos: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    await _authService.logout();
    // Aqui você pode redirecionar de volta para a tela de login
    Navigator.of(context).pushReplacementNamed('/login');
  }

  void _goToPreviousMonth() {
    setState(() {
      _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1, 1);
    });
  }

  void _goToNextMonth() {
    setState(() {
      _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1, 1);
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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
            icon: const Icon(Icons.refresh),
            tooltip: 'Recarregar',
            onPressed: _loadAppointments,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: _logout,
          ),
        ],
      ),
      drawer: const SideMenu(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SfCalendar(
              view: _currentView,
              initialDisplayDate: _focusedDay,
              firstDayOfWeek: 1,
              dataSource: MeetingDataSource(_appointments),
              monthViewSettings: const MonthViewSettings(
                appointmentDisplayMode:
                    MonthAppointmentDisplayMode.appointment,
              ),
              onViewChanged: (_) {}, // opcional, quem sabe usar depois
            ),
      floatingActionButton: !_isLoading
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.chevron_left),
              label: const Text('Anterior'),
              onPressed: _goToPreviousMonth,
            )
          : null,
      bottomNavigationBar: !_isLoading
          ? BottomAppBar(
              child: IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _goToNextMonth,
              ),
            )
          : null,
    );
  }
}

class MeetingDataSource extends CalendarDataSource {
  MeetingDataSource(List<Appointment> source) {
    appointments = source;
  }
}
