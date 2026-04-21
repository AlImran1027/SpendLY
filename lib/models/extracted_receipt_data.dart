/// Data model for receipt data extracted by Gemini AI.
///
/// Holds the merchant name, date, total amount, individual line items,
/// category, payment method, and per-field confidence scores.
/// Used by [ExtractionResultsScreen] to display and edit extracted data.
library;

/// Represents a single line item on a receipt.
class ExtractedItem {
  String name;
  double quantity;
  double unitPrice;
  double subtotal;
  double confidence; // 0.0 – 1.0

  /// VAT/tax rate as a percentage (e.g. 15.0 for 15%). Null if not on receipt.
  double? vatRate;

  /// VAT/tax amount for this line item. Null if not on receipt.
  double? vatAmount;

  ExtractedItem({
    required this.name,
    this.quantity = 1.0,
    this.unitPrice = 0.0,
    required this.subtotal,
    this.confidence = 0.0,
    this.vatRate,
    this.vatAmount,
  });

  /// Creates an [ExtractedItem] from a JSON map.
  factory ExtractedItem.fromJson(Map<String, dynamic> json) {
    return ExtractedItem(
      name: json['name'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0.0,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      vatRate: (json['vat_rate'] as num?)?.toDouble(),
      vatAmount: (json['vat_amount'] as num?)?.toDouble(),
    );
  }

  /// Serialises this item to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'name': name,
        'quantity': quantity,
        'unit_price': unitPrice,
        'subtotal': subtotal,
        'confidence': confidence,
        if (vatRate != null) 'vat_rate': vatRate,
        if (vatAmount != null) 'vat_amount': vatAmount,
      };

  /// True when this item has VAT information.
  bool get hasVat => vatRate != null || vatAmount != null;
}

/// The overall extraction status from the AI.
enum ExtractionStatus { success, partial, failed }

/// Holds all data extracted from a single receipt image.
class ExtractedReceiptData {
  String merchantName;
  double merchantConfidence;

  DateTime? date;
  double dateConfidence;

  double totalAmount;
  double totalConfidence;

  /// Total VAT/tax amount shown on the receipt (null if not present).
  double? taxAmount;

  List<ExtractedItem> items;

  String category;
  double categoryConfidence;

  String paymentMethod; // Cash, Card, Digital Wallet, Other
  double paymentMethodConfidence;

  /// Path to the original receipt image on disk.
  final String imagePath;

  /// Overall extraction status.
  ExtractionStatus status;

  ExtractedReceiptData({
    this.merchantName = '',
    this.merchantConfidence = 0.0,
    this.date,
    this.dateConfidence = 0.0,
    this.totalAmount = 0.0,
    this.totalConfidence = 0.0,
    this.taxAmount,
    List<ExtractedItem>? items,
    this.category = 'Others',
    this.categoryConfidence = 0.0,
    this.paymentMethod = 'Cash',
    this.paymentMethodConfidence = 0.0,
    required this.imagePath,
    this.status = ExtractionStatus.success,
  }) : items = items ?? [];

  /// Creates an [ExtractedReceiptData] from a JSON map (Gemini API response).
  factory ExtractedReceiptData.fromJson(
    Map<String, dynamic> json, {
    required String imagePath,
  }) {
    final itemsList = (json['items'] as List<dynamic>?)
            ?.map((e) => ExtractedItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    // Determine status based on how many key fields were extracted.
    final hasMerchant =
        (json['merchant_name'] as String?)?.isNotEmpty ?? false;
    final hasDate = json['date'] != null;
    final hasTotal = (json['total_amount'] as num?)?.toDouble() != null &&
        (json['total_amount'] as num).toDouble() > 0;

    ExtractionStatus status;
    if (hasMerchant && hasDate && hasTotal) {
      status = ExtractionStatus.success;
    } else if (hasMerchant || hasDate || hasTotal) {
      status = ExtractionStatus.partial;
    } else {
      status = ExtractionStatus.failed;
    }

    return ExtractedReceiptData(
      merchantName: json['merchant_name'] as String? ?? '',
      merchantConfidence:
          (json['merchant_confidence'] as num?)?.toDouble() ?? 0.0,
      date: json['date'] != null
          ? DateTime.tryParse(json['date'] as String)
          : null,
      dateConfidence: (json['date_confidence'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      totalConfidence:
          (json['total_confidence'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (json['tax_amount'] as num?)?.toDouble(),
      items: itemsList,
      category: json['category'] as String? ?? 'Others',
      categoryConfidence:
          (json['category_confidence'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['payment_method'] as String? ?? 'Cash',
      paymentMethodConfidence:
          (json['payment_method_confidence'] as num?)?.toDouble() ?? 0.0,
      imagePath: imagePath,
      status: status,
    );
  }

  /// Serialises this receipt data to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'merchant_name': merchantName,
        'merchant_confidence': merchantConfidence,
        'date': date?.toIso8601String(),
        'date_confidence': dateConfidence,
        'total_amount': totalAmount,
        'total_confidence': totalConfidence,
        if (taxAmount != null) 'tax_amount': taxAmount,
        'items': items.map((e) => e.toJson()).toList(),
        'category': category,
        'category_confidence': categoryConfidence,
        'payment_method': paymentMethod,
        'payment_method_confidence': paymentMethodConfidence,
        'status': status.name,
      };

  /// Generates realistic demo data for UI development & testing.
  factory ExtractedReceiptData.sample({required String imagePath}) {
    return ExtractedReceiptData(
      merchantName: 'Metro Supermarket',
      merchantConfidence: 0.95,
      date: DateTime(2026, 2, 28),
      dateConfidence: 0.92,
      totalAmount: 1240.50,
      totalConfidence: 0.98,
      items: [
        ExtractedItem(
          name: 'Fresh Milk 1L',
          quantity: 2,
          unitPrice: 180.00,
          subtotal: 360.00,
          confidence: 0.94,
        ),
        ExtractedItem(
          name: 'Whole Wheat Bread',
          quantity: 1,
          unitPrice: 120.50,
          subtotal: 120.50,
          confidence: 0.91,
        ),
        ExtractedItem(
          name: 'Organic Eggs (12pc)',
          quantity: 1,
          unitPrice: 350.00,
          subtotal: 350.00,
          confidence: 0.89,
        ),
        ExtractedItem(
          name: 'Basmati Rice 5kg',
          quantity: 1,
          unitPrice: 410.00,
          subtotal: 410.00,
          confidence: 0.87,
        ),
      ],
      category: 'Groceries',
      categoryConfidence: 0.88,
      paymentMethod: 'Card',
      paymentMethodConfidence: 0.75,
      imagePath: imagePath,
      status: ExtractionStatus.success,
    );
  }
}
