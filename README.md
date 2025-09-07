# StudiumFlow 📚🚀

**StudiumFlow** é um aplicativo mobile desenvolvido em Flutter com o objetivo de ajudar estudantes a organizarem suas sessões de estudo, acompanharem seu progresso e manterem o foco ao longo do tempo. O projeto foi desenvolvido como parte do Projeto Integrador do curso técnico, com foco em planejamento, produtividade e visualização de desempenho.

---

## 👥 Integrantes

- Eduardo Felipe Vicente [GitHub](https://github.com/EduardoFelipeVicente)

---

## 🎯 Jornada Escolhida

A jornada implementada foi a de **gestão de sessões de estudo**, incluindo:

- Agendamento de sessões
- Atualização automática de status (ex: atrasado, concluído)
- Visualização de progresso por meio de gráficos
- Dashboard com resumo de atividades e próximas sessões

Essa jornada foi escolhida por representar o núcleo funcional do aplicativo e permitir validar a integração entre interface, lógica de negócio e persistência de dados.

---

## 🛠️ Tecnologias Utilizadas

- **Flutter** — Interface mobile multiplataforma  
- **Firebase** — Autenticação, banco de dados e integração com Google Calendar  
- **Google Calendar API** — Sincronização de sessões  
- **fl_chart** — Gráficos visuais de progresso  
- **Dart** — Lógica de programação  

---

## 📦 Como Executar o Projeto


### Instalação via APK

Caso prefira instalar diretamente no dispositivo Android, há um arquivo `StudiumFlow.apk` disponível para instalação manual, na raiz do projeto.

> ⚠️ Para isso, é necessário:
- Permitir a instalação de apps de fontes desconhecidas nas configurações do Android
- Ao abrir o app pela primeira vez, conceder permissão para usar sua conta Google
- Autorizar o acesso à agenda para sincronização com o Google Calendar

### Pré-requisitos via código fonte

- Visual Studio Code
- Flutter SDK
- Android Studio (Com dispositivo emulado ligado)

### Instalação via código-fonte

```bash```

git clone https://github.com/EduardoFelipeVicente/studiumFlow

cd studiumflow

flutter pub get

flutter run

## 📊 Funcionalidades

- Dashboard com gráfico de pizza (agendadas, concluídas, atrasadas)
- Cards com tempo agendado, tempo realizado e tempo de foco
- Lista de próximas sessões com título, data, horário, tipo e descrição
- Atualização automática de status de eventos
- Integração com Firebase e Google Calendar
- Interface responsiva e intuitiva desenvolvida em Flutter

---

## 🧭 Navegação e Telas do Aplicativo

O aplicativo StudiumFlow é composto por diversas telas que ajudam o usuário a planejar, executar e acompanhar seus estudos de forma prática e visual. Abaixo está um resumo de cada uma:

---

### 🏠 Início (Dashboard)

- Visão geral do progresso e atividades recentes
- Gráfico de pizza com sessões agendadas, concluídas e atrasadas
- Cards com tempo agendado, tempo realizado e tempo de foco
- Lista das próximas sessões com título, data, horário, tipo e descrição
- Intervalo de datas considerado: 7 dias antes e 7 dias depois

---

### 🗓️ Criar Agenda de Estudos

- Permite agendar novas sessões de estudo
- Campos para título, dia da semana, horário de início e fim e descrição
- Ideal para montar uma rotina personalizada
- Consistência  de conflitos com outros compromissos

---

### 📌 Próximas Sessões

- Lista de eventos, com filtros por período, tipo e status
- Exibe detalhes como título, data, horário, tipo e status
- Exibição e agrupamento por data, tipo ou status
- Ajuda o usuário a se preparar com antecedência

---

### 📅 Calendário

- Visualização mensal, semanal ou diária das sessões de estudo
- Cores indicam o status de cada evento (agendada, concluída, atrasada, cancelado)
- Permite navegar por datas e entender a distribuição das sessões
- Permite a conclusão, alteração ou inclusão de eventos

---

### ▶️ Iniciar Sessão

- Inicia uma sessão de estudo em tempo real
- Cronômetro para foco e pausa, utilizando método pomodoro
- Avisa quando iniciar ou terminar uma pausa
- Registra automaticamente o tempo dedicado

---

### 📈 Progresso

- Estatísticas detalhadas do desempenho do usuário por período
- Informações de tempo de foco, pausa, agendado e realizado
- Histórico de eventos por tipo e status
- Comparativo entre tempo agendado e tempo realizado

---

### ⚙️ Configurações

- IInformações da conta logada
- Possibilidade de logout

---

### 🚪 Sair

- Encerra a sessão atual do usuário
- Protege os dados e permite login com outra conta


## 🎥 Vídeo de Apresentação

👉 [Assista aqui](https://youtube.com/seuvideo) — demonstração da jornada implementada e principais funcionalidades.

---

## 📌 Observações

- O nome original do projeto era **StudyFlow**, mas foi alterado para **StudiumFlow** por questões de registro.
- O projeto está hospedado no GitHub com commits contínuos desde o início do desenvolvimento.