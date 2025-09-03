// lib/screens/next_events.dart

import 'package:flutter/material.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:intl/intl.dart';

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

  // Tipos que podem ser filtrados (sem o “0: Nenhum” por padrão)
  late final List<int> _allTypes;
  Set<int> _selectedTypes = {};

  bool _isLoading = false;
  List<calendar.Event> _events = [];

  @override
  void initState() {
    super.initState();
    // Todos os índices exceto o 0 (Nenhum)
    _allTypes = typeSection.keys.where((k) => k != 0).toList();
    _selectedTypes = Set.from(_allTypes);
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);

    final token = await _authService.getGoogleAccessToken();
    if (token == null) {
      _showError('Não foi possível obter credenciais do Google.');
      setState(() => _isLoading = false);
      return;
    }

    try {
      final service = GoogleCalendarService(token);

      // Constrói a lista de filtros para extendedProperties
      final filters = _selectedTypes
          .map((idx) => 'type=${typeSection[idx]}')
          .toList();

      // Busca os próximos 20 eventos com `type` nas propriedades privadas
      final items = await service.fetchNextStudySessions(
        calendarId: 'primary',
        maxResults: 20,
        privateExtendedProperties: filters,
      );

      setState(() => _events = items);
    } catch (e) {
      _showError('Erro ao carregar eventos: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Próximas Seções'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Column(
        children: [
          // --- filtros de tipoSection ---
          Padding(
            padding: const EdgeInsets.all(8),
            child: Wrap(
              spacing: 8,
              children: _allTypes.map((idx) {
                final label = typeSection[idx]!;
                final selected = _selectedTypes.contains(idx);
                return FilterChip(
                  label: Text(label),
                  selected: selected,
                  onSelected: (sel) {
                    setState(() {
                      if (sel) {
                        _selectedTypes.add(idx);
                      } else {
                        _selectedTypes.remove(idx);
                      }
                    });
                    _loadEvents();
                  },
                );
              }).toList(),
            ),
          ),

          const Divider(height: 1),

          // --- lista de eventos ---
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _events.isEmpty
                    ? const Center(child: Text('Nenhuma seção encontrada.'))
                    : ListView.separated(
                        itemCount: _events.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (ctx, i) {
                          final ev = _events[i];
                          final start = ev.start?.dateTime?.toLocal();
                          final end   = ev.end?.dateTime?.toLocal();
                          final type  = ev.extendedProperties
                                          ?.private?['type'] ??
                                        '—';

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: 
                                eventColorMap.entries
                                  .firstWhere((e) => e.key == ev.colorId, orElse: () => MapEntry('6', eventColorMap['6']!))
                                  .value,
                              child: Text(
                                typeSection.entries
                                  .firstWhere((e) => e.value == type, orElse: () => MapEntry(1, 'Seção Estudo'))
                                  .key
                                  .toString(),
                                style: const TextStyle(fontSize: 12, color: Colors.white),
                              ),
                            ),
                            title: Text(ev.summary ?? '(Sem título)'),
                            subtitle: Text(
                              '${type} • '
                              '${start != null ? dateFmt.format(start) : ''}'
                              '${end != null ? ' – ${dateFmt.format(end)}' : ''}',
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}