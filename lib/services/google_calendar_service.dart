// lib/services/google_calendar_service.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:syncfusion_flutter_calendar/calendar.dart';
import '../services/constants.dart';

class GoogleCalendarService {
  final calendar.CalendarApi api;

  GoogleCalendarService(http.Client client)
    : api = calendar.CalendarApi(client);

  /// Busca e converte para Appointment todos os eventos futuros (até 1 ano à frente)
  Future<List<Appointment>> fetchAppointments() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).toUtc();
    final endOfRange = now.toUtc().add(const Duration(days: 365));

    final resp = await api.events.list(
      'primary',
      timeMin: startOfDay,
      timeMax: endOfRange,
      singleEvents: true,
      orderBy: 'startTime',
    );

    return (resp.items ?? [])
        .where((e) => e.start?.dateTime != null && e.end?.dateTime != null)
        .map((e) {
          final s = e.start!.dateTime!.toLocal();
          final t = e.end!.dateTime!.toLocal();
          return Appointment(
            startTime: s,
            endTime: t,
            subject: e.summary ?? 'Sem título',
            notes: e.description,
            id: e.id,
            color: eventColorMap[e.colorId] ?? Colors.deepPurple,
          );
        })
        .toList();
  }

  /// Retorna as propriedades estendidas privadas de um evento
  Future<Map<String, String>> getEventExtendedProperties(
    String eventId, {
    String calendarId = 'primary',
  }) async {
    final event = await api.events.get(calendarId, eventId);
    return event.extendedProperties?.private ?? {};
  }

  /// Busca eventos entre [start] e [end], opcionalmente filtrando por
  /// privateExtendedProperty (e.g. ['type=Seção Estudo', 'status=Agendado']).
  Future<List<calendar.Event>> fetchEventsBetween({
    required DateTime start,
    required DateTime end,
    String calendarId = 'primary',
    bool singleEvents = true,
    String orderBy = 'startTime',
    List<String>? privateExtendedProperty,
  }) async {
    final resp = await api.events.list(
      calendarId,
      timeMin: start.toUtc(),
      timeMax: end.toUtc(),
      singleEvents: singleEvents,
      orderBy: orderBy,
      privateExtendedProperty: privateExtendedProperty,
    );
    return resp.items ?? [];
  }

  /// Busca próximas sessões de estudo filtrando por extendedProperties.private['type']
  Future<List<calendar.Event>> fetchNextStudySessions({
    String calendarId = 'primary',
    int maxResults = 20,
    List<String>? privateExtendedProperties,
  }) async {
    final now = DateTime.now().toUtc();
    final resp = await api.events.list(
      calendarId,
      timeMin: now,
      singleEvents: true,
      orderBy: 'startTime',
      maxResults: maxResults,
      privateExtendedProperty: privateExtendedProperties,
    );
    return resp.items ?? [];
  }

  /// Insere novo evento no calendário
  Future<void> insertEventOnCalendar({
    required DateTime start,
    required int duracaoMinutos,
    String? titulo,
    String? descricao,
    int? sectionTypeIndex,
    int? statusSectionIndex,
    String calendarId = 'primary',
    int alertaMinutos = 10,
    String colorId = '6',
    String transparency = 'opaque',
    String visibility = 'default',
  }) async {
    final sectionLabel = typeSection[sectionTypeIndex] ?? typeSection[0]!;
    final statusLabel = statusSection[statusSectionIndex] ?? statusSection[0]!;

    final ev = calendar.Event()
      ..summary = titulo ?? '[StudyFlow] $sectionLabel'
      ..description = descricao ?? 'Sessão gerada automaticamente'
      ..start = calendar.EventDateTime(dateTime: start.toUtc(), timeZone: 'UTC')
      ..end = calendar.EventDateTime(
        dateTime: start.add(Duration(minutes: duracaoMinutos)).toUtc(),
        timeZone: 'UTC',
      )
      ..colorId = colorId
      ..transparency = transparency
      ..visibility = visibility
      ..reminders = calendar.EventReminders(
        useDefault: false,
        overrides: [
          calendar.EventReminder(method: 'popup', minutes: alertaMinutos),
        ],
      )
      ..extendedProperties = calendar.EventExtendedProperties(
        private: {'type': sectionLabel, 'status': statusLabel},
      );

    await api.events.insert(ev, calendarId);
  }

  /// Atualiza um evento existente, opcionalmente marcando-o como concluído
  /// e gravando propriedades extras como horários e durações de foco/pausa.
  Future<void> alterEventOnCalendar({
    required String eventId,
    DateTime? start,
    DateTime? end,
    String? novoTitulo,
    String? novaDescricao,
    int? typeSectionIndex,
    int? statusSectionIndex,
    Duration? focusDuration,
    Duration? pauseDuration,
    DateTime? actualStart, // horário real de início da sessão
    String calendarId = 'primary',
    int alertaMinutos = 10,
    String colorId = '6',
    String transparency = 'opaque',
    String visibility = 'default',
  }) async {
    // 1) busca o evento original
    final original = await api.events.get(calendarId, eventId);

    // 2) constrói o objeto com todos os campos a atualizar
    final updated = calendar.Event();

    // 2.1) campos básicos
    updated.summary = novoTitulo ?? original.summary;
    updated.description = novaDescricao ?? original.description;
    updated.colorId = colorId;
    updated.transparency = transparency;
    updated.visibility = visibility;

    // 2.2) datas de início e fim (sempre em UTC)
    if (start != null) {
      updated.start = calendar.EventDateTime(
        dateTime: start.toUtc(),
        timeZone: original.start?.timeZone ?? 'UTC',
      );
    } else {
      // mantém o original
      updated.start = original.start;
    }

    if (end != null) {
      updated.end = calendar.EventDateTime(
        dateTime: end.toUtc(),
        timeZone: original.end?.timeZone ?? 'UTC',
      );
    } else {
      updated.end = original.end;
    }

    // 2.3) lembretes
    updated.reminders = calendar.EventReminders(
      useDefault: false,
      overrides: [
        calendar.EventReminder(method: 'popup', minutes: alertaMinutos),
      ],
    );

    // 3) propriedades estendidas
    //    clona as private properties originais pra não perder nada
    final props = Map<String, String>.from(
      original.extendedProperties?.private ?? {},
    );

    // status / type
    if (statusSectionIndex != null) {
      props['status'] = statusSection[statusSectionIndex] ?? statusSection[0]!;
    }
    if (typeSectionIndex != null) {
      props['type'] = typeSection[typeSectionIndex] ?? typeSection[0]!;
    }

    // horário real de início, se informado
    if (actualStart != null) {
      props['actualStart'] = actualStart.toIso8601String();
    }

    // tempos de foco, pausa e total
    String fmtDur(Duration d) {
      final h = d.inHours.toString().padLeft(2, '0');
      final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return '$h:$m:$s';
    }

    if (focusDuration != null) {
      props['focusTime'] = fmtDur(focusDuration);
    }
    if (pauseDuration != null) {
      props['pauseTime'] = fmtDur(pauseDuration);
    }
    if (focusDuration != null && pauseDuration != null) {
      final total = focusDuration + pauseDuration;
      props['totalTime'] = fmtDur(total);
    }

    updated.extendedProperties = calendar.EventExtendedProperties(
      private: props,
    );

    // 4) patch no Google Calendar
    await api.events.patch(updated, calendarId, eventId, sendUpdates: 'all');
  }

  /// Exclui um evento
  Future<void> deleteEvent(String eventId, {String calendarId = 'primary'}) {
    return api.events.delete(calendarId, eventId);
  }

  // Traz todos os eventos num range predefinido (30 dias atrás até 60 dias à frente)
  Future<List<calendar.Event>> fetchAllEvents({
    String calendarId = 'primary',
  }) async {
    final resp = await api.events.list(
      calendarId,
      singleEvents: true,
      orderBy: 'startTime',
      timeMin: DateTime.now().subtract(const Duration(days: 30)).toUtc(),
      timeMax: DateTime.now().add(const Duration(days: 60)).toUtc(),
    );
    return resp.items ?? [];
  }

  Future<List<calendar.Event>> fetchStudySessions({
    required DateTime timeMin,
    required DateTime timeMax,
  }) async {
    final resp = await api.events.list(
      'primary',
      timeMin: timeMin,
      timeMax: timeMax,
      singleEvents: true,
      orderBy: 'startTime',
    );
    return resp.items ?? <calendar.Event>[];
  }

  Future<void> updateLateEvents() async {
    final now = DateTime.now().toUtc();
  
    // Busca eventos que terminaram até agora
    final events = await fetchStudySessions(
      timeMin: DateTime.utc(2000), // busca ampla
      timeMax: now,
    );

    for (var ev in events) {
      final id = ev.id;
      final status = ev.extendedProperties?.private?['status'];
      final tipo = ev.extendedProperties?.private?['type'];
      final end = ev.end?.dateTime;

      final isAtrasado =
          end != null &&
          end.isBefore(now) &&
          status != statusSection[0] && // Nenhum
          status != statusSection[2] && // Concluído
          status != statusSection[4] && // Cancelado
          tipo != typeSection[0]; // Tipo Nenhum

      if (isAtrasado && id != null) {
        await alterEventOnCalendar(
          eventId: id,
          statusSectionIndex: 3 /* Atrasado */,
        );
      }

    }
  }
}
