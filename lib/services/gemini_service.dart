/// Gemini AI service — receipt image extraction via Google Generative AI SDK.
///
/// Sends a receipt image to Gemini and parses the structured JSON response
/// into an [ExtractedReceiptData] model that the extraction results screen
/// can display and edit.
///
/// The API key is stored in SharedPreferences under [prefKey] and loaded once
/// at startup via [load]. Callers check [hasApiKey] before calling
/// [extractFromImage], and use [setApiKey] to persist a new key.
library;

import 'dart:convert';
import 'dart:io';

import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/extracted_receipt_data.dart';

// ─── Exception types ─────────────────────────────────────────────────────────

/// Thrown when [extractFromImage] is called without an API key configured.
class GeminiApiKeyMissingException implements Exception {
  const GeminiApiKeyMissingException();
  @override
  String toString() => 'Gemini API key is not configured';
}

/// Thrown when the model returns an unreadable or structurally invalid response.
class GeminiParseException implements Exception {
  final String message;
  const GeminiParseException(this.message);
  @override
  String toString() => 'GeminiParseException: $message';
}

// ═════════════════════════════════════════════════════════════════════════════
// SERVICE
// ═════════════════════════════════════════════════════════════════════════════

class GeminiService {
  GeminiService._();
  static final GeminiService instance = GeminiService._();

  static const String prefKey = 'pref_gemini_api_key';
  static const String _model = 'gemini-2.5-flash';

  String? _apiKey;

  /// True when a non-empty API key is in memory.
  bool get hasApiKey => _apiKey != null && _apiKey!.isNotEmpty;

  /// Returns a masked preview of the stored key (e.g. `"AIza••••1234"`).
  String get apiKeyMasked {
    if (!hasApiKey) return '';
    final k = _apiKey!;
    if (k.length <= 8) return '••••••••';
    return '${k.substring(0, 4)}••••${k.substring(k.length - 4)}';
  }

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  /// Load persisted key from SharedPreferences. Call in [main] before [runApp].
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _apiKey = prefs.getString(prefKey);
  }

  /// Persist a new API key and update the in-memory value.
  /// Pass an empty string to clear the key.
  Future<void> setApiKey(String key) async {
    _apiKey = key.trim();
    final prefs = await SharedPreferences.getInstance();
    if (_apiKey!.isEmpty) {
      _apiKey = null;
      await prefs.remove(prefKey);
    } else {
      await prefs.setString(prefKey, _apiKey!);
    }
  }

  // ─── Extraction ────────────────────────────────────────────────────────────

  /// Sends [imagePath] to the Gemini 1.5 Flash model and returns the parsed
  /// [ExtractedReceiptData].
  ///
  /// Throws:
  /// - [GeminiApiKeyMissingException] when no key is configured.
  /// - [GeminiParseException] when the response cannot be parsed as JSON.
  /// - Platform / network exceptions from the SDK for other failures.
  Future<ExtractedReceiptData> extractFromImage(String imagePath) async {
    if (!hasApiKey) throw const GeminiApiKeyMissingException();

    final imageFile = File(imagePath); // Ensure the file exists before sending to the model.
    if (!await imageFile.exists()) {
      throw Exception('Receipt image not found at: $imagePath');
    }

    final imageBytes = await imageFile.readAsBytes();
    final mime = _mimeType(imagePath);

    final model = GenerativeModel(model: _model, apiKey: _apiKey!); //

    final response = await model.generateContent([ // Send both the image and the prompt as input to the model.
      Content.multi([
        DataPart(mime, imageBytes),
        TextPart(_extractionPrompt),
      ]),
    ]);

    final raw = response.text;
    if (raw == null || raw.trim().isEmpty) {
      throw const GeminiParseException('Empty response from Gemini');
    }

    try {
      final jsonStr = _extractJsonString(raw); // Strip markdown and find the JSON block in the response.
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return ExtractedReceiptData.fromJson(json, imagePath: imagePath); // Parse the JSON into our data model.
    } on FormatException catch (e) {
      throw GeminiParseException('Invalid JSON in response: ${e.message}');
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
  "date": "DD-MM-YYYY or null",
  "date_confidence": 0.90,
  "total_amount": 0.00,
  "total_confidence": 0.95,
  "tax_amount": 0.00,
  "items": [
    {
      "name": "item description",
      "quantity": 1.0,
      "unit_price": 0.00,
      "subtotal": 0.00,
      "vat_rate": 15.0,
      "vat_amount": 0.00,
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
- tax_amount is the total VAT/tax line shown on the receipt; omit the field (do not include it) if no tax line is visible
- For each item: if a VAT rate is printed next to the item, set vat_rate (percentage, e.g. 15.0) and compute vat_amount; omit both fields if no per-item VAT is shown
- Return ONLY the JSON object, no other text
''';
}
