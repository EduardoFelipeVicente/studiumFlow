import 'package:flutter/material.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

class GoogleCalendarService {
  final _scopes = [calendar.CalendarApi.calendarScope];

  final _clientId = ClientId(
    '109345613312-c399mids3ek6gd4v2vpe2cr2se34mec5.apps.googleusercontent.com',
    null,
  );

  void _prompt(String url) {
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Future<AuthClient> _getAuthenticatedClient() async {
    final prefs = await SharedPreferences.getInstance();

    final accessToken = prefs.getString('access_token');
    final expiry = prefs.getInt('access_expiry');

    if (accessToken != null && expiry != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now < expiry) {
        final credentials = AccessCredentials(
          AccessToken('Bearer', accessToken, DateTime.fromMillisecondsSinceEpoch(expiry)),
          null,
          _scopes,
        );
        return authenticatedClient(http.Client(), credentials);
      }
    }

    final client = await clientViaUserConsent(_clientId, _scopes, _prompt);
    final credentials = (client).credentials;

    await prefs.setString('access_token', credentials.accessToken.data);
    await prefs.setInt('access_expiry', credentials.accessToken.expiry.millisecondsSinceEpoch);

    return client;
  }

  Future<void> insertStudySession(DateTime start, int focoMinutos, int pausaMinutos) async {
    final client = await _getAuthenticatedClient();
    final calendarApi = calendar.CalendarApi(client);

    final fim = start.add(Duration(minutes: focoMinutos + pausaMinutos));

    final event = calendar.Event()
      ..summary = '[StudyFlow] Sessão de Estudo'
      ..description = 'Sessão gerada automaticamente pelo StudyFlow'
      ..start = calendar.EventDateTime(
        dateTime: start,
        timeZone: 'America/Sao_Paulo',
      )
      ..end = calendar.EventDateTime(
        dateTime: fim,
        timeZone: 'America/Sao_Paulo',
      )
      ..colorId = '6'
      ..reminders = calendar.EventReminders(
        useDefault: false,
        overrides: [calendar.EventReminder(method: 'popup', minutes: 10)],
      );

    await calendarApi.events.insert(event, "primary");
    client.close();
  }

  Future<List<Appointment>> fetchAppointments() async {
    final client = await _getAuthenticatedClient();
    final calendarApi = calendar.CalendarApi(client);

    final now = DateTime.now();
    final oneMonthAhead = now.add(const Duration(days: 30));

    final events = await calendarApi.events.list(
      "primary",
      timeMin: now.toUtc(),
      timeMax: oneMonthAhead.toUtc(),
      singleEvents: true,
      orderBy: "startTime",
    );

    final appointments = <Appointment>[];

    for (var event in events.items ?? []) {
      final start = event.start?.dateTime;
      final end = event.end?.dateTime;

      if (start != null && end != null) {
        appointments.add(
          Appointment(
            startTime: start.toLocal(),
            endTime: end.toLocal(),
            subject: event.summary ?? 'Sessão sem título',
            color: Colors.deepPurple,
            notes: event.description,
          ),
        );
      }
    }

    client.close();
    return appointments;
  }
}
