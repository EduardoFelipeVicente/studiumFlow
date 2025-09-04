// lib/services/google_calendar_service.dart

import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:studyflow/services/google_auth_client.dart';
import 'package:http/http.dart' as http;
import 'package:studyflow/services/constants.dart';

class GoogleCalendarService {
  final calendar.CalendarApi api;

  GoogleCalendarService(http.Client client) : api = calendar.CalendarApi(client);

  Future<List<calendar.Event>> fetchAllEvents({
    String calendarId = 'primary',
  }) async {
    final now = DateTime.now().toUtc();
    final resp = await api.events.list(
      calendarId,
      singleEvents: true,
      orderBy: 'startTime',
      timeMin: now,
      timeMax: now.add(const Duration(days: 60)),
    );
    return resp.items ?? [];
  }

  Future<void> deleteEvent(String eventId, {String calendarId = 'primary'}) {
    return api.events.delete(calendarId, eventId);
  }

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
    final statusLabel  = statusSection[statusSectionIndex]  ?? statusSection[0]!;

    final end = start.add(Duration(minutes: duracaoMinutos));
    final ev = calendar.Event()
      ..summary     = titulo    ?? '[StudyFlow] $sectionLabel'
      ..description = descricao ?? 'Sessão gerada automaticamente'
      ..start       = calendar.EventDateTime(dateTime: start.toUtc(), timeZone: 'UTC')
      ..end         = calendar.EventDateTime(dateTime: end.toUtc(),   timeZone: 'UTC')
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

  // repita o padrão para alterEventOnCalendar, fetchEventsBetween, etc.
}