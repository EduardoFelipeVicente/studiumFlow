// lib/screens/next_events.dart

import 'package:flutter/material.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:intl/intl.dart';

import '../components/side_menu.dart';
import '../services/auth_service.dart';
import '../services/google_auth_client.dart';
import '../services/google_calendar_service.dart';
import '../services/constants.dart';

class NextEventsScreen extends StatefulWidget {
  const NextEventsScreen({Key? key}) : super(key: key);

  @override
  State<NextEventsScreen> createState() => _NextEventsScreenState();
}

class _NextEventsScreenState extends State<NextEventsScreen> {
  final _authService = AuthService();
  late GoogleCalendarService _service;

  // controllers para abrir/fechar manualmente os menus
  final MenuController _typeMenuController = MenuController();
  final MenuController _statusMenuController = MenuController();

  bool _isLoading = true;
  List<calendar.Event> _allEvents = [];
  List<calendar.Event> _events = [];

  // filtros múltiplos
  final List<String> _typeFilters = [];
  final List<String> _statusFilters = [];

  // opções de filtro (valores dos maps em constants.dart)
  late final List<String> _typeOptions = typeSection.values.toList();
  late final List<String> _statusOptions = statusSection.values.toList();

  // filtro de período
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() => _isLoading = true);
    final headers = await _authService.getAuthHeaders();
    if (headers == null) {
      _showError('Não foi possível obter credenciais Google.');
      setState(() => _isLoading = false);
      return;
    }
    _service = GoogleCalendarService(GoogleAuthClient(headers));
    await _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final start = now;
      final end = now.add(const Duration(days: 365));

      _allEvents = await _service.fetchEventsBetween(
        calendarId: 'primary',
        start: start,
        end: end,
      );

      _applyFiltersAndSort();
    } catch (e) {
      _showError('Erro ao carregar eventos: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _applyFiltersAndSort() {
    // filtra por tipo/status
    var filtered = _allEvents.where((e) {
      final props = e.extendedProperties?.private ?? {};
      final type = props['type'] ?? '';
      final status = props['status'] ?? '';

      final okType = _typeFilters.isEmpty || _typeFilters.contains(type);
      final okStatus =
          _statusFilters.isEmpty || _statusFilters.contains(status);
      return okType && okStatus;
    }).toList();

    // filtra por período, se definido
    if (_startDate != null && _endDate != null) {
      filtered = filtered.where((e) {
        final dt = e.start?.dateTime?.toLocal();
        if (dt == null) return false;
        return !dt.isBefore(_startDate!) && !dt.isAfter(_endDate!);
      }).toList();
    }

    // ordena por data de início
    filtered.sort((a, b) {
      final da = a.start?.dateTime ?? DateTime.now();
      final db = b.start?.dateTime ?? DateTime.now();
      return da.compareTo(db);
    });

    setState(() => _events = filtered);
  }

  Future<void> _pickDateRange() async {
    final initial = (_startDate != null && _endDate != null)
        ? DateTimeRange(start: _startDate!, end: _endDate!)
        : null;

    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: initial,
    );
    if (range != null) {
      setState(() {
        _startDate = range.start;
        _endDate = range.end;
      });
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd/MM/yyyy');
    final timeFmt = DateFormat('HH:mm');

    // agrupa eventos por tipo
    final grouped = <String, List<calendar.Event>>{};
    for (var e in _events) {
      final type = e.extendedProperties?.private?['type'] ?? 'Sem Tipo';
      grouped.putIfAbsent(type, () => []).add(e);
    }

    return Scaffold(
      drawer: const SideMenu(),
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        centerTitle: true,
        title: const Text(
          'Próximos Eventos',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadEvents,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // picker de período
                  OutlinedButton.icon(
                    icon: const Icon(
                      Icons.date_range,
                      color: Colors.deepPurple,
                    ),
                    label: Text(
                      _startDate == null
                          ? 'Selecionar Período'
                          : '${dateFmt.format(_startDate!)} → ${dateFmt.format(_endDate!)}',
                      style: const TextStyle(color: Colors.deepPurple),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.deepPurple),
                    ),
                    onPressed: _pickDateRange,
                  ),
                  const SizedBox(height: 12),

                  // filtros multi‐select: Tipos e Status
                  Row(
                    children: [
                      // Tipos
                      Expanded(
                        child: MenuAnchor(
                          controller: _typeMenuController,
                          menuChildren: [
                            for (final opt in _typeOptions)
                              StatefulBuilder(
                                builder: (ctx, setMenuState) {
                                  final sel = _typeFilters.contains(opt);
                                  return CheckboxListTile(
                                    title: Text(opt),
                                    value: sel,
                                    onChanged: (v) {
                                      setState(() {
                                        if (v! && !_typeFilters.contains(opt)) {
                                          _typeFilters.add(opt);
                                        } else if (!v &&
                                            _typeFilters.contains(opt)) {
                                          _typeFilters.remove(opt);
                                        }
                                      });
                                      setMenuState(() {});
                                      if (_typeFilters.length ==
                                          _typeOptions.length) {
                                        _typeMenuController.close();
                                      }
                                    },
                                  );
                                },
                              ),
                          ],
                          builder: (ctx, controller, child) {
                            return OutlinedButton(
                              onPressed: () => controller.open(),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.deepPurple),
                              ),
                              child: Text(
                                _typeFilters.isEmpty
                                    ? 'Selecionar Tipos'
                                    : _typeFilters.join(', '),
                                maxLines: 1,
                                softWrap: false,
                                style: const TextStyle(
                                  color: Colors.deepPurple,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Status
                      Expanded(
                        child: MenuAnchor(
                          controller: _statusMenuController,
                          menuChildren: [
                            for (final opt in _statusOptions)
                              StatefulBuilder(
                                builder: (ctx, setMenuState) {
                                  final sel = _statusFilters.contains(opt);
                                  return CheckboxListTile(
                                    title: Text(opt),
                                    value: sel,
                                    onChanged: (v) {
                                      setState(() {
                                        if (v! &&
                                            !_statusFilters.contains(opt)) {
                                          _statusFilters.add(opt);
                                        } else if (!v &&
                                            _statusFilters.contains(opt)) {
                                          _statusFilters.remove(opt);
                                        }
                                      });
                                      setMenuState(() {});
                                      if (_statusFilters.length ==
                                          _statusOptions.length) {
                                        _statusMenuController.close();
                                      }
                                    },
                                  );
                                },
                              ),
                          ],
                          builder: (ctx, controller, child) {
                            return OutlinedButton(
                              onPressed: () => controller.open(),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.deepPurple),
                              ),
                              child: Text(
                                _statusFilters.isEmpty
                                    ? 'Selecionar Status'
                                    : _statusFilters.join(', '),
                                maxLines: 1,
                                softWrap: false,                                
                                style: const TextStyle(
                                  color: Colors.deepPurple,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // aplicar filtros
                  ElevatedButton.icon(
                    onPressed: _applyFiltersAndSort,
                    icon: const Icon(Icons.filter_list),
                    label: const Text('Aplicar Filtros'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // listagem agrupada
                  if (grouped.isEmpty)
                    const Center(child: Text('Nenhum evento encontrado.'))
                  else
                    for (final entry in grouped.entries) ...[
                      Text(
                        entry.key,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ...entry.value.map((e) {
                        final start = e.start?.dateTime?.toLocal();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12, left: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e.summary ?? 'Sem título',
                                style: const TextStyle(fontSize: 16),
                              ),
                              if (start != null)
                                Text(
                                  '${dateFmt.format(start)} ${timeFmt.format(start)}',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        );
                      }),
                      const Divider(),
                      const SizedBox(height: 16),
                    ],
                ],
              ),
      ),
    );
  }
}
