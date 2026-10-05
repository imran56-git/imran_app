import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class FallbackAiService {
  static final FallbackAiService _instance = FallbackAiService._internal();
  factory FallbackAiService() => _instance;
  FallbackAiService._internal();

  final String _apiKey = const String.fromEnvironment(
    'GROQ_API_KEY',
    defaultValue: '',
  );

  static const String _endpoint =
      'https://api.groq.com/openai/v1/chat/completions';
  static const String _model = 'llama-3.3-70b-versatile';

  Future<String> generateContent(String prompt, {String? systemPrompt}) async {
    if (_apiKey.isEmpty) {
      throw Exception('GROQ_API_KEY is not configured');
    }

    final messages = <Map<String, String>>[];
    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      messages.add({'role': 'system', 'content': systemPrompt});
    }
    messages.add({'role': 'user', 'content': prompt});

    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': _model,
        'messages': messages,
        'temperature': 0.7,
        'max_tokens': 1024,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final content = data['choices']?[0]?['message']?['content'];
      if (content != null) {
        return content.toString().trim();
      }
      throw Exception('Invalid response structure');
    } else {
      throw Exception('Fallback API error: ${response.statusCode}');
    }
  }

  Stream<String> generateContentStream(String prompt, {String? systemPrompt}) async* {
    if (_apiKey.isEmpty) {
      throw Exception('GROQ_API_KEY is not configured');
    }

    final messages = <Map<String, String>>[];
    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      messages.add({'role': 'system', 'content': systemPrompt});
    }
    messages.add({'role': 'user', 'content': prompt});

    final request = http.Request('POST', Uri.parse(_endpoint));
    request.headers.addAll({
      'Authorization': 'Bearer $_apiKey',
      'Content-Type': 'application/json',
      'Accept': 'text/event-stream',
    });
    request.body = jsonEncode({
      'model': _model,
      'messages': messages,
      'temperature': 0.7,
      'max_tokens': 1024,
      'stream': true,
    });

    final client = http.Client();
    try {
      final response = await client.send(request);
      if (response.statusCode != 200) {
        throw Exception('Fallback API error: ${response.statusCode}');
      }

      final lineStream = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in lineStream) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        if (trimmed.startsWith('data: ')) {
          final dataStr = trimmed.substring(6).trim();
          if (dataStr == '[DONE]') break;
          try {
            final json = jsonDecode(dataStr);
            final delta = json['choices']?[0]?['delta']?['content'];
            if (delta != null && delta is String && delta.isNotEmpty) {
              yield delta;
            }
          } catch (_) {}
        }
      }
    } finally {
      client.close();
    }
  }
}
