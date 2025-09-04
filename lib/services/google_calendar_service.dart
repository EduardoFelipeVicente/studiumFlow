// lib/services/google_calendar_service.dart

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:studyflow/services/constants.dart';

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

  Future<void> insertEventOnCalendar({
    required DateTime start, // horário local
    required int duracaoMinutos, // duração total da sessão
    String? titulo,
    String? descricao,
    int? sectionTypeIndex, // índice para tipo (ex: Estudo, Prova)
    int? statusSectionIndex, // índice para status (ex: Agendado, Concluído)
    String calendarId = 'primary',
    int alertaMinutos = 10,
    String colorId = '6',
    String transparency = 'opaque',
    String visibility = 'default',
    DateTime? inicioReal, // opcional: horário real de início
    Duration? tempoFoco,
    Duration? tempoPausa,
  }) async {
    // 1. Extrai rótulos a partir dos índices
    final sectionLabel = typeSection[sectionTypeIndex] ?? typeSection[0]!;
    final statusLabel = statusSection[statusSectionIndex] ?? statusSection[0]!;

    // 2. Define horário de início e fim
    final localStart = DateTime(
      start.year,
      start.month,
      start.day,
      start.hour,
      start.minute,
    );
    final localEnd = localStart.add(Duration(minutes: duracaoMinutos));

    // 3. Configura cliente e API
    final expiry = DateTime.now().toUtc().add(const Duration(hours: 1));
    final client = _buildClient(expiryUtc: expiry);
    final api = calendar.CalendarApi(client);

    try {
      // 4. Monta propriedades estendidas
      final extendedProps = {'type': sectionLabel, 'status': statusLabel};

      if (inicioReal != null) {
        extendedProps['inicioReal'] = inicioReal.toIso8601String();
      }
      if (tempoFoco != null) {
        extendedProps['tempoFoco'] = tempoFoco.inMinutes.toString();
      }
      if (tempoPausa != null) {
        extendedProps['tempoPausa'] = tempoPausa.inMinutes.toString();
      }
      if (tempoFoco != null || tempoPausa != null) {
        final total =
            (tempoFoco ?? Duration.zero) + (tempoPausa ?? Duration.zero);
        extendedProps['tempoTotal'] = total.inMinutes.toString();
      }

      // 5. Cria evento
      final ev = calendar.Event()
        ..summary = titulo ?? '[StudyFlow] $sectionLabel'
        ..description =
            descricao ?? 'Sessão gerada automaticamente pelo StudyFlow'
        ..start = calendar.EventDateTime(
          dateTime: localStart,
          timeZone: 'America/Sao_Paulo',
        )
        ..end = calendar.EventDateTime(
          dateTime: localEnd,
          timeZone: 'America/Sao_Paulo',
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
          private: extendedProps,
        );

      await api.events.insert(ev, calendarId);
    } finally {
      client.close();
    }
  }

  Future<void> alterEventOnCalendar({
    required String eventId,
    String calendarId = 'primary',
    int? statusSectionIndex,
    DateTime? inicioReal,
    Duration? tempoFoco,
    Duration? tempoPausa,
    String? novaDescricao,
  }) async {
    final expiry = DateTime.now().toUtc().add(const Duration(hours: 1));
    final client = _buildClient(expiryUtc: expiry);
    final api = calendar.CalendarApi(client);

    try {
      // 1. Busca o evento atual
      final original = await api.events.get(calendarId, eventId);

      // 2. Atualiza campos desejados
      final updated = calendar.Event();

      // Mantém os dados existentes
      updated.summary = original.summary;
      updated.start = original.start;
      updated.end = original.end;
      updated.colorId = original.colorId;
      updated.transparency = original.transparency;
      updated.visibility = original.visibility;
      updated.reminders = original.reminders;

      // Atualiza descrição se fornecida
      if (novaDescricao != null) {
        updated.description = novaDescricao;
      } else {
        updated.description = original.description;
      }

      // Atualiza propriedades estendidas
      final props = Map<String, String>.from(
        original.extendedProperties?.private ?? {},
      );

      if (statusSectionIndex != null) {
        props['status'] =
            statusSection[statusSectionIndex] ?? statusSection[0]!;
      }
      if (inicioReal != null) {
        props['inicioReal'] = inicioReal.toIso8601String();
      }
      if (tempoFoco != null) {
        props['tempoFoco'] = tempoFoco.inMinutes.toString();
      }
      if (tempoPausa != null) {
        props['tempoPausa'] = tempoPausa.inMinutes.toString();
      }
      if (tempoFoco != null || tempoPausa != null) {
        final total =
            (tempoFoco ?? Duration.zero) + (tempoPausa ?? Duration.zero);
        props['tempoTotal'] = total.inMinutes.toString();
      }

      updated.extendedProperties = calendar.EventExtendedProperties(
        private: props,
      );

      // 3. Envia atualização
      await api.events.update(updated, calendarId, eventId);
    } finally {
      client.close();
    }
  }

  Future<List<calendar.Event>> fetchNextStudySessions({
    String calendarId = 'primary',
    int maxResults = 20,
    List<String>? privateExtendedProperties,
  }) async {
    // 1. calcula expiry e cria client autenticado
    final expiry = DateTime.now().toUtc().add(const Duration(hours: 1));
    final client = _buildClient(expiryUtc: expiry);

    // 2. cria a instância da API
    final api = calendar.CalendarApi(client);

    try {
      // 3. faz a chamada list com o filtro em extendedProperties.private['type']
      final now = DateTime.now().toUtc();
      final resp = await api.events.list(
        calendarId,
        timeMin: now,
        singleEvents: true,
        orderBy: 'startTime',
        maxResults: maxResults,
        privateExtendedProperty: privateExtendedProperties,
      );

      // 4. retorna a lista (ou vazia)
      return resp.items ?? <calendar.Event>[];
    } finally {
      // 5. não esqueça de fechar o client
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

  Future<List<calendar.Event>> fetchEventsBetween({
    required DateTime start,
    required DateTime end,
    String calendarId = 'primary',
  }) async {
    final expiry = DateTime.now().toUtc().add(const Duration(hours: 1));
    final client = _buildClient(expiryUtc: expiry);
    final api = calendar.CalendarApi(client);

    try {
      final events = await api.events.list(
        calendarId,
        timeMin: start.toUtc(),
        timeMax: end.toUtc(),
        singleEvents: true,
        orderBy: 'startTime',
      );
      return events.items ?? [];
    } finally {
      client.close();
    }
  }
}
