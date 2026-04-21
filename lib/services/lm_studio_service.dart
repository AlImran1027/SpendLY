/// LM Studio local inference service — receipt image extraction via LM Studio.
///
/// LM Studio exposes an OpenAI-compatible REST API on a local server
/// (default http://localhost:1234). This service sends a receipt image as a
/// base64-encoded data URL inside a chat-completions request and parses the
/// JSON response into the same [ExtractedReceiptData] model used by the
/// Gemini service.
///
/// Configuration stored in SharedPreferences:
///   [prefServerUrl]  — full base URL, e.g. "http://192.168.1.5:1234"
///   [prefModelName]  — model identifier as shown in LM Studio, e.g.
///                      "llava-v1.5-7b" or leave blank to let LM Studio
///                      use whatever is currently loaded.
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/extracted_receipt_data.dart';

// ─── Exception types ─────────────────────────────────────────────────────────

/// Thrown when [extractFromImage] is called without a server URL configured.
class LMStudioNotConfiguredException implements Exception {
  const LMStudioNotConfiguredException();
  @override
  String toString() => 'LM Studio server URL is not configured';
}

/// Thrown when the model returns an unreadable or structurally invalid response.
class LMStudioParseException implements Exception {
  final String message;
  const LMStudioParseException(this.message);
  @override
  String toString() => 'LMStudioParseException: $message';
}

// ═════════════════════════════════════════════════════════════════════════════
// SERVICE
// ═════════════════════════════════════════════════════════════════════════════

class LMStudioService {
  LMStudioService._();
  static final LMStudioService instance = LMStudioService._();

  static const String prefServerUrl = 'pref_lm_studio_url';
  static const String prefModelName = 'pref_lm_studio_model';
  static const String defaultServerUrl = 'http://localhost:1234';

  String? _serverUrl;
  String? _modelName;

  /// True when a non-empty server URL is in memory.
  bool get isConfigured => _serverUrl != null && _serverUrl!.isNotEmpty;

  String get serverUrl => _serverUrl ?? defaultServerUrl;
  String get modelName => _modelName ?? '';

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  /// Load persisted settings from SharedPreferences. Call in [main] before [runApp].
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _serverUrl = prefs.getString(prefServerUrl);
    _modelName = prefs.getString(prefModelName);
  }

  /// Persist new server URL. Pass an empty string to clear.
  Future<void> setServerUrl(String url) async {
    final trimmed = url.trim().replaceAll(RegExp(r'/+$'), ''); // strip trailing /
    _serverUrl = trimmed.isEmpty ? null : trimmed;
    final prefs = await SharedPreferences.getInstance();
    if (_serverUrl == null) {
      await prefs.remove(prefServerUrl);
    } else {
      await prefs.setString(prefServerUrl, _serverUrl!);
    }
  }

  /// Persist model name. Pass an empty string to clear (uses whatever is loaded).
  Future<void> setModelName(String name) async {
    _modelName = name.trim().isEmpty ? null : name.trim();
    final prefs = await SharedPreferences.getInstance();
    if (_modelName == null) {
      await prefs.remove(prefModelName);
    } else {
      await prefs.setString(prefModelName, _modelName!);
    }
  }

  /// Fetches the list of model IDs currently available in LM Studio.
  /// Returns an empty list if the server is unreachable.
  Future<List<String>> fetchAvailableModels() async {
    if (!isConfigured) return [];
    try {
      final uri = Uri.parse('$serverUrl/v1/models');
      final response =
          await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return [];
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = body['data'] as List<dynamic>? ?? [];
      return data
          .map((m) => (m as Map<String, dynamic>)['id'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ─── Extraction ────────────────────────────────────────────────────────────

  /// Sends [imagePath] to the configured LM Studio server and returns parsed
  /// [ExtractedReceiptData].
  ///
  /// Throws:
  /// - [LMStudioNotConfiguredException] when no server URL is set.
  /// - [LMStudioParseException] when the response cannot be parsed as JSON.
  /// - [http.ClientException] / [SocketException] for network failures.
  Future<ExtractedReceiptData> extractFromImage(String imagePath) async {
    if (!isConfigured) throw const LMStudioNotConfiguredException();

    final imageFile = File(imagePath);
    if (!await imageFile.exists()) {
      throw Exception('Receipt image not found at: $imagePath');
    }

    final imageBytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(imageBytes);
    final mimeType = _mimeType(imagePath);
    final dataUrl = 'data:$mimeType;base64,$base64Image';

    final requestBody = jsonEncode({
      'model': _modelName ?? '',
      'messages': [
        {
          'role': 'user',
          'content': [
            {
              'type': 'image_url',
              'image_url': {'url': dataUrl},
            },
            {
              'type': 'text',
              'text': _extractionPrompt,
            },
          ],
        },
      ],
      'temperature': 0.1,
      'max_tokens': 2048,
      'stream': false,
    });

    final uri = Uri.parse('$serverUrl/v1/chat/completions');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: requestBody,
        )
        .timeout(const Duration(seconds: 120));

    if (response.statusCode != 200) {
      throw Exception(
          'LM Studio returned ${response.statusCode}: ${response.body}');
    }

    final responseJson =
        jsonDecode(response.body) as Map<String, dynamic>;
    final choices = responseJson['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw const LMStudioParseException('No choices in response');
    }

    final message =
        (choices.first as Map<String, dynamic>)['message'] as Map<String, dynamic>?;
    final raw = message?['content'] as String?;
    if (raw == null || raw.trim().isEmpty) {
      throw const LMStudioParseException('Empty content in response');
    }

    try {
      final jsonStr = _extractJsonString(raw);
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return ExtractedReceiptData.fromJson(json, imagePath: imagePath);
    } on FormatException catch (e) {
      throw LMStudioParseException('Invalid JSON in response: ${e.message}');
    }
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  static String _mimeType(String path) {
    switch (path.toLowerCase().split('.').last) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
      case 'heif':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }

  /// Strips markdown code fences and finds the outermost `{...}` block.
  static String _extractJsonString(String text) {
    final t = text
        .trim()
        .replaceFirst(RegExp(r'^```(?:json)?\s*\n?'), '')
        .replaceFirst(RegExp(r'\n?```\s*$'), '')
        .trim();
    final start = t.indexOf('{');
    final end = t.lastIndexOf('}');
    if (start != -1 && end > start) return t.substring(start, end + 1);
    return t;
  }

  // ─── Prompt ────────────────────────────────────────────────────────────────

  static const _extractionPrompt = '''
Analyze this receipt image and extract all visible information.
Return ONLY a valid JSON object with this exact structure (no markdown, no commentary):

{
  "merchant_name": "store or restaurant name, empty string if not visible",
  "merchant_confidence": 0.95,
  "date": "YYYY-MM-DD or null",
  "date_confidence": 0.90,
  "total_amount": 0.00,
  "total_confidence": 0.95,
  "items": [
    {
      "name": "item description",
      "quantity": 1.0,
      "unit_price": 0.00,
      "subtotal": 0.00,
      "confidence": 0.90
    }
  ],
  "category": "one of: Groceries, Food/Restaurant, Medicine, Clothes, Hardware, Cosmetics, Entertainment, Others",
  "category_confidence": 0.85,
  "payment_method": "one of: Cash, Card, Digital Wallet, Other",
  "payment_method_confidence": 0.80
}

Rules:
- All confidence scores must be between 0.0 and 1.0
- date must be ISO format YYYY-MM-DD or null
- Extract ALL line items visible on the receipt
- total_amount is the grand total (including tax if shown)
- Return ONLY the JSON object, no other text
''';
}
