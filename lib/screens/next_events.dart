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

  // controle de visualização: 0=Dia,1=Tipo,2=Status
  int _viewStyle = 0;

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

    // se o usuário já definiu um range, pega do início daquele dia
    final fetchStart = _startDate != null
        ? DateTime(_startDate!.year, _startDate!.month, _startDate!.day)
        : DateTime.now();

    // se definiu fim, pega até 23:59:59 daquele dia
    final fetchEnd = _endDate != null
        ? DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59)
        : DateTime.now().add(const Duration(days: 365));

    try {
      _allEvents = await _service.fetchEventsBetween(
        calendarId: 'primary',
        start: fetchStart,
        end: fetchEnd,
        singleEvents: true,
        orderBy: 'startTime',
      );

      _applyFiltersAndSort();
    } catch (e) {
      _showError('Erro ao carregar eventos: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _applyFiltersAndSort() {
    // aplica filtros de tipo e status
    var filtered = _allEvents.where((e) {
      final props = e.extendedProperties?.private ?? {};
      final type = props['type'] ?? '';
      final status = props['status'] ?? '';
      final okType = _typeFilters.isEmpty || _typeFilters.contains(type);
      final okStatus =
          _statusFilters.isEmpty || _statusFilters.contains(status);
      return okType && okStatus;
    }).toList();

    // filtra por período, se definido, incluindo eventos que começam antes mas ainda estão ativos
    if (_startDate != null && _endDate != null) {
      filtered = filtered.where((e) {
        // tenta pegar dateTime (horário) ou date (all‐day)
        final startLocal =
            e.start?.dateTime?.toLocal() ?? e.start?.date?.toLocal();
        final endLocal = e.end?.dateTime?.toLocal() ?? e.end?.date?.toLocal();
        if (startLocal == null || endLocal == null) return false;

        // overlap: evento termina depois do início do range
        //       E evento começa antes do fim do range
        final overlapStart = !endLocal.isBefore(_startDate!);
        final overlapEnd = !startLocal.isAfter(_endDate!);
        return overlapStart && overlapEnd;
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
      // refaz o fetch já que mudou o intervalo
      await _loadEvents();
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd/MM/yyyy');
    final timeFmt = DateFormat('HH:mm');

    // 1) Agrupa eventos conforme estilo de visualização
    final grouped = <String, List<calendar.Event>>{};
    for (var e in _events) {
      final start = e.start?.dateTime?.toLocal();
      late String key;
      switch (_viewStyle) {
        case 0: // Dia
          key = start != null ? dateFmt.format(start) : 'Sem Data';
          break;
        case 1: // Tipo
          key = e.extendedProperties?.private?['type'] ?? 'Sem Tipo';
          break;
        case 2: // Status
          key = e.extendedProperties?.private?['status'] ?? 'Sem Status';
          break;
        default:
          key = '';
      }
      grouped.putIfAbsent(key, () => []).add(e);
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

                  // filtros multi-select: Tipos e Status
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
                                        if (v! && !_typeFilters.contains(opt))
                                          _typeFilters.add(opt);
                                        else if (!v &&
                                            _typeFilters.contains(opt))
                                          _typeFilters.remove(opt);
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
                                overflow: TextOverflow.ellipsis,
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
                                        if (v! && !_statusFilters.contains(opt))
                                          _statusFilters.add(opt);
                                        else if (!v &&
                                            _statusFilters.contains(opt))
                                          _statusFilters.remove(opt);
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
                                overflow: TextOverflow.ellipsis,
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

                  const SizedBox(height: 16),

                  // toggle de visualização (Dia/Tipo/Status)
                  Center(
                    child: ToggleButtons(
                      isSelected: List.generate(
                        styleViewNextEvents.length,
                        (i) => _viewStyle == i,
                      ),
                      onPressed: (i) => setState(() => _viewStyle = i),
                      borderRadius: BorderRadius.circular(8),
                      selectedColor: Colors.white,
                      fillColor: Colors.deepPurple,
                      color: Colors.deepPurple,
                      constraints: const BoxConstraints(minWidth: 80),
                      children: styleViewNextEvents.entries.map((e) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            e.value,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        );
                      }).toList(),
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

                      for (var e in entry.value) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16, left: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Título
                              Text(
                                e.summary ?? 'Sem título',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              // Data e intervalo de horas
                              if (e.start?.dateTime != null &&
                                  e.end?.dateTime != null)
                                Text(
                                  '${dateFmt.format(e.start!.dateTime!.toLocal())} '
                                  '${timeFmt.format(e.start!.dateTime!.toLocal())} até '
                                  '${timeFmt.format(e.end!.dateTime!.toLocal())}',
                                  style: const TextStyle(color: Colors.black),
                                ),

                              // Tipo / Status
                              Text(
                                'Tipo: ${e.extendedProperties?.private?['type'] ?? 'Sem Tipo'}    '
                                'Status: ${e.extendedProperties?.private?['status'] ?? 'Sem Status'}',
                                style: const TextStyle(color: Colors.black),
                              ),

                              // Descrição
                              if ((e.description ?? '').isNotEmpty)
                                Text(e.description!),

                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ],

                      const Divider(),
                      const SizedBox(height: 16),
                    ],
                ],
              ),
      ),
    );
  }
}
