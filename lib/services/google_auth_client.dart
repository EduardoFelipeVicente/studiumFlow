// lib/services/google_auth_client.dart

import 'package:http/http.dart' as http;

/// Cliente HTTP que injeta automaticamente os headers de autorização
/// em cada requisição feita para a API do Google.
class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _inner = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    // Adiciona os headers de autenticação (ex: Authorization: Bearer <token>)
    request.headers.addAll(_headers);
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}