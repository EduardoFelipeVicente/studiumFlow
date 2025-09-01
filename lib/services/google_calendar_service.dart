// lib/services/google_calendar_service.dart

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

class GoogleCalendarService {
  final String _accessToken;
  GoogleCalendarService(this._accessToken);

  /// Constrói um client HTTP autenticado usando apenas o access token
  http.Client get _client {
    final creds = AccessCredentials(
      AccessToken('Bearer', _accessToken, DateTime.now().add(const Duration(hours: 1))),
      null,
      [calendar.CalendarApi.calendarScope],
    );
    return authenticatedClient(http.Client(), creds);
  }

  Future<void> insertStudySession(DateTime start, int focoMinutos, int pausaMinutos) async {
    final client = _client;
    final api = calendar.CalendarApi(client);

    final end = start.add(Duration(minutes: focoMinutos + pausaMinutos));

    final event = calendar.Event()
      ..summary = '[StudyFlow] Sessão de Estudo'
      ..description = 'Sessão gerada automaticamente pelo StudyFlow'
      ..start = calendar.EventDateTime(dateTime: start, timeZone: 'America/Sao_Paulo')
      ..end   = calendar.EventDateTime(dateTime: end,   timeZone: 'America/Sao_Paulo')
      ..colorId = '6'
      ..reminders = calendar.EventReminders(
        useDefault: false,
        overrides: [calendar.EventReminder(method: 'popup', minutes: 10)],
      );

    await api.events.insert(event, 'primary');
    client.close();
  }

  Future<List<Appointment>> fetchAppointments() async {
    final client = _client;
    final api = calendar.CalendarApi(client);

    final now   = DateTime.now();
    final later = now.add(const Duration(days: 30));

    final events = await api.events.list(
      'primary',
      timeMin: now.toUtc(),
      timeMax: later.toUtc(),
      singleEvents: true,
      orderBy: 'startTime',
    );

    final list = <Appointment>[];
    for (var e in events.items ?? []) {
      final s = e.start?.dateTime;
      final t = e.end?.dateTime;
      if (s != null && t != null) {
        list.add(Appointment(
          startTime: s.toLocal(),
          endTime:   t.toLocal(),
          subject:   e.summary ?? 'Sem título',
          color:     Colors.deepPurple,
          notes:     e.description,
        ));
      }
    }

    client.close();
    return list;
  }
}
