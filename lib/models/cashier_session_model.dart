class CashierSessionModel {
  final int? merchantId;
  final String cashierName;
  final String cashierGreeting;
  final String role;
  final String merchantName;
  final String outletLocation;
  final String shift;
  final String shiftNumber;
  final String activeStation;
  final double todaySalesAmount;
  final int todayTransactionCount;
  final int pendingSyncCount;
  final String lastSyncTime;
  final int localStorageCount;
  final bool isOnline;
  final bool isAutoSyncing;
  final double initialCash;

  static const CashierSessionModel empty = CashierSessionModel(
    merchantId: null,
    cashierName: 'Kasir',
    cashierGreeting: 'Selamat bertugas 👋',
    role: 'kasir',
    merchantName: 'POSAN Cafe',
    outletLocation: 'Cabang Utama',
    shift: 'Shift Utama',
    shiftNumber: 'Shift 1',
    activeStation: 'Kasir Utama',
    todaySalesAmount: 0.0,
    todayTransactionCount: 0,
    pendingSyncCount: 0,
    lastSyncTime: 'Belum sinkron',
    localStorageCount: 0,
    isOnline: true,
    isAutoSyncing: false,
    initialCash: 0.0,
  );

  const CashierSessionModel({
    this.merchantId,
    required this.cashierName,
    this.cashierGreeting = 'Selamat bertugas 👋',
    this.role = 'kasir',
    required this.merchantName,
    this.outletLocation = '',
    required this.shift,
    this.shiftNumber = 'Shift 1',
    required this.activeStation,
    this.todaySalesAmount = 0.0,
    this.todayTransactionCount = 0,
    this.pendingSyncCount = 0,
    this.lastSyncTime = 'Belum sinkron',
    this.localStorageCount = 0,
    this.isOnline = true,
    this.isAutoSyncing = false,
    this.initialCash = 0.0,
  });

  CashierSessionModel copyWith({
    int? merchantId,
    String? cashierName,
    String? cashierGreeting,
    String? role,
    String? merchantName,
    String? outletLocation,
    String? shift,
    String? shiftNumber,
    String? activeStation,
    double? todaySalesAmount,
    int? todayTransactionCount,
    int? pendingSyncCount,
    String? lastSyncTime,
    int? localStorageCount,
    bool? isOnline,
    bool? isAutoSyncing,
    double? initialCash,
  }) {
    return CashierSessionModel(
      merchantId: merchantId ?? this.merchantId,
      cashierName: cashierName ?? this.cashierName,
      cashierGreeting: cashierGreeting ?? this.cashierGreeting,
      role: role ?? this.role,
      merchantName: merchantName ?? this.merchantName,
      outletLocation: outletLocation ?? this.outletLocation,
      shift: shift ?? this.shift,
      shiftNumber: shiftNumber ?? this.shiftNumber,
      activeStation: activeStation ?? this.activeStation,
      todaySalesAmount: todaySalesAmount ?? this.todaySalesAmount,
      todayTransactionCount:
          todayTransactionCount ?? this.todayTransactionCount,
      pendingSyncCount: pendingSyncCount ?? this.pendingSyncCount,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      localStorageCount: localStorageCount ?? this.localStorageCount,
      isOnline: isOnline ?? this.isOnline,
      isAutoSyncing: isAutoSyncing ?? this.isAutoSyncing,
      initialCash: initialCash ?? this.initialCash,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'merchantId': merchantId,
      'cashierName': cashierName,
      'cashierGreeting': cashierGreeting,
      'role': role,
      'merchantName': merchantName,
      'outletLocation': outletLocation,
      'shift': shift,
      'shiftNumber': shiftNumber,
      'activeStation': activeStation,
      'todaySalesAmount': todaySalesAmount,
      'todayTransactionCount': todayTransactionCount,
      'pendingSyncCount': pendingSyncCount,
      'lastSyncTime': lastSyncTime,
      'localStorageCount': localStorageCount,
      'isOnline': isOnline,
      'isAutoSyncing': isAutoSyncing,
      'initialCash': initialCash,
    };
  }

  factory CashierSessionModel.fromJson(Map<String, dynamic> json) {
    return CashierSessionModel(
      merchantId: (json['merchantId'] as num?)?.toInt(),
      cashierName: json['cashierName']?.toString() ?? 'Kasir',
      cashierGreeting: json['cashierGreeting']?.toString() ?? 'Selamat bertugas 👋',
      role: json['role']?.toString() ?? 'kasir',
      merchantName: json['merchantName']?.toString() ?? 'POSAN Cafe',
      outletLocation: json['outletLocation']?.toString() ?? '',
      shift: json['shift']?.toString() ?? 'Shift Utama',
      shiftNumber: json['shiftNumber']?.toString() ?? 'Shift 1',
      activeStation: json['activeStation']?.toString() ?? 'Kasir Utama',
      todaySalesAmount: (json['todaySalesAmount'] as num?)?.toDouble() ?? 0.0,
      todayTransactionCount: (json['todayTransactionCount'] as num?)?.toInt() ?? 0,
      pendingSyncCount: (json['pendingSyncCount'] as num?)?.toInt() ?? 0,
      lastSyncTime: json['lastSyncTime']?.toString() ?? 'Belum sinkron',
      localStorageCount: (json['localStorageCount'] as num?)?.toInt() ?? 0,
      isOnline: json['isOnline'] == null || json['isOnline'] == true,
      isAutoSyncing: json['isAutoSyncing'] == true,
      initialCash: (json['initialCash'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
