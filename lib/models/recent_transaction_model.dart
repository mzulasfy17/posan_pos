import 'package:flutter/material.dart';

enum TransactionPaymentMethod {
  qris('QRIS'),
  cash('Tunai'),
  bank('Bank');

  final String label;
  const TransactionPaymentMethod(this.label);

  IconData get icon => switch (this) {
        TransactionPaymentMethod.qris => Icons.qr_code_scanner_rounded,
        TransactionPaymentMethod.cash => Icons.payments_outlined,
        TransactionPaymentMethod.bank => Icons.account_balance_rounded,
      };
}

enum SyncStatus {
  synced('SYNCED'),
  pending('PENDING');

  final String label;
  const SyncStatus(this.label);
}

class RecentTransactionModel {
  final String id;
  final TransactionPaymentMethod paymentMethod;
  final String time;
  final String itemSummary;
  final double totalAmount;
  final double amountPaid;
  final double changeAmount;
  final String status;
  SyncStatus syncStatus;
  final DateTime? createdAt;
  final int? createdAtMillis;
  final String? orderType;
  final String? cashierName;
  final String? customerName;

  RecentTransactionModel({
    required this.id,
    required this.paymentMethod,
    required this.time,
    required this.itemSummary,
    required this.totalAmount,
    this.amountPaid = 0.0,
    this.changeAmount = 0.0,
    this.status = 'PAID',
    this.syncStatus = SyncStatus.synced,
    this.createdAt,
    this.createdAtMillis,
    this.orderType = 'Dine In',
    this.cashierName,
    this.customerName,
  });

  RecentTransactionModel copyWith({
    String? id,
    TransactionPaymentMethod? paymentMethod,
    String? time,
    String? itemSummary,
    double? totalAmount,
    double? amountPaid,
    double? changeAmount,
    String? status,
    SyncStatus? syncStatus,
    DateTime? createdAt,
    int? createdAtMillis,
    String? orderType,
    String? cashierName,
    String? customerName,
  }) {
    return RecentTransactionModel(
      id: id ?? this.id,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      time: time ?? this.time,
      itemSummary: itemSummary ?? this.itemSummary,
      totalAmount: totalAmount ?? this.totalAmount,
      amountPaid: amountPaid ?? this.amountPaid,
      changeAmount: changeAmount ?? this.changeAmount,
      status: status ?? this.status,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt ?? this.createdAt,
      createdAtMillis: createdAtMillis ?? this.createdAtMillis,
      orderType: orderType ?? this.orderType,
      cashierName: cashierName ?? this.cashierName,
      customerName: customerName ?? this.customerName,
    );
  }

  factory RecentTransactionModel.fromJson(Map<String, dynamic> json) {
    final receiptNum = (json['receipt_number'] ?? json['receiptNumber'] ?? json['id'] ?? '').toString();
    final trxId = receiptNum.startsWith('#') ? receiptNum : '#$receiptNum';
    
    final pmName = (json['payment_method_name'] ?? json['paymentMethodName'] ?? json['payment_method'] ?? 'Tunai').toString().toLowerCase();
    TransactionPaymentMethod pm = TransactionPaymentMethod.cash;
    if (pmName.contains('qris')) {
      pm = TransactionPaymentMethod.qris;
    } else if (pmName.contains('bank') || pmName.contains('transfer') || pmName.contains('debit')) {
      pm = TransactionPaymentMethod.bank;
    }

    final rawTotal = json['total_amount'] ?? json['totalAmount'] ?? 0;
    final total = (rawTotal is num) ? rawTotal.toDouble() : (double.tryParse(rawTotal.toString()) ?? 0.0);

    final rawPaid = json['amount_paid'] ?? json['amountPaid'] ?? total;
    final paid = (rawPaid is num) ? rawPaid.toDouble() : (double.tryParse(rawPaid.toString()) ?? total);

    final rawChange = json['change_amount'] ?? json['changeAmount'] ?? 0;
    final change = (rawChange is num) ? rawChange.toDouble() : (double.tryParse(rawChange.toString()) ?? 0.0);

    final createdAtStr = json['created_at']?.toString() ?? json['createdAt']?.toString();
    DateTime? dt = createdAtStr != null ? DateTime.tryParse(createdAtStr)?.toLocal() : null;
    
    String timeFormatted = '12:00 WIB';
    if (dt != null) {
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      timeFormatted = '$h:$m WIB';
    }

    String summary = '';
    final rawItems = json['items'];
    if (rawItems is List && rawItems.isNotEmpty) {
      final summaries = rawItems.map((it) {
        final qty = it['quantity'] ?? it['qty'] ?? 1;
        final name = it['product_name'] ?? it['name'] ?? 'Menu';
        return '$qty $name';
      }).toList();
      summary = summaries.take(2).join(', ');
      if (summaries.length > 2) {
        summary += ' +${summaries.length - 2} lainnya';
      }
    } else {
      summary = (json['notes'] ?? 'Transaksi Kasir').toString();
    }

    final syncStatusStr = (json['sync_status'] ?? 'synced').toString().toLowerCase();
    final syncStatus = syncStatusStr == 'pending' ? SyncStatus.pending : SyncStatus.synced;

    return RecentTransactionModel(
      id: trxId,
      paymentMethod: pm,
      time: timeFormatted,
      itemSummary: summary,
      totalAmount: total,
      amountPaid: paid,
      changeAmount: change,
      status: (json['status']?.toString() ?? 'PAID').toUpperCase() == 'COMPLETED' ? 'PAID' : 'PAID',
      syncStatus: syncStatus,
      createdAt: dt ?? DateTime.now(),
      createdAtMillis: dt?.millisecondsSinceEpoch,
      orderType: json['order_type']?.toString() ?? json['notes']?.toString() ?? 'Dine In',
      cashierName: json['cashier_name']?.toString() ?? 'Kasir',
      customerName: json['customer_name']?.toString(),
    );
  }
}
