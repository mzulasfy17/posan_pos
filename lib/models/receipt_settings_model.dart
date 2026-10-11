class ReceiptSettingsModel {
  final int id;
  final int? merchantId;
  final String storeName;
  final String headerTitle;
  final String storeAddress;
  final String storePhone;
  final String headerSubtitle;
  final bool showLogo;
  final String? logoUrl;
  final bool showOrderType;
  final bool showCashierName;
  final bool showDateTime;
  final String bankInfo;
  final String thankYouMessage;
  final String footerNote;
  final String paperSize; // '58mm' or '80mm'
  final String? printerMac;
  final String? printerName;
  final bool autoPrint;

  const ReceiptSettingsModel({
    this.id = 1,
    this.merchantId,
    this.storeName = 'POSAN Coffee',
    this.headerTitle = 'POSAN Coffee',
    this.storeAddress = '',
    this.storePhone = '',
    this.headerSubtitle = '',
    this.showLogo = true,
    this.logoUrl,
    this.showOrderType = true,
    this.showCashierName = true,
    this.showDateTime = true,
    this.bankInfo = 'BCA : 034-392-4680\nA.N Nacha Soraya',
    this.thankYouMessage = 'Terimakasih Kak.',
    this.footerNote = 'Powered by POSAN POS',
    this.paperSize = '58mm',
    this.printerMac,
    this.printerName,
    this.autoPrint = true,
  });

  ReceiptSettingsModel copyWith({
    int? id,
    int? merchantId,
    String? storeName,
    String? headerTitle,
    String? storeAddress,
    String? storePhone,
    String? headerSubtitle,
    bool? showLogo,
    String? logoUrl,
    bool? showOrderType,
    bool? showCashierName,
    bool? showDateTime,
    String? bankInfo,
    String? thankYouMessage,
    String? footerNote,
    String? paperSize,
    String? printerMac,
    String? printerName,
    bool? autoPrint,
  }) {
    return ReceiptSettingsModel(
      id: id ?? this.id,
      merchantId: merchantId ?? this.merchantId,
      storeName: storeName ?? this.storeName,
      headerTitle: headerTitle ?? this.headerTitle,
      storeAddress: storeAddress ?? this.storeAddress,
      storePhone: storePhone ?? this.storePhone,
      headerSubtitle: headerSubtitle ?? this.headerSubtitle,
      showLogo: showLogo ?? this.showLogo,
      logoUrl: logoUrl ?? this.logoUrl,
      showOrderType: showOrderType ?? this.showOrderType,
      showCashierName: showCashierName ?? this.showCashierName,
      showDateTime: showDateTime ?? this.showDateTime,
      bankInfo: bankInfo ?? this.bankInfo,
      thankYouMessage: thankYouMessage ?? this.thankYouMessage,
      footerNote: footerNote ?? this.footerNote,
      paperSize: paperSize ?? this.paperSize,
      printerMac: printerMac ?? this.printerMac,
      printerName: printerName ?? this.printerName,
      autoPrint: autoPrint ?? this.autoPrint,
    );
  }

  factory ReceiptSettingsModel.fromJson(Map<String, dynamic> json) {
    final mId = (json['merchant_id'] as num?)?.toInt();
    final name = json['store_name']?.toString() ?? 'POSAN Coffee';
    final title = json['header_title']?.toString() ?? name;

    return ReceiptSettingsModel(
      id: (json['id'] is int)
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? '1') ?? 1,
      merchantId: mId,
      storeName: name,
      headerTitle: title,
      storeAddress: json['store_address']?.toString() ?? '',
      storePhone: json['store_phone']?.toString() ?? '',
      headerSubtitle: json['header_subtitle']?.toString() ?? '',
      showLogo: json['show_logo'] == 1 ||
          json['show_logo'] == true ||
          json['show_logo']?.toString().toLowerCase() == 'true' ||
          json['show_logo'] == null,
      logoUrl: json['logo_url']?.toString(),
      showOrderType: json['show_order_type'] == 1 ||
          json['show_order_type'] == true ||
          json['show_order_type']?.toString().toLowerCase() == 'true' ||
          json['show_order_type'] == null,
      showCashierName: json['show_cashier_name'] == 1 ||
          json['show_cashier_name'] == true ||
          json['show_cashier_name']?.toString().toLowerCase() == 'true' ||
          json['show_cashier_name'] == null,
      showDateTime: json['show_date_time'] == 1 ||
          json['show_date_time'] == true ||
          json['show_date_time']?.toString().toLowerCase() == 'true' ||
          json['show_date_time'] == null,
      bankInfo: json['bank_info']?.toString() ??
          'BCA : 034-392-4680\nA.N Nacha Soraya',
      thankYouMessage: json['thank_you_message']?.toString() ?? 'Terimakasih Kak.',
      footerNote: json['footer_note']?.toString() ?? 'Powered by POSAN POS',
      paperSize: json['paper_size']?.toString() ?? '58mm',
      printerMac: json['printer_mac']?.toString(),
      printerName: json['printer_name']?.toString(),
      autoPrint: json['auto_print'] == 1 ||
          json['auto_print'] == true ||
          json['auto_print']?.toString().toLowerCase() == 'true' ||
          json['auto_print'] == null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'merchant_id': merchantId,
      'store_name': storeName,
      'header_title': headerTitle,
      'store_address': storeAddress,
      'store_phone': storePhone,
      'header_subtitle': headerSubtitle,
      'show_logo': showLogo ? 1 : 0,
      'logo_url': logoUrl,
      'show_order_type': showOrderType ? 1 : 0,
      'show_cashier_name': showCashierName ? 1 : 0,
      'show_date_time': showDateTime ? 1 : 0,
      'bank_info': bankInfo,
      'thank_you_message': thankYouMessage,
      'footer_note': footerNote,
      'paper_size': paperSize,
      'printer_mac': printerMac,
      'printer_name': printerName,
      'auto_print': autoPrint ? 1 : 0,
    };
  }
}
