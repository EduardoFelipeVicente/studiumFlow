// lib/services/google_calendar_service.dart

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

class GoogleCalendarService {
  final String _accessToken;
  const GoogleCalendarService(this._accessToken);

  /// Retorna um client autenticado com o token
  http.Client _buildClient({required DateTime expiryUtc}) {
    final creds = AccessCredentials(
      AccessToken('Bearer', _accessToken, expiryUtc),
      null,
      [calendar.CalendarApi.calendarScope],
    );
    return authenticatedClient(http.Client(), creds);
  }

  Future<void> insertStudySession(
    DateTime start,
    int focoMinutos,
    int pausaMinutos,
  ) async {
    // calcula expiry UTC (1h à frente)
    final expiry = DateTime.now().toUtc().add(const Duration(hours: 1));
    final client = _buildClient(expiryUtc: expiry);
    final api = calendar.CalendarApi(client);

    try {
      // calcula tempos locais e depois converte para UTC
      final endLocal = start.add(Duration(minutes: focoMinutos + pausaMinutos));
      final startUtc = start.toUtc();
      final endUtc = endLocal.toUtc();

      final event = calendar.Event()
        ..summary = '[StudyFlow] Sessão de Estudo'
        ..description = 'Sessão gerada automaticamente pelo StudyFlow'
        ..start = calendar.EventDateTime(dateTime: startUtc, timeZone: 'UTC')
        ..end = calendar.EventDateTime(dateTime: endUtc, timeZone: 'UTC')
        ..colorId = '6'
        ..reminders = calendar.EventReminders(
          useDefault: false,
          overrides: [calendar.EventReminder(method: 'popup', minutes: 10)],
        );

      await api.events.insert(event, 'primary');
    } finally {
      client.close();
    }
  }

  Future<List<Appointment>> fetchAppointments() async {
    final expiry = DateTime.now().toUtc().add(const Duration(hours: 1));
    final client = _buildClient(expiryUtc: expiry);
    final api = calendar.CalendarApi(client);

    try {
      final now = DateTime.now().toUtc();
      final later = now.add(const Duration(days: 30));

      final response = await api.events.list(
        'primary',
        timeMin: now,
        timeMax: later,
        singleEvents: true,
        orderBy: 'startTime',
      );

      return (response.items ?? [])
          .where((e) => e.start?.dateTime != null && e.end?.dateTime != null)
          .map((e) {
            final s = e.start!.dateTime!.toLocal();
            final t = e.end!.dateTime!.toLocal();
            return Appointment(
              startTime: s,
              endTime: t,
              subject: e.summary ?? 'Sem título',
              color: Colors.deepPurple,
              notes: e.description,
            );
          })
          .toList();
    } finally {
      client.close();
    }
  }
}
