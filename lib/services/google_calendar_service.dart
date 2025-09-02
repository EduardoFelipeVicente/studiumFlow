// lib/services/google_calendar_service.dart

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

class CalendarInfo {
  final String id;
  final String summary;

  CalendarInfo({required this.id, required this.summary});
}

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

  /// Retorna só as agendas não-holiday com id e summary
  Future<List<CalendarInfo>> listCalendars() async {
    final expiry = DateTime.now().toUtc().add(const Duration(hours: 1));
    final client = _buildClient(expiryUtc: expiry);
    final api = calendar.CalendarApi(client);

    try {
      final response = await api.calendarList.list();

      return (response.items ?? [])
          // 1) remove tudo que for holiday
          .where((e) {
            final lowerId = e.id?.toLowerCase() ?? '';
            final lowerName = e.summary?.toLowerCase() ?? '';
            return !lowerId.contains('holiday') &&
                !lowerName.contains('holiday');
          })
          // 2) mapeia para CalendarInfo
          .map((e) => CalendarInfo(id: e.id!, summary: e.summary ?? e.id!))
          .toList();
    } finally {
      client.close();
    }
  }

  /// Cria uma nova agenda com o nome [summary] e a adiciona à lista do usuário
  Future<String> createCalendar({required String summary}) async {
    final expiry = DateTime.now().toUtc().add(const Duration(hours: 1));
    final client = _buildClient(expiryUtc: expiry);
    final api = calendar.CalendarApi(client);

    try {
      // 1) Cria o próprio calendário
      final createdCal = await api.calendars.insert(
        calendar.Calendar()..summary = summary,
      );

      // 2) Adiciona este calendário à lista de agendas do usuário
      await api.calendarList.insert(
        calendar.CalendarListEntry()..id = createdCal.id!,
      );

      return createdCal.id!;
    } finally {
      client.close();
    }
  }

/// Insere uma nova sessão de estudo no Google Calendar
Future<void> insertStudySession({
  required DateTime start,
  required int focoMinutos,
  required int pausaMinutos,
  String? titulo,
  String? descricao,
  String calendarId = 'primary',
  int alertaMinutos = 10,
  String colorId = '6',
  String transparency = 'opaque',
  String visibility = 'default',
}) async {
  final expiry = DateTime.now().toUtc().add(const Duration(hours: 1));
  final client = _buildClient(expiryUtc: expiry);
  final api = calendar.CalendarApi(client);

  try {
    // Usa exatamente o DateTime passado, sem conversões
    final eventEnd = start.add(Duration(minutes: focoMinutos + pausaMinutos));
    final tzName = start.timeZoneName;

    final event = calendar.Event()
      ..summary     = titulo    ?? '[StudyFlow] Sessão de Estudo'
      ..description = descricao ?? 'Sessão gerada automaticamente pelo StudyFlow'
      ..start = calendar.EventDateTime(
        dateTime: start,
        timeZone: 'UTC',
      )
      ..end = calendar.EventDateTime(
        dateTime: eventEnd,
        timeZone: 'UTC',
      )
      ..colorId      = colorId
      ..transparency = transparency
      ..visibility   = visibility
      ..reminders = calendar.EventReminders(
        useDefault: false,
        overrides: [
          calendar.EventReminder(method: 'popup', minutes: alertaMinutos),
        ],
      );

    await api.events.insert(event, calendarId);
  } finally {
    client.close();
  }
}

  /// Busca sessões do dia atual em diante e converte para Appointment
  Future<List<Appointment>> fetchAppointments() async {
    final expiry = DateTime.now().toUtc().add(const Duration(hours: 1));
    final client = _buildClient(expiryUtc: expiry);
    final api = calendar.CalendarApi(client);

    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day).toUtc();
      final endOfRange = now.toUtc().add(const Duration(days: 365));

      final response = await api.events.list(
        'primary',
        timeMin: startOfDay,
        timeMax: endOfRange,
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
              id: e.id,
            );
          })
          .toList();
    } finally {
      client.close();
    }
  }

  /// Exclui uma sessão do Google Calendar usando o eventId
  Future<void> deleteSession(String eventId) async {
    final expiry = DateTime.now().toUtc().add(const Duration(hours: 1));
    final client = _buildClient(expiryUtc: expiry);
    final api = calendar.CalendarApi(client);

    try {
      await api.events.delete('primary', eventId);
    } finally {
      client.close();
    }
  }

  /// Atualiza uma sessão existente no Google Calendar
  Future<void> updateSession({
    required String eventId,
    required DateTime newStart,
    required DateTime newEnd,
    required String newSummary,
    String? newDescription,
  }) async {
    final expiry = DateTime.now().toUtc().add(const Duration(hours: 1));
    final client = _buildClient(expiryUtc: expiry);
    final api = calendar.CalendarApi(client);

    try {
      final updated = calendar.Event()
        ..summary = newSummary
        ..description = newDescription
        ..start = calendar.EventDateTime(
          dateTime: newStart.toUtc(),
          timeZone: 'UTC',
        )
        ..end = calendar.EventDateTime(
          dateTime: newEnd.toUtc(),
          timeZone: 'UTC',
        );

      await api.events.patch(updated, 'primary', eventId);
    } finally {
      client.close();
    }
  }
}
