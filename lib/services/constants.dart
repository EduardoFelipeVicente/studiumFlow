// lib/services/constants.dart

import 'package:flutter/material.dart';

/// Texto padrão usado quando nenhum título for informado
const String defaultStudySessionTitle = '[Study Flow] Sessão de Estudo';

/// Descrição padrão usada quando nenhuma descrição for informada
const String defaultStudySessionDes =
    'Sessão gerada automaticamente pelo StudyFlow';

/// Mapeamento de colorId → cor real (usando ARGB)
const Map<String, Color> eventColorMap = {
  '1': Color.fromARGB(255, 0, 0, 255), // Azul
  '2': Color.fromARGB(255, 30, 255, 0), // Verde
  '3': Color.fromARGB(255, 93, 10, 156), // Roxo
  '4': Color.fromARGB(255, 199, 145, 140), // Salmão
  '5': Color.fromARGB(255, 255, 251, 0), // Amarelo
  '6': Color.fromARGB(255, 185, 119, 60), // Pêssego
  '7': Color.fromARGB(255, 0, 233, 241), // Turquesa
  '8': Color.fromARGB(255, 77, 72, 72), // Cinza
  '9': Color.fromARGB(255, 84, 132, 237), // Azul Royal
  '10': Color.fromARGB(255, 81, 183, 73), // Verde Médio
  '11': Color.fromARGB(255, 255, 0, 8), // Vermelho
  '12': Color.fromARGB(255, 255, 136, 0), // Laranja
};

/// Mapeamento de colorId → nome amigável
const Map<String, String> eventColorNames = {
  '1': 'Azul',
  '2': 'Verde',
  '3': 'Roxo',
  '4': 'Salmão',
  '5': 'Amarelo',
  '6': 'Pêssego',
  '7': 'Turquesa',
  '8': 'Cinza',
  '9': 'Azul Royal',
  '10': 'Verde Médio',
  '11': 'Vermelho',
  '12': 'Laranja',
};

const Map<int, String> typeSection = {
  0: 'Nenhum',
  1: 'Seção Estudo',
  2: 'Prova',
  3: 'Trabalho',
  4: 'Revisão',
  5: 'Outros',
};

const Map<int, String> statusSection = {
  0: 'Nenhum',
  1: 'Agendado',
  2: 'Concluido',
  3: 'Atrasado',
  4: 'Cancelado',
  5: 'Outros',
};

final Map<String, Color> statusColorMap = {
  'Agendado': const Color.fromARGB(255, 61, 104, 168),
  'Concluido': const Color.fromARGB(255, 58, 138, 61),
  'Cancelado': const Color.fromARGB(255, 117, 83, 50),
  'Atrasado': const Color.fromARGB(255, 192, 80, 80),
  'Outros' : const Color.fromARGB(255, 206, 92, 177),
};


const Map<int, String> styleViewNextEvents = {0: 'Dia', 1: 'Tipo', 2: 'Status'};

// Pomodoro configuration (minutos e segundos)
const int kFocusMinutes = 0;
const int kFocusSeconds = 20;

const int kShortPauseMinutes = 0;
const int kShortPauseSeconds = 5;

const int kLongPauseMinutes = 0;
const int kLongPauseSeconds = 10;

// Durations construídas a partir dos valores acima
final Duration kFocusPeriod = Duration(
  minutes: kFocusMinutes,
  seconds: kFocusSeconds,
);

final Duration kShortPausePeriod = Duration(
  minutes: kShortPauseMinutes,
  seconds: kShortPauseSeconds,
);

final Duration kLongPausePeriod = Duration(
  minutes: kLongPauseMinutes,
  seconds: kLongPauseSeconds,
);
