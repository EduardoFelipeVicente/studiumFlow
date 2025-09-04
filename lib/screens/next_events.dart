// lib/screens/next_events.dart

import 'package:flutter/material.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:intl/intl.dart';

import '../components/side_menu.dart';
import '../services/auth_service.dart';
import '../services/google_calendar_service.dart';
import '../services/constants.dart';

class NextEventsScreen extends StatefulWidget {
  const NextEventsScreen({Key? key}) : super(key: key);

  @override
  _NextEventsScreenState createState() => _NextEventsScreenState();
}

class _NextEventsScreenState extends State<NextEventsScreen> {
  final _authService = AuthService();
  late final GoogleCalendarService _service;
  List<calendar.Event> _events = [];
  bool _isLoading = false;

  late final List<int> _allTypes;
  Set<int> _selectedTypes = {};
  bool _groupByDate = true;

  @override
  void initState() {
    super.initState();
    _allTypes = typeSection.keys.where((k) => k != 0).toList();
    _selectedTypes = Set.from(_allTypes);
    _init();
  }

  Future<void> _init() async {
    setState(() => _isLoading = true);
    final token = await _authService.getGoogleAccessToken();
    if (token == null) {
      _showError('Não foi possível obter credenciais Google.');
      return;
    }
    _service = GoogleCalendarService(token);
    await _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    final allItems = <calendar.Event>[];

    for (var idx in _selectedTypes) {
      final label = typeSection[idx]!;
      final items = await _service.fetchNextStudySessions(
        maxResults: 20,
        privateExtendedProperties: ['type=$label'],
      );
      allItems.addAll(items);
    }

    allItems.sort((a, b) {
      final aDt = a.start?.dateTime?.toUtc() ?? DateTime(0);
      final bDt = b.start?.dateTime?.toUtc() ?? DateTime(0);
      return aDt.compareTo(bDt);
    });

    setState(() {
      _events = allItems.take(20).toList();
      _isLoading = false;
    });
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd/MM/yyyy');
    final timeFmt = DateFormat('HH:mm');

    return Scaffold(
      // 1) adiciona Sidebar
      drawer: const SideMenu(),

      appBar: AppBar(
        title: const Text('Próximos Eventos'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Column(
        children: [
          // filtros de tipo
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Wrap(
              spacing: 8,
              children: _allTypes.map((idx) {
                final label = typeSection[idx]!;
                return FilterChip(
                  label: Text(label),
                  selected: _selectedTypes.contains(idx),
                  onSelected: (sel) {
                    setState(() {
                      if (sel)
                        _selectedTypes.add(idx);
                      else
                        _selectedTypes.remove(idx);
                    });
                    _loadEvents();
                  },
                );
              }).toList(),
            ),
          ),

          // toggle Agrupar
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ToggleButtons(
              isSelected: [_groupByDate, !_groupByDate],
              onPressed: (i) {
                setState(() => _groupByDate = (i == 0));
              },
              borderRadius: BorderRadius.circular(8),
              selectedColor: Colors.white,
              fillColor: Colors.deepPurple,
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Por Data'),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Por Tipo'),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // lista de eventos ou loading
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildGroupedList(dateFmt, timeFmt),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedList(DateFormat dateFmt, DateFormat timeFmt) {
    if (_events.isEmpty) {
      return const Center(child: Text('Nenhuma evento encontrado.'));
    }
    final list = _groupByDate
        ? _buildByDate(dateFmt, timeFmt)
        : _buildByType(dateFmt, timeFmt);
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: list,
    );
  }

  List<Widget> _buildByDate(DateFormat dateFmt, DateFormat timeFmt) {
    final Map<String, List<calendar.Event>> grouped = {};
    for (var ev in _events) {
      final dt = ev.start?.dateTime?.toLocal();
      if (dt == null) continue;
      final key = dateFmt.format(dt);
      grouped.putIfAbsent(key, () => []).add(ev);
    }
    final dates = grouped.keys.toList()
      ..sort((a, b) => dateFmt.parse(a).compareTo(dateFmt.parse(b)));

    final widgets = <Widget>[];
    for (var dateKey in dates) {
      widgets.add(_buildSectionHeader(dateKey));
      for (var ev in grouped[dateKey]!) {
        widgets.add(_buildEventTile(ev, dateFmt, timeFmt));
      }
    }
    return widgets;
  }

  List<Widget> _buildByType(DateFormat dateFmt, DateFormat timeFmt) {
    final Map<String, List<calendar.Event>> grouped = {};
    for (var ev in _events) {
      final type = ev.extendedProperties?.private?['type'] ?? '—';
      grouped.putIfAbsent(type, () => []).add(ev);
    }
    final preferredOrder = [
      typeSection[1]!,
      typeSection[2]!,
      typeSection[3]!,
      typeSection[4]!,
    ];
    final widgets = <Widget>[];
    for (var typeLabel in preferredOrder) {
      final list = grouped[typeLabel];
      if (list == null || list.isEmpty) continue;
      widgets.add(_buildSectionHeader(typeLabel));
      for (var ev in list) {
        widgets.add(_buildEventTile(ev, dateFmt, timeFmt, isTypeMode: true));
      }
    }
    return widgets;
  }

  Widget _buildSectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildEventTile(
    calendar.Event ev,
    DateFormat dateFmt,
    DateFormat timeFmt, {
    bool isTypeMode = false,
  }) {
    final start = ev.start?.dateTime?.toLocal();
    final end = ev.end?.dateTime?.toLocal();

    final parts = <String>[];

    if (!isTypeMode) {
      // MODO POR DATA: mostra apenas tipo + horário
      final type = ev.extendedProperties?.private?['type'];
      if (type != null && type.isNotEmpty) {
        parts.add(type);
      }
      if (start != null && end != null) {
        parts.add('${timeFmt.format(start)} – ${timeFmt.format(end)}');
      }
    } else {
      // MODO POR TIPO: mostra data + horário
      if (start != null && end != null) {
        parts.add(
          '${dateFmt.format(start)} ${timeFmt.format(start)} – ${timeFmt.format(end)}',
        );
      }
    }

    final subtitleText = parts.join(' • ');
    final color = eventColorMap[ev.colorId] ?? Colors.deepPurple;

    return ListTile(
      leading: Icon(Icons.event, color: color),
      title: Text(ev.summary ?? '(Sem título)'),
      subtitle: subtitleText.isEmpty ? null : Text(subtitleText),
    );
  }
}
