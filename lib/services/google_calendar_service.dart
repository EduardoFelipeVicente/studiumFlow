// lib/services/google_calendar_service.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:studyflow/services/constants.dart';
import 'package:studyflow/services/google_auth_client.dart';

class GoogleCalendarService {
  final calendar.CalendarApi api;

  GoogleCalendarService(http.Client client) : api = calendar.CalendarApi(client);

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

  /// Busca eventos entre [start] e [end]
  Future<List<calendar.Event>> fetchEventsBetween({
    required DateTime start,
    required DateTime end,
    String calendarId = 'primary',
  }) async {
    final resp = await api.events.list(
      calendarId,
      timeMin: start.toUtc(),
      timeMax: end.toUtc(),
      singleEvents: true,
      orderBy: 'startTime',
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
      ..summary     = titulo    ?? '[StudyFlow] $sectionLabel'
      ..description = descricao ?? 'Sessão gerada automaticamente'
      ..start       = calendar.EventDateTime(dateTime: start.toUtc(), timeZone: 'UTC')
      ..end         = calendar.EventDateTime(dateTime: start.add(Duration(minutes: duracaoMinutos)).toUtc(), timeZone: 'UTC')
      ..colorId     = colorId
      ..transparency= transparency
      ..visibility  = visibility
      ..reminders   = calendar.EventReminders(
         useDefault: false,
         overrides: [calendar.EventReminder(method: 'popup', minutes: alertaMinutos)],
       )
      ..extendedProperties = calendar.EventExtendedProperties(private: {
        'type':   sectionLabel,
        'status': statusLabel,
      });

    await api.events.insert(ev, calendarId);
  }

  /// Atualiza um evento existente
  Future<void> alterEventOnCalendar({
    required String eventId,
    String calendarId = 'primary',
    int? statusSectionIndex,
    String? novaDescricao,
  }) async {
    final original = await api.events.get(calendarId, eventId);
    final updated = calendar.Event();

    // mantêm todos os campos originais, só altera description e status
    updated.summary     = original.summary;
    updated.start       = original.start;
    updated.end         = original.end;
    updated.colorId     = original.colorId;
    updated.transparency= original.transparency;
    updated.visibility  = original.visibility;
    updated.reminders   = original.reminders;
    updated.description = novaDescricao ?? original.description;

    // atualiza status em extendedProperties.private
    final props = Map<String, String>.from(original.extendedProperties?.private ?? {});
    if (statusSectionIndex != null) {
      props['status'] = statusSection[statusSectionIndex] ?? statusSection[0]!;
    }
    updated.extendedProperties = calendar.EventExtendedProperties(private: props);

    await api.events.patch(updated, calendarId, eventId);
  }

  /// Exclui um evento
  Future<void> deleteEvent(String eventId, {String calendarId = 'primary'}) {
    return api.events.delete(calendarId, eventId);
  }

  // Traz todos os eventos num range predefinido (30 dias atrás até 60 dias à frente)
  Future<List<calendar.Event>> fetchAllEvents({String calendarId = 'primary'}) async {
    final resp = await api.events.list(
      calendarId,
      singleEvents: true,
      orderBy: 'startTime',
      timeMin: DateTime.now().subtract(const Duration(days: 30)).toUtc(),
      timeMax: DateTime.now().add(const Duration(days: 60)).toUtc(),
    );
    return resp.items ?? [];
  }

}