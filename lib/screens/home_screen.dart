import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../components/side_menu.dart';
import '../services/google_calendar_service.dart';
import '../services/auth_service.dart';
import '../services/google_auth_client.dart';
import '../services/constants.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _auth = AuthService();
  late GoogleCalendarService _calendarService;

  bool _isLoading = true;
  int _agendadas = 0;
  int _concluidas = 0;
  int _atrasadas = 0;
  int _scheduledSecs = 0;
  int _focusSecs = 0;
  int _pauseSecs = 0;

  List<Map<String, String>> _proximas = [];

  final _dateFmt = DateFormat('dd/MM/yyyy');
  final _timeFmt = DateFormat('HH:mm');

  @override
  void initState() {
    super.initState();
    initAndUpdateLateEvents();
  }

  Future<void> initAndUpdateLateEvents() async {
    final headers = await _auth.getAuthHeaders();
    final client = GoogleAuthClient(headers!);
    _calendarService = GoogleCalendarService(client);

    await _calendarService.updateLateEvents();
    await _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    final now = DateTime.now().toUtc();
    final start = now.subtract(const Duration(days: 7));
    final end = now.add(const Duration(days: 7));

    final events = await _calendarService.fetchStudySessions(
      timeMin: start,
      timeMax: end,
    );

    _agendadas = 0;
    _concluidas = 0;
    _atrasadas = 0;
    _scheduledSecs = 0;
    _focusSecs = 0;
    _pauseSecs = 0;
    _proximas = [];

    for (var ev in events) {
      final status = ev.extendedProperties?.private?['status'];
      final tipo = ev.extendedProperties?.private?['type'];
      final desc = ev.description ?? '';
      final start = ev.start?.dateTime;
      final end = ev.end?.dateTime;

      if (status == statusSection[1]) _agendadas++;
      if (status == statusSection[2]) _concluidas++;
      if (status == statusSection[3]) _atrasadas++;

      if (start != null && end != null) {
        _scheduledSecs += end.difference(start).inSeconds;

        if (start.isAfter(DateTime.now().toUtc())) {
          _proximas.add({
            'title': ev.summary ?? 'Sem título',
            'date': _dateFmt.format(start.toLocal()),
            'start': _timeFmt.format(start.toLocal()),
            'end': _timeFmt.format(end.toLocal()),
            'type': tipo ?? 'Não definido',
            'desc': desc,
          });
        }
      }

      final ft = ev.extendedProperties?.private?['focusTime'];
      final pt = ev.extendedProperties?.private?['pauseTime'];
      if (ft != null) _focusSecs += _parseHms(ft);
      if (pt != null) _pauseSecs += _parseHms(pt);
    }

    setState(() => _isLoading = false);
  }

  int _parseHms(String hhmmss) {
    final p = hhmmss.split(':').map(int.parse).toList();
    return p[0] * 3600 + p[1] * 60 + p[2];
  }

  String _formatHms(int secs) {
    final h = (secs ~/ 3600).toString().padLeft(2, '0');
    final m = ((secs % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (secs % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final total = (_agendadas + _concluidas + _atrasadas).toDouble();
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 7));
    final end = now.add(const Duration(days: 7));
    final intervalo = '${_dateFmt.format(start)} até ${_dateFmt.format(end)}';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        centerTitle: true,
        title: const Text(
          'StudiumFlow',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      drawer: const SideMenu(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Dashboard de Estudos',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Intervalo considerado: $intervalo',
                    style: const TextStyle(fontSize: 14),
                  ),

                  const SizedBox(height: 24),

                  // Gráfico de pizza
                  SizedBox(
                    height: 180,
                    child: PieChart(
                      PieChartData(
                        centerSpaceRadius: 30,
                        sectionsSpace: 4,
                        sections: [
                          if (_agendadas > 0)
                            PieChartSectionData(
                              value: _agendadas.toDouble(),
                              color: statusColorMap['Agendado'],
                              radius: 50,
                              title:
                                  '${(_agendadas / total * 100).toStringAsFixed(0)}%',
                              titleStyle: const TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                          if (_concluidas > 0)
                            PieChartSectionData(
                              value: _concluidas.toDouble(),
                              color: statusColorMap['Concluído'],
                              radius: 50,
                              title:
                                  '${(_concluidas / total * 100).toStringAsFixed(0)}%',
                              titleStyle: const TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                          if (_atrasadas > 0)
                            PieChartSectionData(
                              value: _atrasadas.toDouble(),
                              color: statusColorMap['Atrasado'],
                              radius: 50,
                              title:
                                  '${(_atrasadas / total * 100).toStringAsFixed(0)}%',
                              titleStyle: const TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Cards de tempo
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildInfoCard(
                        label: 'Agendado',
                        value: _formatHms(_scheduledSecs),
                        color: Colors.blue,
                      ),
                      _buildInfoCard(
                        label: 'Realizado',
                        value: _formatHms(_focusSecs + _pauseSecs),
                        color: Colors.green,
                      ),
                      _buildInfoCard(
                        label: 'Foco',
                        value: _formatHms(_focusSecs),
                        color: Colors.deepPurple,
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  const Text(
                    'Próximas Sessões',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  ..._proximas.map(
                    (s) => Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s['title']!,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text('🗓 ${s['date']}'),
                            Text('⏰ ${s['start']} - ${s['end']}'),
                            Text('📌 Tipo: ${s['type']}'),
                            if (s['desc']!.isNotEmpty) Text('📝 ${s['desc']}'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoCard({
    required String label,
    required String value,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
