import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarView _currentView = CalendarView.month;
  DateTime _focusedDay = DateTime.now();
  bool _showAgenda = false;

  final List<Appointment> _appointments = [
    Appointment(
      startTime: DateTime.now().add(const Duration(hours: 2)),
      endTime: DateTime.now().add(const Duration(hours: 3)),
      subject: 'Sessão de Matemática',
      color: Colors.deepPurple,
    ),
    Appointment(
      startTime: DateTime.now().add(const Duration(days: 1, hours: 1)),
      endTime: DateTime.now().add(const Duration(days: 1, hours: 2)),
      subject: 'Revisão de História',
      color: Colors.orange,
    ),
    Appointment(
      startTime: DateTime.now().add(const Duration(days: 2, hours: 1)),
      endTime: DateTime.now().add(const Duration(days: 2, hours: 2)),
      subject: 'Leitura de Filosofia',
      color: Colors.green,
    ),
  ];

  void _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _focusedDay,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: 'Selecionar mês e ano',
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null) {
      setState(() {
        _focusedDay = picked;
      });
    }
  }

  void _goToPreviousMonth() {
    setState(() {
      _focusedDay = DateTime(
        _focusedDay.year,
        _focusedDay.month - 1,
        1,
      );
    });
  }

  void _goToNextMonth() {
    setState(() {
      _focusedDay = DateTime(
        _focusedDay.year,
        _focusedDay.month + 1,
        1,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendário de Estudos'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Mês anterior',
            onPressed: _goToPreviousMonth,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Próximo mês',
            onPressed: _goToNextMonth,
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Selecionar mês/ano',
            onPressed: _selectDate,
          ),
          DropdownButton<CalendarView>(
            value: _currentView,
            dropdownColor: Colors.white,
            underline: const SizedBox(),
            icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
            items: const [
              DropdownMenuItem(value: CalendarView.day, child: Text('Dia')),
              DropdownMenuItem(value: CalendarView.week, child: Text('Semana')),
              DropdownMenuItem(value: CalendarView.month, child: Text('Mês')),
            ],
            onChanged: (view) {
              if (view != null) {
                setState(() {
                  _currentView = view;
                });
              }
            },
          ),
          IconButton(
            icon: Icon(_showAgenda ? Icons.calendar_view_month : Icons.list),
            tooltip: _showAgenda ? 'Ver Calendário' : 'Ver Agenda',
            onPressed: () {
              setState(() {
                _showAgenda = !_showAgenda;
              });
            },
          ),
        ],
      ),
      body: _showAgenda ? _buildAgendaView() : _buildCalendarView(),
    );
  }

  Widget _buildCalendarView() {
    return SfCalendar(
      key: ValueKey(_currentView.toString() + _focusedDay.toString()),
      view: _currentView,
      initialDisplayDate: _focusedDay,
      firstDayOfWeek: 1,
      dataSource: MeetingDataSource(_appointments),
      monthViewSettings: const MonthViewSettings(
        appointmentDisplayMode: MonthAppointmentDisplayMode.appointment,
      ),
    );
  }

  Widget _buildAgendaView() {
    final upcoming = _appointments
        .where((a) => a.startTime.isAfter(DateTime.now()))
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: upcoming.length,
      itemBuilder: (context, index) {
        final event = upcoming[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: ListTile(
            leading: Icon(Icons.event, color: event.color),
            title: Text(event.subject),
            subtitle: Text(
              '${event.startTime.day}/${event.startTime.month} • ${event.startTime.hour.toString().padLeft(2, '0')}:${event.startTime.minute.toString().padLeft(2, '0')}',
            ),
          ),
        );
      },
    );
  }
}

class MeetingDataSource extends CalendarDataSource {
  MeetingDataSource(List<Appointment> source) {
    appointments = source;
  }
}

