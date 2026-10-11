import 'package:intl/intl.dart';

class OrderLogModel {
  final int? id;
  final String transactionId;
  final int? itemId;
  final String receiptNumber;
  final String productName;
  final String station; // 'barista' or 'kitchen'
  final String status; // 'masuk', 'diproses', 'selesai'
  final int createdAtMillis;
  final int? processingAtMillis;
  final int? completedAtMillis;
  final String? updatedBy;
  final String? notes;
  final String? createdAt;

  const OrderLogModel({
    this.id,
    required this.transactionId,
    this.itemId,
    required this.receiptNumber,
    required this.productName,
    required this.station,
    required this.status,
    required this.createdAtMillis,
    this.processingAtMillis,
    this.completedAtMillis,
    this.updatedBy,
    this.notes,
    this.createdAt,
  });

  String get formattedCreatedTime {
    final dt = DateTime.fromMillisecondsSinceEpoch(createdAtMillis);
    return DateFormat('HH:mm:ss').format(dt);
  }

  String? get formattedProcessingTime {
    if (processingAtMillis == null || processingAtMillis == 0) return null;
    final dt = DateTime.fromMillisecondsSinceEpoch(processingAtMillis!);
    return DateFormat('HH:mm:ss').format(dt);
  }

  String? get formattedCompletedTime {
    if (completedAtMillis == null || completedAtMillis == 0) return null;
    final dt = DateTime.fromMillisecondsSinceEpoch(completedAtMillis!);
    return DateFormat('HH:mm:ss').format(dt);
  }

  /// Durasi pengerjaan dari masuk hingga selesai (atau diproses)
  String get processingDurationFormatted {
    if (completedAtMillis != null && completedAtMillis! > 0) {
      final start = processingAtMillis ?? createdAtMillis;
      final diffSeconds = ((completedAtMillis! - start) / 1000).round();
      if (diffSeconds < 60) return '$diffSeconds dtk';
      final min = diffSeconds ~/ 60;
      final sec = diffSeconds % 60;
      return '$min m $sec d';
    } else if (processingAtMillis != null && processingAtMillis! > 0) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final diffSeconds = ((now - processingAtMillis!) / 1000).round();
      final min = diffSeconds ~/ 60;
      return '$min m berjalan';
    }
    return 'Menunggu antrean';
  }

  static int? _parseNullableInt(dynamic val) {
    if (val == null) return null;
    if (val is int) return val;
    if (val is num) return val.toInt();
    return int.tryParse(val.toString().trim());
  }

  factory OrderLogModel.fromJson(Map<String, dynamic> json) {
    final rawCreatedAtMillis = _parseNullableInt(json['created_at_millis']);
    final createdAtMillis = rawCreatedAtMillis ??
        (json['created_at'] != null
            ? DateTime.tryParse(json['created_at'].toString())?.millisecondsSinceEpoch ??
                DateTime.now().millisecondsSinceEpoch
            : DateTime.now().millisecondsSinceEpoch);

    return OrderLogModel(
      id: _parseNullableInt(json['id']),
      transactionId: json['transaction_id']?.toString() ?? '',
      itemId: _parseNullableInt(json['item_id']),
      receiptNumber: json['receipt_number']?.toString() ?? '',
      productName: json['product_name']?.toString() ?? '',
      station: json['station']?.toString() ?? 'barista',
      status: json['status']?.toString() ?? 'masuk',
      createdAtMillis: createdAtMillis,
      processingAtMillis: _parseNullableInt(json['processing_at_millis']),
      completedAtMillis: _parseNullableInt(json['completed_at_millis']),
      updatedBy: json['updated_by']?.toString(),
      notes: json['notes']?.toString(),
      createdAt: json['created_at']?.toString(),
    );
  }
}
