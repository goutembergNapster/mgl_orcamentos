import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models.dart';

class N8nClient {
  final String webhookUrl;
  N8nClient(this.webhookUrl);

  Future<http.Response> enviarOrcamento({
    required Orcamento orcamento,
    required String pdfBase64,
    required String pdfFilename,
  }) async {
    final payload = {
      'evento': 'orcamento_criado',
      'orcamento': orcamento.toJson(),
      'profissional': orcamento.profissional.toJson(),
      'cliente': orcamento.cliente.toJson(),
      'pdf': {
        'filename': pdfFilename,
        'base64': pdfBase64,
        'mimetype': 'application/pdf',
      }
    };

    return await http.post(
      Uri.parse(webhookUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
  }
}
