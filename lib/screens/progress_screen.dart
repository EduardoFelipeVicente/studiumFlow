// lib/screens/progress_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../components/side_menu.dart';
import '../services/auth_service.dart';
import '../services/google_auth_client.dart';
import '../services/google_calendar_service.dart';
import '../services/constants.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({Key? key}) : super(key: key);

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final _auth = AuthService();
  late GoogleCalendarService _calService;

  bool _isLoading = true;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();

  late final List<String> _types = typeSection.values
      .whereType<String>()
      .skip(1)
      .toList();

  late final List<String> _statuses = statusSection.values
      .whereType<String>()
      .skip(1)
      .toList();

  Map<String, int> _statusCounts = {};
  Map<String, Map<String, int>> _typeStatusCounts = {};

  int _scheduledSecs = 0;
  int _focusSecs = 0;
  int _pauseSecs = 0;

  final _dateFmt = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _statusCounts = {for (var s in _statuses) s: 0};
    _typeStatusCounts = {
      for (var t in _types) t: {for (var s in _statuses) s: 0},
    };
    _initLoad();
  }

  Future<void> _initLoad() async {
    final headers = await _auth.getAuthHeaders();
    _calService = GoogleCalendarService(GoogleAuthClient(headers!));
    await _loadProgress();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_startDate.isAfter(_endDate)) _endDate = _startDate;
      } else {
        _endDate = picked;
        if (_endDate.isBefore(_startDate)) _startDate = _endDate;
      }
    });
    await _loadProgress();
  }

  Future<void> _loadProgress() async {
    setState(() => _isLoading = true);

    final events = await _calService.fetchStudySessions(
      timeMin: _startDate.toUtc(),
      timeMax: _endDate.toUtc(),
    );

    _statusCounts = {for (var s in _statuses) s: 0};
    _typeStatusCounts = {
      for (var t in _types) t: {for (var s in _statuses) s: 0},
    };
    _scheduledSecs = 0;
    _focusSecs = 0;
    _pauseSecs = 0;

    for (var ev in events) {
      final s = ev.extendedProperties?.private?['status'];
      final t = ev.extendedProperties?.private?['type'];

      if (_statuses.contains(s)) {
        _statusCounts[s!] = _statusCounts[s]! + 1;
        if (_types.contains(t)) {
          _typeStatusCounts[t!]![s] = _typeStatusCounts[t]![s]! + 1;
        }
      }

      final start = ev.start?.dateTime;
      final end = ev.end?.dateTime;
      if (start != null && end != null) {
        _scheduledSecs += end.difference(start).inSeconds;
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
    final total = _statusCounts.values.fold<int>(0, (a, b) => a + b).toDouble();

    return Scaffold(
      drawer: const SideMenu(),
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        centerTitle: true,
        title: const Text(
          'Progresso',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          icon: const Icon(Icons.date_range),
                          label: Text('De: ${_dateFmt.format(_startDate)}'),
                          onPressed: () => _pickDate(isStart: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextButton.icon(
                          icon: const Icon(Icons.date_range),
                          label: Text('Até: ${_dateFmt.format(_endDate)}'),
                          onPressed: () => _pickDate(isStart: false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // PieChart
                  SizedBox(
                    height: 180,
                    child: PieChart(
                      PieChartData(
                        centerSpaceRadius: 30,
                        sectionsSpace: 4,
                        sections: _statuses
                            .where((s) => _statusCounts[s]! > 0)
                            .map((status) {
                              final count = _statusCounts[status]!.toDouble();
                              final pct = total > 0
                                  ? '${(count / total * 100).toStringAsFixed(0)}%'
                                  : '0%';
                              final color =
                                  statusColorMap[status] ?? Colors.grey;
                              return PieChartSectionData(
                                value: count,
                                color: color,
                                radius: 50,
                                title: pct,
                                titleStyle: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.white,
                                ),
                              );
                            })
                            .toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: _statuses.where((s) => _statusCounts[s]! > 0).map(
                      (s) {
                        final color = statusColorMap[s] ?? Colors.grey;
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 12, height: 12, color: color),
                            const SizedBox(width: 4),
                            Text(s, style: const TextStyle(fontSize: 12)),
                          ],
                        );
                      },
                    ).toList(),
                  ),

                  const SizedBox(height: 32),

                  // BarChart vertical
                  SizedBox(
                    height: 200,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: _typeStatusCounts.values
                            .map((m) => m.values.fold<int>(0, (a, b) => a + b))
                            .fold<int>(0, (mx, v) => v > mx ? v : mx)
                            .toDouble(),
                        barGroups: _types.asMap().entries.map((e) {
                          final idx = e.key;
                          final type = e.value;
                          double acc = 0;
                          final stacks = <BarChartRodStackItem>[];
                          for (var status in _statuses) {
                            final count = _typeStatusCounts[type]![status]!
                                .toDouble();
                            if (count > 0) {
                              final color =
                                  statusColorMap[status] ?? Colors.grey;
                              stacks.add(
                                BarChartRodStackItem(acc, acc + count, color),
                              );
                              acc += count;
                            }
                          }
                          return BarChartGroupData(
                            x: idx,
                            barRods: [
                              BarChartRodData(
                                toY: acc,
                                width: 20,
                                rodStackItems: stacks,
                              ),
                            ],
                          );
                        }).toList(),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              getTitlesWidget: (value, meta) {
                                final i = value.toInt();
                                final label = (i >= 0 && i < _types.length)
                                    ? _types[i]
                                    : '';
                                return SideTitleWidget(
                                  axisSide: meta.axisSide,
                                  child: Text(
                                    label,
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                );
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 28,
                              interval: 1,
                              getTitlesWidget: (value, meta) {
                                return SideTitleWidget(
                                  axisSide: meta.axisSide,
                                  child: Text(
                                    value.toInt().toString(),
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                );
                              },
                            ),
                          ),
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        gridData: FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Cards de tempo
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildInfoCard(
                        label: 'Programado',
                        value: _formatHms(_scheduledSecs),
                        color: const Color.fromARGB(255, 11, 0, 172),
                      ),
                      _buildInfoCard(
                        label: 'Realizado',
                        value: _formatHms(_focusSecs + _pauseSecs),
                        color: const Color.fromARGB(255, 15, 128, 0),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildInfoCard(
                        label: 'Foco',
                        value: _formatHms(_focusSecs),
                        color: const Color.fromARGB(255, 146, 52, 23),
                      ),
                      _buildInfoCard(
                        label: 'Pausa',
                        value: _formatHms(_pauseSecs),
                        color: const Color.fromARGB(255, 136, 122, 1),
                      ),
                    ],
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
                fontSize: 14,
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
