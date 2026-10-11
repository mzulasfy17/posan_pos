class StationOrderItemModel {
  final int itemId;
  final String transactionId;
  final String? productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double subtotal;
  final String station; // 'barista' or 'kitchen'
  final String itemStatus; // 'pending', 'processing', 'completed'
  final String? processedBy; // Nama staf yang sedang memproses
  final int createdAtMillis;
  final int? processingAtMillis;
  final int? completedAtMillis;
  final String? itemNotes;
  final String receiptNumber;
  final String orderTime;
  final String? customerName;
  final String? transactionNotes;
  final String? cashierName;

  const StationOrderItemModel({
    required this.itemId,
    required this.transactionId,
    this.productId,
    required this.productName,
    required this.quantity,
    this.unitPrice = 0.0,
    this.subtotal = 0.0,
    required this.station,
    this.itemStatus = 'pending',
    this.processedBy,
    required this.createdAtMillis,
    this.processingAtMillis,
    this.completedAtMillis,
    this.itemNotes,
    required this.receiptNumber,
    required this.orderTime,
    this.customerName,
    this.transactionNotes,
    this.cashierName,
  });

  bool get isPending => itemStatus == 'pending' || itemStatus == 'masuk';
  bool get isProcessing => itemStatus == 'processing' || itemStatus == 'diproses';
  bool get isCompleted => itemStatus == 'completed' || itemStatus == 'selesai';

  /// Cek apakah pesanan sedang diproses oleh staf LAIN (sehingga terkunci untuk staf ini)
  bool isLockedByOther(String? currentUserName) {
    if (!isProcessing) return false;
    if (processedBy == null || processedBy!.trim().isEmpty) return false;
    if (currentUserName == null || currentUserName.trim().isEmpty) return false;
    return processedBy!.trim().toLowerCase() != currentUserName.trim().toLowerCase();
  }

  /// Cek apakah pesanan sedang diproses oleh staf yang sedang login ini
  bool isProcessedByMe(String? currentUserName) {
    if (!isProcessing) return false;
    if (processedBy == null || processedBy!.trim().isEmpty) return true; // Tidak ada yang lock, anggap boleh
    if (currentUserName == null || currentUserName.trim().isEmpty) return true;
    return processedBy!.trim().toLowerCase() == currentUserName.trim().toLowerCase();
  }

  /// Format elapsed duration in minutes & seconds
  String get elapsedMinutesFormatted {
    final now = DateTime.now().millisecondsSinceEpoch;
    final diffMs = now - createdAtMillis;
    if (diffMs < 0) return '0 m';
    final minutes = diffMs ~/ (1000 * 60);
    if (minutes < 60) {
      return '$minutes m lalu';
    } else {
      final hours = minutes ~/ 60;
      final remMin = minutes % 60;
      return '${hours}j ${remMin}m';
    }
  }

  static int _parseInt(dynamic val, [int def = 0]) {
    if (val == null) return def;
    if (val is int) return val;
    if (val is num) return val.toInt();
    return int.tryParse(val.toString().trim()) ?? def;
  }

  static int? _parseNullableInt(dynamic val) {
    if (val == null) return null;
    if (val is int) return val;
    if (val is num) return val.toInt();
    return int.tryParse(val.toString().trim());
  }

  static double _parseDouble(dynamic val, [double def = 0.0]) {
    if (val == null) return def;
    if (val is double) return val;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString().trim()) ?? def;
  }

  StationOrderItemModel copyWith({
    int? itemId,
    String? transactionId,
    String? productId,
    String? productName,
    int? quantity,
    double? unitPrice,
    double? subtotal,
    String? station,
    String? itemStatus,
    String? processedBy,
    int? createdAtMillis,
    int? processingAtMillis,
    int? completedAtMillis,
    String? itemNotes,
    String? receiptNumber,
    String? orderTime,
    String? customerName,
    String? transactionNotes,
    String? cashierName,
  }) {
    return StationOrderItemModel(
      itemId: itemId ?? this.itemId,
      transactionId: transactionId ?? this.transactionId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      subtotal: subtotal ?? this.subtotal,
      station: station ?? this.station,
      itemStatus: itemStatus ?? this.itemStatus,
      processedBy: processedBy ?? this.processedBy,
      createdAtMillis: createdAtMillis ?? this.createdAtMillis,
      processingAtMillis: processingAtMillis ?? this.processingAtMillis,
      completedAtMillis: completedAtMillis ?? this.completedAtMillis,
      itemNotes: itemNotes ?? this.itemNotes,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      orderTime: orderTime ?? this.orderTime,
      customerName: customerName ?? this.customerName,
      transactionNotes: transactionNotes ?? this.transactionNotes,
      cashierName: cashierName ?? this.cashierName,
    );
  }

  factory StationOrderItemModel.fromJson(Map<String, dynamic> json) {
    final rawCreatedAtMillis = _parseNullableInt(json['created_at_millis']);
    final createdAtMillis = rawCreatedAtMillis ??
        (json['created_at'] != null
            ? DateTime.tryParse(json['created_at'].toString())?.millisecondsSinceEpoch ??
                DateTime.now().millisecondsSinceEpoch
            : DateTime.now().millisecondsSinceEpoch);

    return StationOrderItemModel(
      itemId: _parseInt(json['item_id'] ?? json['id']),
      transactionId: json['transaction_id']?.toString() ?? '',
      productId: json['product_id']?.toString(),
      productName: json['product_name']?.toString() ?? 'Menu',
      quantity: _parseInt(json['quantity'], 1),
      unitPrice: _parseDouble(json['unit_price']),
      subtotal: _parseDouble(json['subtotal']),
      station: json['station']?.toString() ?? 'barista',
      itemStatus: json['item_status']?.toString() ?? 'pending',
      processedBy: json['processed_by']?.toString(),
      createdAtMillis: createdAtMillis,
      processingAtMillis: _parseNullableInt(json['processing_at_millis']),
      completedAtMillis: _parseNullableInt(json['completed_at_millis']),
      itemNotes: json['item_notes']?.toString() ?? json['notes']?.toString(),
      receiptNumber: json['receipt_number']?.toString() ?? '',
      orderTime: json['order_time']?.toString() ?? json['created_at']?.toString() ?? '',
      customerName: json['customer_name']?.toString(),
      transactionNotes: json['transaction_notes']?.toString(),
      cashierName: json['cashier_name']?.toString(),
    );
  }
}
