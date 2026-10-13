import 'dart:io' show Platform, File;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../models/attendance_model.dart';
import '../../models/cart_order_model.dart';
import '../../models/category_model.dart';
import '../../models/product_model.dart';
import '../../models/recent_transaction_model.dart';
import '../../models/receipt_settings_model.dart';
import '../services/auth_service.dart';

class LocalDatabaseService {
  static final LocalDatabaseService _instance = LocalDatabaseService._internal();
  factory LocalDatabaseService() => _instance;
  LocalDatabaseService._internal();

  Database? _db;
  bool _isInitializing = false;

  int? get _activeMerchantId => AuthService().currentUser?.merchantId;

  Future<Database> get database async {
    if (_db != null && _db!.isOpen) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    if (_isInitializing) {
      while (_isInitializing) {
        await Future.delayed(const Duration(milliseconds: 50));
        if (_db != null && _db!.isOpen) return _db!;
      }
    }
    _isInitializing = true;

    try {
      if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      }

      String dbPath;
      if (kIsWeb) {
        dbPath = 'posan_offline.db';
      } else {
        final docsDir = await getApplicationDocumentsDirectory();
        // Remove legacy unoptimized database file if exists to save disk space
        try {
          final legacyFile = File(p.join(docsDir.path, 'posan_offline.db'));
          if (await legacyFile.exists()) {
            await legacyFile.delete();
          }
        } catch (_) {}
        dbPath = p.join(docsDir.path, 'posan_offline_v2.db');
      }

      final db = await openDatabase(
        dbPath,
        version: 2,
        onCreate: _onCreateTables,
        onUpgrade: _onUpgradeTables,
        onOpen: (db) async {
          debugPrint('POSAN SQLite Database successfully opened at: $dbPath');
          try {
            await db.execute('ALTER TABLE sales_transactions ADD COLUMN merchant_id INTEGER');
          } catch (_) {}
          try {
            await db.execute('ALTER TABLE products ADD COLUMN merchant_id INTEGER');
          } catch (_) {}
          try {
            await db.execute('ALTER TABLE categories ADD COLUMN merchant_id INTEGER');
          } catch (_) {}
          try {
            await db.execute('ALTER TABLE order_logs ADD COLUMN merchant_id INTEGER');
          } catch (_) {}
          try {
            await db.execute('ALTER TABLE transaction_items ADD COLUMN processed_by TEXT');
          } catch (_) {}
          try {
            await db.execute('CREATE INDEX IF NOT EXISTS idx_st_merchant_id ON sales_transactions(merchant_id)');
          } catch (_) {}
          try {
            // Clean up unassigned legacy synced records so they don't pollute any merchant's view
            await db.execute('DELETE FROM sales_transactions WHERE merchant_id IS NULL AND sync_status = "synced"');
          } catch (_) {}
          try {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS attendances (
                id TEXT PRIMARY KEY,
                user_id TEXT NOT NULL,
                user_name TEXT NOT NULL,
                role TEXT NOT NULL,
                merchant_id INTEGER,
                date TEXT NOT NULL,
                check_in_time TEXT,
                check_out_time TEXT,
                status TEXT NOT NULL,
                notes TEXT,
                sync_status TEXT DEFAULT 'synced',
                updated_at TEXT
              )
            ''');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_att_user_date ON attendances(user_id, date)');
          } catch (_) {}
        },
      );

      _isInitializing = false;
      return db;
    } catch (e) {
      _isInitializing = false;
      debugPrint('Error initializing POSAN SQLite Database: $e');
      rethrow;
    }
  }

  Future<void> _onCreateTables(Database db, int version) async {
    debugPrint('Creating POSAN SQLite offline tables with merchant_id isolation...');

    // 1. Categories table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        icon_name TEXT,
        station TEXT DEFAULT 'barista',
        merchant_id INTEGER,
        updated_at TEXT
      )
    ''');

    // 2. Products table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS products (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        category_id TEXT,
        category_name TEXT,
        price REAL NOT NULL DEFAULT 0.0,
        image_asset TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        station TEXT DEFAULT 'barista',
        merchant_id INTEGER,
        updated_at TEXT
      )
    ''');

    // 3. Payment Methods table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS payment_methods (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        merchant_id INTEGER,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // 4. Sales Transactions table (offline-first & sync status)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sales_transactions (
        id TEXT PRIMARY KEY,
        receipt_number TEXT UNIQUE NOT NULL,
        cashier_id TEXT,
        cashier_name TEXT,
        merchant_id INTEGER,
        payment_method_id TEXT,
        payment_method_name TEXT,
        total_amount REAL NOT NULL,
        amount_paid REAL NOT NULL,
        change_amount REAL NOT NULL,
        status TEXT NOT NULL DEFAULT 'completed',
        customer_name TEXT,
        notes TEXT,
        order_type TEXT DEFAULT 'Dine In',
        sync_status TEXT NOT NULL DEFAULT 'pending',
        created_at_millis INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        synced_at TEXT
      )
    ''');

    // 5. Transaction Items table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS transaction_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id TEXT NOT NULL,
        product_id TEXT,
        product_name TEXT NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 1,
        unit_price REAL NOT NULL DEFAULT 0.0,
        subtotal REAL NOT NULL DEFAULT 0.0,
        station TEXT NOT NULL DEFAULT 'barista',
        item_status TEXT NOT NULL DEFAULT 'pending',
        processed_by TEXT,
        created_at_millis INTEGER,
        processing_at_millis INTEGER,
        completed_at_millis INTEGER,
        notes TEXT,
        FOREIGN KEY (transaction_id) REFERENCES sales_transactions (id) ON DELETE CASCADE
      )
    ''');

    // 6. Order Logs table (currentmillis logging for order lifecycle)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS order_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id TEXT NOT NULL,
        item_id INTEGER,
        receipt_number TEXT NOT NULL,
        product_name TEXT NOT NULL,
        station TEXT NOT NULL DEFAULT 'barista',
        status TEXT NOT NULL DEFAULT 'masuk',
        created_at_millis INTEGER NOT NULL,
        processing_at_millis INTEGER,
        completed_at_millis INTEGER,
        updated_by TEXT,
        notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // 7. Sync History Logs table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_history_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        trigger_type TEXT NOT NULL,
        status TEXT NOT NULL,
        message TEXT NOT NULL,
        items_synced INTEGER NOT NULL DEFAULT 0,
        timestamp TEXT NOT NULL
      )
    ''');

    // 8. Receipt Settings table (Header, Footer, Store, Paper Size, Bluetooth Printer)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS receipt_settings (
        id INTEGER PRIMARY KEY,
        store_name TEXT NOT NULL,
        header_title TEXT,
        store_address TEXT,
        store_phone TEXT,
        header_subtitle TEXT,
        show_order_type INTEGER NOT NULL DEFAULT 1,
        show_cashier_name INTEGER NOT NULL DEFAULT 1,
        show_date_time INTEGER NOT NULL DEFAULT 1,
        bank_info TEXT,
        thank_you_message TEXT,
        footer_note TEXT,
        paper_size TEXT NOT NULL DEFAULT '58mm',
        printer_mac TEXT,
        printer_name TEXT,
        auto_print INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // 9. Attendances table (offline-first & sync)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS attendances (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        user_name TEXT NOT NULL,
        role TEXT NOT NULL,
        merchant_id INTEGER,
        date TEXT NOT NULL,
        check_in_time TEXT,
        check_out_time TEXT,
        status TEXT NOT NULL,
        notes TEXT,
        sync_status TEXT DEFAULT 'synced',
        updated_at TEXT
      )
    ''');

    // Create indexes for fast querying
    await db.execute('CREATE INDEX IF NOT EXISTS idx_st_sync_status ON sales_transactions(sync_status)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_st_created_at ON sales_transactions(created_at)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_ti_trx_id ON transaction_items(transaction_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_ti_station_status ON transaction_items(station, item_status)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_ol_receipt ON order_logs(receipt_number)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_att_user_date ON attendances(user_id, date)');
  }

  Future<void> _onUpgradeTables(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE sales_transactions ADD COLUMN created_at_millis INTEGER DEFAULT 0');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE transaction_items ADD COLUMN created_at_millis INTEGER DEFAULT 0');
        await db.execute('ALTER TABLE transaction_items ADD COLUMN processing_at_millis INTEGER');
        await db.execute('ALTER TABLE transaction_items ADD COLUMN completed_at_millis INTEGER');
      } catch (_) {}
      await db.execute('''
        CREATE TABLE IF NOT EXISTS order_logs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          transaction_id TEXT NOT NULL,
          item_id INTEGER,
          receipt_number TEXT NOT NULL,
          product_name TEXT NOT NULL,
          station TEXT NOT NULL DEFAULT 'barista',
          status TEXT NOT NULL DEFAULT 'masuk',
          created_at_millis INTEGER NOT NULL,
          processing_at_millis INTEGER,
          completed_at_millis INTEGER,
          updated_by TEXT,
          notes TEXT,
          created_at TEXT NOT NULL
        )
      ''');
    }
  }

  // ==================== CATEGORIES OPERATIONS ====================

  Future<void> saveCategories(List<CategoryModel> categories, {int? merchantId}) async {
    final db = await database;
    final batch = db.batch();
    for (final cat in categories) {
      batch.insert(
        'categories',
        {
          'id': cat.id,
          'name': cat.name,
          'icon_name': cat.icon?.codePoint.toString() ?? '',
          'station': 'barista',
          'merchant_id': merchantId,
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<CategoryModel>> getCategories({int? merchantId}) async {
    final db = await database;
    final mId = merchantId ?? _activeMerchantId;
    final rows = mId != null
        ? await db.query('categories', where: 'merchant_id = ?', whereArgs: [mId], orderBy: 'id ASC')
        : await db.query('categories', orderBy: 'id ASC');
    if (rows.isEmpty) return [];

    final list = <CategoryModel>[
      const CategoryModel(
        id: 'all',
        name: 'Semua',
        icon: Icons.grid_view_rounded,
      ),
    ];

    for (final row in rows) {
      if (row['id'] == 'all') continue;
      final name = row['name']?.toString() ?? 'Kategori';
      
      IconData icon = Icons.coffee_rounded;
      final nameLower = name.toLowerCase();
      if (nameLower.contains('minum') || nameLower.contains('drink') || nameLower.contains('coffee') || nameLower.contains('teh')) {
        icon = Icons.local_drink_rounded;
      } else if (nameLower.contains('makan') || nameLower.contains('food') || nameLower.contains('nasi')) {
        icon = Icons.restaurant_rounded;
      } else if (nameLower.contains('snack') || nameLower.contains('kentang') || nameLower.contains('roti') || nameLower.contains('pastry')) {
        icon = Icons.cookie_rounded;
      }

      list.add(CategoryModel(
        id: row['id']?.toString() ?? '',
        name: name,
        icon: icon,
      ));
    }
    return list;
  }

  // ==================== PRODUCTS OPERATIONS ====================

  Future<void> saveProducts(List<ProductModel> products, {int? merchantId}) async {
    final db = await database;
    final batch = db.batch();
    for (final p in products) {
      batch.insert(
        'products',
        {
          'id': p.id,
          'name': p.name,
          'category_id': p.categoryId,
          'category_name': p.category,
          'price': p.price,
          'image_asset': p.imageAsset,
          'is_active': p.isAvailable ? 1 : 0,
          'station': 'barista',
          'merchant_id': merchantId,
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<ProductModel>> getProducts({int? merchantId}) async {
    final db = await database;
    final mId = merchantId ?? _activeMerchantId;
    final rows = mId != null
        ? await db.query('products', where: 'is_active = ? AND merchant_id = ?', whereArgs: [1, mId], orderBy: 'name ASC')
        : await db.query('products', where: 'is_active = ?', whereArgs: [1], orderBy: 'name ASC');
    if (rows.isEmpty) return [];

    return rows.map((r) {
      String asset = r['image_asset']?.toString().trim() ?? '';
      if (asset.isEmpty) {
        final name = (r['name']?.toString() ?? '').toLowerCase();
        if (name.contains('croissant') || name.contains('butter') || name.contains('pastry') || name.contains('cheesecake') || name.contains('cake') || name.contains('bakery') || name.contains('roti')) {
          asset = 'assets/images/butter_croissant.jpg';
        } else if (name.contains('almond')) {
          asset = 'assets/images/almond_croissant.jpg';
        } else if (name.contains('matcha') || name.contains('taro') || name.contains('tea') || name.contains('teh') || name.contains('green')) {
          asset = 'assets/images/matcha_latte.jpg';
        } else if (name.contains('americano') || name.contains('black') || name.contains('espresso')) {
          asset = 'assets/images/iced_americano.jpg';
        } else if (name.contains('aren') || name.contains('kopi') || name.contains('coffee') || name.contains('coffe')) {
          asset = 'assets/images/kopi_susu_aren.jpg';
        } else {
          asset = 'assets/images/caramel_macchiato.jpg';
        }
      }
      return ProductModel(
        id: r['id']?.toString() ?? '',
        name: r['name']?.toString() ?? 'Menu',
        categoryId: r['category_id']?.toString() ?? '',
        category: (r['category_name']?.toString() ?? 'MENU').toUpperCase(),
        price: (r['price'] as num?)?.toDouble() ?? 0.0,
        imageAsset: asset,
        isAvailable: (r['is_active'] as int?) == 1,
        cartQuantity: 0,
      );
    }).toList();
  }

  // ==================== TRANSACTIONS OPERATIONS ====================

  /// Simpan transaksi baru secara offline di SQLite dengan isolasi merchant_id
  Future<void> saveTransactionOffline({
    required RecentTransactionModel transaction,
    required List<CartItemModel> items,
    String? cashierId,
    String? cashierName,
    int? merchantId,
    String? orderType,
    String? customerName,
    String? notes,
    bool isSynced = false,
  }) async {
    final db = await database;
    final trxId = transaction.id;
    final receiptNumber = trxId.replaceAll('#', '');
    final now = DateTime.now();
    final nowIso = now.toIso8601String();
    final nowMillis = now.millisecondsSinceEpoch;

    await db.transaction((txn) async {
      await txn.insert(
        'sales_transactions',
        {
          'id': trxId,
          'receipt_number': receiptNumber,
          'cashier_id': cashierId,
          'cashier_name': cashierName ?? 'Kasir POSAN',
          'merchant_id': merchantId,
          'payment_method_id': null,
          'payment_method_name': transaction.paymentMethod.label,
          'total_amount': transaction.totalAmount,
          'amount_paid': transaction.amountPaid > 0 ? transaction.amountPaid : transaction.totalAmount,
          'change_amount': transaction.changeAmount,
          'status': 'completed',
          'customer_name': customerName,
          'notes': notes ?? orderType ?? 'Dine In',
          'order_type': orderType ?? 'Dine In',
          'sync_status': isSynced ? 'synced' : 'pending',
          'created_at_millis': nowMillis,
          'created_at': nowIso,
          'synced_at': isSynced ? nowIso : null,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Insert transaction items
      for (final item in items) {
        String station = 'barista';
        final catLower = item.product.category.toLowerCase();
        final nameLower = item.product.name.toLowerCase();
        if (catLower.contains('makan') || catLower.contains('food') || catLower.contains('snack') ||
            catLower.contains('pastry') || catLower.contains('bakery') ||
            nameLower.contains('nasi') || nameLower.contains('mie') || nameLower.contains('kentang') || nameLower.contains('roti') || nameLower.contains('croissant')) {
          station = 'kitchen';
        }

        final itemId = await txn.insert(
          'transaction_items',
          {
            'transaction_id': trxId,
            'product_id': item.product.id,
            'product_name': item.product.name,
            'quantity': item.quantity,
            'unit_price': item.product.price,
            'subtotal': item.subtotal,
            'station': station,
            'item_status': 'pending',
            'created_at_millis': nowMillis,
            'notes': item.note,
          },
        );

        // Record initial order log with currentmillis
        await txn.insert(
          'order_logs',
          {
            'transaction_id': trxId,
            'item_id': itemId,
            'receipt_number': receiptNumber,
            'product_name': item.product.name,
            'station': station,
            'status': 'masuk',
            'created_at_millis': nowMillis,
            'updated_by': cashierName ?? 'Kasir',
            'notes': item.note,
            'created_at': nowIso,
          },
        );
      }
    });

    debugPrint('Offline transaction saved to SQLite: $trxId (Sync: ${isSynced ? 'SYNCED' : 'PENDING'})');
  }

  /// Ambil pesanan stasiun Barista atau Koki dari SQLite
  /// Untuk Barista dan Koki: hanya berstatus 'masuk' (pending) dan 'diproses' (processing)
  Future<List<Map<String, dynamic>>> getStationOrders(String station, {String statusFilter = 'active', int? merchantId}) async {
    final db = await database;
    final mId = merchantId ?? _activeMerchantId;
    String whereClause = 'ti.station = ?';
    List<dynamic> whereArgs = [station];

    if (mId != null) {
      whereClause += ' AND st.merchant_id = ?';
      whereArgs.add(mId);
    }

    if (statusFilter == 'active') {
      whereClause += " AND ti.item_status IN ('pending', 'processing')";
    } else if (statusFilter != 'all') {
      whereClause += " AND ti.item_status = ?";
      whereArgs.add(statusFilter);
    }

    final query = '''
      SELECT 
        ti.id AS item_id,
        ti.transaction_id,
        ti.product_id,
        ti.product_name,
        ti.quantity,
        ti.unit_price,
        ti.subtotal,
        ti.station,
        ti.item_status,
        ti.processed_by,
        ti.created_at_millis,
        ti.processing_at_millis,
        ti.completed_at_millis,
        ti.notes AS item_notes,
        st.receipt_number,
        st.created_at AS order_time,
        st.customer_name,
        st.notes AS transaction_notes,
        st.cashier_name
      FROM transaction_items ti
      JOIN sales_transactions st ON st.id = ti.transaction_id
      WHERE $whereClause
      ORDER BY 
        CASE 
          WHEN ti.item_status = 'pending' THEN 1
          WHEN ti.item_status = 'processing' THEN 2
          ELSE 3
        END ASC,
        ti.created_at_millis ASC
    ''';

    final rows = await db.rawQuery(query, whereArgs);
    return rows;
  }

  /// Sinkronkan status item dari server ke SQLite (Mencegah downgrade status lokal)
  Future<void> syncStationItemStatus({
    required int itemId,
    required String itemStatus,
    String? processedBy,
    int? processingAtMillis,
    int? completedAtMillis,
  }) async {
    final db = await database;

    // Cegah penimpaan mundur status lokal jika status lokal sudah lebih maju
    final existing = await db.query(
      'transaction_items',
      columns: ['item_status'],
      where: 'id = ?',
      whereArgs: [itemId],
    );

    if (existing.isNotEmpty) {
      final localStatus = existing.first['item_status']?.toString();
      if ((localStatus == 'processing' || localStatus == 'completed') && itemStatus == 'pending') {
        return; // Pertahankan status lokal yang sedang diproses / selesai
      }
      if (localStatus == 'completed' && itemStatus == 'processing') {
        return; // Pertahankan status lokal yang sudah selesai
      }
    }

    final data = <String, dynamic>{
      'item_status': itemStatus,
      'processed_by': processedBy,
    };
    if (processingAtMillis != null) data['processing_at_millis'] = processingAtMillis;
    if (completedAtMillis != null) data['completed_at_millis'] = completedAtMillis;
    await db.update(
      'transaction_items',
      data,
      where: 'id = ?',
      whereArgs: [itemId],
    );
  }

  /// Update status item pesanan stasiun dan catat log currentmillis & processed_by
  Future<void> updateStationItemStatus({
    required int itemId,
    required String nextStatus,
    required String updatedBy,
    String? processedBy,
  }) async {
    final db = await database;
    final now = DateTime.now();
    final nowMillis = now.millisecondsSinceEpoch;
    final nowIso = now.toIso8601String();
    final processor = processedBy ?? updatedBy;

    await db.transaction((txn) async {
      // 1. Get current item details
      final itemRows = await txn.rawQuery('''
        SELECT ti.id, ti.transaction_id, ti.product_name, ti.station, ti.processed_by, ti.created_at_millis, ti.processing_at_millis,
               st.receipt_number
        FROM transaction_items ti
        JOIN sales_transactions st ON st.id = ti.transaction_id
        WHERE ti.id = ?
      ''', [itemId]);

      if (itemRows.isEmpty) return;
      final item = itemRows.first;

      // 2. Update transaction_item
      final Map<String, dynamic> updateData = {'item_status': nextStatus};
      if (nextStatus == 'processing') {
        updateData['processed_by'] = processor;
        updateData['processing_at_millis'] = nowMillis;
      } else if (nextStatus == 'pending') {
        updateData['processed_by'] = null;
        updateData['processing_at_millis'] = null;
      } else if (nextStatus == 'completed') {
        updateData['processed_by'] = item['processed_by'] ?? processor;
        updateData['completed_at_millis'] = nowMillis;
      }

      await txn.update(
        'transaction_items',
        updateData,
        where: 'id = ?',
        whereArgs: [itemId],
      );

      // 3. Insert order log
      final indonesianStatus = nextStatus == 'processing'
          ? 'diproses'
          : (nextStatus == 'completed' ? 'selesai' : (nextStatus == 'pending' ? 'masuk' : 'dibatalkan'));
      await txn.insert('order_logs', {
        'transaction_id': item['transaction_id'],
        'item_id': itemId,
        'receipt_number': item['receipt_number'],
        'product_name': item['product_name'],
        'station': item['station'],
        'status': indonesianStatus,
        'created_at_millis': item['created_at_millis'] ?? nowMillis,
        'processing_at_millis': nextStatus == 'processing' ? nowMillis : item['processing_at_millis'],
        'completed_at_millis': nextStatus == 'completed' ? nowMillis : null,
        'updated_by': processor,
        'created_at': nowIso,
      });
    });
  }

  /// Kasir / Admin mengubah status seluruh item dalam transaksi di SQLite
  Future<void> updateTransactionAllItemsStatus({
    required String receiptNumber,
    required String nextStatus,
    required String updatedBy,
    String? station,
  }) async {
    final db = await database;
    final clean = receiptNumber.replaceAll('#', '').trim();
    final now = DateTime.now();
    final nowMillis = now.millisecondsSinceEpoch;
    final nowIso = now.toIso8601String();

    await db.transaction((txn) async {
      // Find items
      String query = '''
        SELECT ti.id, ti.transaction_id, ti.product_name, ti.station, ti.created_at_millis
        FROM transaction_items ti
        JOIN sales_transactions st ON st.id = ti.transaction_id
        WHERE st.receipt_number = ? OR st.id = ? OR st.id = ?
      ''';
      List<dynamic> args = [clean, clean, '#$clean'];
      if (station != null && station.isNotEmpty) {
        query += ' AND ti.station = ?';
        args.add(station);
      }

      final items = await txn.rawQuery(query, args);
      if (items.isEmpty) return;

      final Map<String, dynamic> updateData = {'item_status': nextStatus};
      if (nextStatus == 'processing') {
        updateData['processed_by'] = updatedBy;
        updateData['processing_at_millis'] = nowMillis;
      } else if (nextStatus == 'pending') {
        updateData['processed_by'] = null;
        updateData['processing_at_millis'] = null;
      } else if (nextStatus == 'completed') {
        updateData['completed_at_millis'] = nowMillis;
      }

      for (final it in items) {
        final itemId = it['id'] as int;
        await txn.update(
          'transaction_items',
          updateData,
          where: 'id = ?',
          whereArgs: [itemId],
        );

        final indonesianStatus = nextStatus == 'processing'
            ? 'diproses'
            : (nextStatus == 'completed' ? 'selesai' : 'masuk');
        await txn.insert('order_logs', {
          'transaction_id': it['transaction_id'],
          'item_id': itemId,
          'receipt_number': clean,
          'product_name': it['product_name'],
          'station': it['station'],
          'status': indonesianStatus,
          'created_at_millis': it['created_at_millis'] ?? nowMillis,
          'processing_at_millis': nextStatus == 'processing' ? nowMillis : null,
          'completed_at_millis': nextStatus == 'completed' ? nowMillis : null,
          'updated_by': updatedBy,
          'created_at': nowIso,
        });
      }
    });
  }

  /// Ambil log pesanan (currentmillis) untuk nomor struk tertentu (Kasir History)
  Future<List<Map<String, dynamic>>> getOrderLogs(String receiptNumber) async {
    final db = await database;
    final clean = receiptNumber.replaceAll('#', '').trim();
    return await db.query(
      'order_logs',
      where: 'receipt_number = ? OR transaction_id = ? OR transaction_id = ?',
      whereArgs: [clean, clean, '#$clean'],
      orderBy: 'id ASC',
    );
  }

  /// Ambil statistik jumlah pesanan stasiun
  Future<Map<String, int>> getStationStats(String station) async {
    final db = await database;
    final res = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(CASE WHEN item_status = 'pending' THEN 1 ELSE 0 END), 0) AS pending_count,
        COALESCE(SUM(CASE WHEN item_status = 'processing' THEN 1 ELSE 0 END), 0) AS processing_count,
        COALESCE(SUM(CASE WHEN item_status = 'completed' THEN 1 ELSE 0 END), 0) AS completed_count,
        COUNT(*) AS total_count
      FROM transaction_items
      WHERE station = ?
    ''', [station]);

    if (res.isNotEmpty) {
      final row = res.first;
      return {
        'pending_count': (row['pending_count'] as num?)?.toInt() ?? 0,
        'processing_count': (row['processing_count'] as num?)?.toInt() ?? 0,
        'completed_count': (row['completed_count'] as num?)?.toInt() ?? 0,
        'total_count': (row['total_count'] as num?)?.toInt() ?? 0,
      };
    }

    return {'pending_count': 0, 'processing_count': 0, 'completed_count': 0, 'total_count': 0};
  }

  /// Ambil riwayat transaksi dari SQLite berdasarkan merchant_id
  Future<List<RecentTransactionModel>> getRecentTransactions({int? merchantId, int limit = 50}) async {
    final db = await database;
    final mId = merchantId ?? _activeMerchantId;
    final rows = mId != null
        ? await db.query(
            'sales_transactions',
            where: 'merchant_id = ?',
            whereArgs: [mId],
            orderBy: 'created_at DESC',
            limit: limit,
          )
        : await db.query(
            'sales_transactions',
            orderBy: 'created_at DESC',
            limit: limit,
          );

    if (rows.isEmpty) return [];

    final list = <RecentTransactionModel>[];
    for (final row in rows) {
      final trxId = row['id']?.toString() ?? '';
      
      // Fetch item names for summary
      final itemRows = await db.query(
        'transaction_items',
        where: 'transaction_id = ?',
        whereArgs: [trxId],
      );

      String summary = '';
      if (itemRows.isNotEmpty) {
        final summaries = itemRows.map((it) {
          final qty = it['quantity'] ?? 1;
          final pName = it['product_name'] ?? 'Menu';
          return '$qty $pName';
        }).toList();
        summary = summaries.take(2).join(', ');
        if (summaries.length > 2) {
          summary += ' +${summaries.length - 2} lainnya';
        }
      } else {
        summary = row['notes']?.toString() ?? 'Transaksi Kasir';
      }

      final pmName = (row['payment_method_name']?.toString() ?? 'Tunai').toLowerCase();
      TransactionPaymentMethod pm = TransactionPaymentMethod.cash;
      if (pmName.contains('qris')) {
        pm = TransactionPaymentMethod.qris;
      } else if (pmName.contains('bank') || pmName.contains('transfer') || pmName.contains('debit')) {
        pm = TransactionPaymentMethod.bank;
      }

      String timeFormatted = '12:00 WIB';
      DateTime? dt;
      if (row['created_at'] != null) {
        dt = DateTime.tryParse(row['created_at'].toString())?.toLocal();
        if (dt != null) {
          final h = dt.hour.toString().padLeft(2, '0');
          final m = dt.minute.toString().padLeft(2, '0');
          timeFormatted = '$h:$m WIB';
        }
      }

      final syncStatusStr = row['sync_status']?.toString() ?? 'synced';
      final syncStatus = syncStatusStr == 'pending' ? SyncStatus.pending : SyncStatus.synced;
      final createdAtMillis = (row['created_at_millis'] as num?)?.toInt() ?? dt?.millisecondsSinceEpoch;
      final orderType = row['order_type']?.toString() ?? 'Dine In';
      final cashierName = row['cashier_name']?.toString();
      final customerName = row['customer_name']?.toString();

      list.add(RecentTransactionModel(
        id: trxId.startsWith('#') ? trxId : '#$trxId',
        paymentMethod: pm,
        time: timeFormatted,
        itemSummary: summary,
        totalAmount: (row['total_amount'] as num?)?.toDouble() ?? 0.0,
        amountPaid: (row['amount_paid'] as num?)?.toDouble() ?? 0.0,
        changeAmount: (row['change_amount'] as num?)?.toDouble() ?? 0.0,
        status: (row['status']?.toString() ?? 'PAID').toUpperCase() == 'COMPLETED' ? 'PAID' : 'PAID',
        syncStatus: syncStatus,
        createdAt: dt ?? DateTime.now(),
        createdAtMillis: createdAtMillis,
        orderType: orderType,
        cashierName: cashierName,
        customerName: customerName,
      ));
    }

    return list;
  }

  /// Ambil semua transaksi yang belum tersinkronkan (sync_status = 'pending')
  Future<List<Map<String, dynamic>>> getPendingSyncTransactions({int? merchantId}) async {
    final db = await database;
    final mId = merchantId ?? _activeMerchantId;
    final rows = mId != null
        ? await db.query(
            'sales_transactions',
            where: 'sync_status = ? AND merchant_id = ?',
            whereArgs: ['pending', mId],
            orderBy: 'created_at ASC',
          )
        : await db.query(
            'sales_transactions',
            where: 'sync_status = ?',
            whereArgs: ['pending'],
            orderBy: 'created_at ASC',
          );

    final payloadList = <Map<String, dynamic>>[];

    for (final row in rows) {
      final trxId = row['id']?.toString() ?? '';
      final itemRows = await db.query(
        'transaction_items',
        where: 'transaction_id = ?',
        whereArgs: [trxId],
      );

      final items = itemRows.map((it) => {
        'product_id': it['product_id'],
        'product_name': it['product_name'],
        'quantity': it['quantity'],
        'unit_price': it['unit_price'],
        'subtotal': it['subtotal'],
        'station': it['station'],
        'item_status': it['item_status'],
        'created_at_millis': it['created_at_millis'],
        'processing_at_millis': it['processing_at_millis'],
        'completed_at_millis': it['completed_at_millis'],
        'notes': it['notes'],
      }).toList();

      payloadList.add({
        'id': trxId,
        'receipt_number': row['receipt_number'] ?? trxId.replaceAll('#', ''),
        'cashier_id': row['cashier_id'],
        'cashier_name': row['cashier_name'],
        'merchant_id': row['merchant_id'] ?? mId,
        'payment_method_name': row['payment_method_name'],
        'total_amount': row['total_amount'],
        'amount_paid': row['amount_paid'],
        'change_amount': row['change_amount'],
        'customer_name': row['customer_name'],
        'notes': row['notes'],
        'order_type': row['order_type'],
        'created_at_millis': row['created_at_millis'],
        'created_at': row['created_at'],
        'items': items,
      });
    }

    return payloadList;
  }

  /// Hapus transaksi dari SQLite lokal setelah berhasil disinkronkan ke server PostgreSQL
  Future<void> deleteSyncedTransactions(List<String> receiptNumbers) async {
    if (receiptNumbers.isEmpty) return;
    final db = await database;
    await db.transaction((txn) async {
      for (final r in receiptNumbers) {
        final clean = r.replaceAll('#', '').trim();
        final rows = await txn.query(
          'sales_transactions',
          columns: ['id'],
          where: 'receipt_number = ? OR id = ? OR id = ?',
          whereArgs: [clean, clean, '#$clean'],
        );
        for (final row in rows) {
          final tId = row['id'] as String;
          await txn.delete('transaction_items', where: 'transaction_id = ?', whereArgs: [tId]);
          await txn.delete('order_logs', where: 'transaction_id = ? OR receipt_number = ?', whereArgs: [tId, clean]);
        }
        await txn.delete(
          'sales_transactions',
          where: 'receipt_number = ? OR id = ? OR id = ?',
          whereArgs: [clean, clean, '#$clean'],
        );
      }
    });
    try {
      await db.execute('VACUUM;');
      await db.execute('PRAGMA wal_checkpoint(TRUNCATE);');
    } catch (_) {}
    debugPrint('🗑️ Berhasil menghapus ${receiptNumbers.length} data transaksi lokal di SQLite dan memadatkan storage (VACUUM).');
  }

  /// Hapus seluruh riwayat transaksi lokal yang berstatus bukan pending (membersihkan storage lokal)
  Future<void> deleteAllSyncedTransactions({int? merchantId}) async {
    final db = await database;
    final mId = merchantId ?? _activeMerchantId;
    await db.transaction((txn) async {
      final rows = mId != null
          ? await txn.query(
              'sales_transactions',
              columns: ['id', 'receipt_number'],
              where: "sync_status != 'pending' AND merchant_id = ?",
              whereArgs: [mId],
            )
          : await txn.query(
              'sales_transactions',
              columns: ['id', 'receipt_number'],
              where: "sync_status != 'pending'",
            );

      for (final row in rows) {
        final tId = row['id'] as String;
        final rNum = row['receipt_number']?.toString() ?? '';
        await txn.delete('transaction_items', where: 'transaction_id = ?', whereArgs: [tId]);
        await txn.delete('order_logs', where: 'transaction_id = ? OR receipt_number = ?', whereArgs: [tId, rNum]);
      }

      if (mId != null) {
        await txn.delete('sales_transactions', where: "sync_status != 'pending' AND merchant_id = ?", whereArgs: [mId]);
      } else {
        await txn.delete('sales_transactions', where: "sync_status != 'pending'");
      }
    });
    try {
      await db.execute('VACUUM;');
      await db.execute('PRAGMA wal_checkpoint(TRUNCATE);');
    } catch (_) {}
    debugPrint('🧹 Data transaksi tersinkron di SQLite lokal berhasil dibersihkan dan dipadatkan (VACUUM).');
  }

  /// Tandai transaksi sebagai telah tersinkronkan dan hapus dari SQLite lokal
  Future<void> markTransactionsAsSynced(List<String> receiptNumbers) async {
    await deleteSyncedTransactions(receiptNumbers);
  }

  /// Hitung jumlah transaksi yang belum tersinkron
  Future<int> getPendingSyncCount({int? merchantId}) async {
    final db = await database;
    final mId = merchantId ?? _activeMerchantId;
    final String query = mId != null
        ? "SELECT COUNT(*) FROM sales_transactions WHERE sync_status = 'pending' AND merchant_id = ?"
        : "SELECT COUNT(*) FROM sales_transactions WHERE sync_status = 'pending'";
    final List<dynamic> args = mId != null ? [mId] : [];
    
    final count = Sqflite.firstIntValue(await db.rawQuery(query, args));
    return count ?? 0;
  }

  /// Membersihkan transaksi online dari SQLite lokal agar tidak membebani kapasitas memori lokal
  Future<void> syncOnlineTransactions(List<Map<String, dynamic>> onlineTrxs, {int? merchantId, bool replaceSynced = true}) async {
    // Sesuai aturan: data transaksi di lokal dihapus saat sinkronisasi, tidak disimpan kembali ke SQLite lokal
    await deleteAllSyncedTransactions(merchantId: merchantId);
  }

  /// Hitung total transaksi dan penjualan hari ini di SQLite dengan filter merchant_id
  Future<Map<String, dynamic>> getTodayMetrics({int? merchantId}) async {
    final db = await database;
    final mId = merchantId ?? _activeMerchantId;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayStartIso = todayStart.toIso8601String();
    final todayStartMillis = todayStart.millisecondsSinceEpoch;

    String whereClause = 'created_at >= ? OR created_at_millis >= ?';
    List<dynamic> whereArgs = [todayStartIso, todayStartMillis];
    if (mId != null) {
      whereClause = '($whereClause) AND merchant_id = ?';
      whereArgs.add(mId);
    }

    final res = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(total_amount), 0.0) as total_sales,
        COUNT(*) as total_count,
        COALESCE(SUM(CASE WHEN sync_status = 'pending' THEN 1 ELSE 0 END), 0) as pending_count
      FROM sales_transactions
      WHERE $whereClause
    ''', whereArgs);

    if (res.isNotEmpty) {
      final row = res.first;
      return {
        'todaySales': (row['total_sales'] as num?)?.toDouble() ?? 0.0,
        'todayCount': (row['total_count'] as num?)?.toInt() ?? 0,
        'pendingCount': (row['pending_count'] as num?)?.toInt() ?? 0,
      };
    }

    return {
      'todaySales': 0.0,
      'todayCount': 0,
      'pendingCount': 0,
    };
  }

  // ==================== SYNC HISTORY LOGS ====================

  Future<void> logSyncEvent({
    required String triggerType,
    required String status,
    required String message,
    int itemsSynced = 0,
  }) async {
    final db = await database;
    await db.insert('sync_history_logs', {
      'trigger_type': triggerType,
      'status': status,
      'message': message,
      'items_synced': itemsSynced,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getSyncLogs({int limit = 15}) async {
    final db = await database;
    return await db.query(
      'sync_history_logs',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
  }

  /// Ambil detail item dari transaksi berdasarkan ID (untuk cetak struk akurat)
  Future<List<Map<String, dynamic>>> getTransactionItems(String transactionId) async {
    final db = await database;
    final clean = transactionId.replaceAll('#', '').trim();
    try {
      final rows = await db.query(
        'transaction_items',
        where: 'transaction_id = ? OR transaction_id = ? OR transaction_id = ?',
        whereArgs: [transactionId, clean, '#$clean'],
        orderBy: 'id ASC',
      );
      return rows;
    } catch (e) {
      debugPrint('getTransactionItems error: $e');
      return [];
    }
  }

  // ==================== RECEIPT SETTINGS ====================

  Future<ReceiptSettingsModel> getReceiptSettings({int? merchantId}) async {
    final db = await database;
    final mId = merchantId ?? _activeMerchantId;
    try {
      // Create table if not exists (runtime fallback)
      await db.execute('''
        CREATE TABLE IF NOT EXISTS receipt_settings (
          id INTEGER PRIMARY KEY,
          merchant_id INTEGER,
          store_name TEXT NOT NULL,
          header_title TEXT,
          store_address TEXT,
          store_phone TEXT,
          header_subtitle TEXT,
          show_logo INTEGER NOT NULL DEFAULT 1,
          logo_url TEXT,
          show_order_type INTEGER NOT NULL DEFAULT 1,
          show_cashier_name INTEGER NOT NULL DEFAULT 1,
          show_date_time INTEGER NOT NULL DEFAULT 1,
          bank_info TEXT,
          thank_you_message TEXT,
          footer_note TEXT,
          paper_size TEXT NOT NULL DEFAULT '58mm',
          printer_mac TEXT,
          printer_name TEXT,
          auto_print INTEGER NOT NULL DEFAULT 1
        )
      ''');

      // Migration check for existing SQLite databases
      try {
        await db.execute('ALTER TABLE receipt_settings ADD COLUMN merchant_id INTEGER');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE receipt_settings ADD COLUMN show_logo INTEGER NOT NULL DEFAULT 1');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE receipt_settings ADD COLUMN logo_url TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE receipt_settings ADD COLUMN printer_mac TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE receipt_settings ADD COLUMN printer_name TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE receipt_settings ADD COLUMN auto_print INTEGER NOT NULL DEFAULT 1');
      } catch (_) {}

      final rows = mId != null
          ? await db.query('receipt_settings', where: 'merchant_id = ?', whereArgs: [mId], limit: 1)
          : await db.query('receipt_settings', limit: 1);

      if (rows.isNotEmpty) {
        return ReceiptSettingsModel.fromJson(rows.first);
      }
    } catch (e) {
      debugPrint('getReceiptSettings local error: $e');
    }

    final user = AuthService().currentUser;
    final dynamicStoreName = (user?.merchantName != null && user!.merchantName!.isNotEmpty)
        ? user.merchantName!
        : 'POSAN Coffee';

    return ReceiptSettingsModel(
      merchantId: mId,
      storeName: dynamicStoreName,
      headerTitle: dynamicStoreName,
      storeAddress: user?.merchantAddress ?? '',
      storePhone: '',
    );

  }

  Future<void> saveReceiptSettings(ReceiptSettingsModel settings) async {
    final db = await database;
    final mId = settings.merchantId ?? _activeMerchantId;
    final finalSettings = settings.copyWith(merchantId: mId);

    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS receipt_settings (
          id INTEGER PRIMARY KEY,
          merchant_id INTEGER,
          store_name TEXT NOT NULL,
          header_title TEXT,
          store_address TEXT,
          store_phone TEXT,
          header_subtitle TEXT,
          show_logo INTEGER NOT NULL DEFAULT 1,
          logo_url TEXT,
          show_order_type INTEGER NOT NULL DEFAULT 1,
          show_cashier_name INTEGER NOT NULL DEFAULT 1,
          show_date_time INTEGER NOT NULL DEFAULT 1,
          bank_info TEXT,
          thank_you_message TEXT,
          footer_note TEXT,
          paper_size TEXT NOT NULL DEFAULT '58mm',
          printer_mac TEXT,
          printer_name TEXT,
          auto_print INTEGER NOT NULL DEFAULT 1
        )
      ''');

      try {
        await db.execute('ALTER TABLE receipt_settings ADD COLUMN merchant_id INTEGER');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE receipt_settings ADD COLUMN show_logo INTEGER NOT NULL DEFAULT 1');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE receipt_settings ADD COLUMN logo_url TEXT');
      } catch (_) {}

      await db.insert(
        'receipt_settings',
        finalSettings.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint('Receipt & Printer settings saved to local SQLite: ${finalSettings.headerTitle}');
    } catch (e) {
      debugPrint('saveReceiptSettings local error: $e');
    }
  }

  /// Ambil data shift aktif dari SQLite
  Future<Map<String, dynamic>?> getActiveShift({int? merchantId}) async {
    final db = await database;
    final mId = merchantId ?? _activeMerchantId;
    try {
      await _ensureShiftTable(db);
      final rows = await db.query(
        'cashier_shifts',
        where: mId != null ? 'merchant_id = ? AND status = ?' : 'status = ?',
        whereArgs: mId != null ? [mId, 'open'] : ['open'],
        orderBy: 'id DESC',
        limit: 1,
      );
      if (rows.isNotEmpty) {
        return rows.first;
      }
    } catch (e) {
      debugPrint('getActiveShift error: $e');
    }
    return null;
  }

  /// Ambil modal awal kasir aktif
  Future<double> getStartingCash({int? merchantId}) async {
    final activeShift = await getActiveShift(merchantId: merchantId);
    if (activeShift != null && activeShift['starting_cash'] != null) {
      return (activeShift['starting_cash'] as num).toDouble();
    }
    return 200000.0;
  }

  /// Update modal awal kasir
  Future<void> updateStartingCash(double amount, {int? merchantId, String? cashierName}) async {
    final db = await database;
    final mId = merchantId ?? _activeMerchantId;
    await _ensureShiftTable(db);
    final active = await getActiveShift(merchantId: mId);
    final nowIso = DateTime.now().toIso8601String();

    if (active != null) {
      await db.update(
        'cashier_shifts',
        {'starting_cash': amount},
        where: 'id = ?',
        whereArgs: [active['id']],
      );
    } else {
      await db.insert('cashier_shifts', {
        'merchant_id': mId,
        'cashier_name': cashierName ?? 'Kasir',
        'shift_name': 'Shift Utama',
        'starting_cash': amount,
        'status': 'open',
        'opened_at': nowIso,
      });
    }
  }

  /// Tutup shift kasir dan catat rekonsiliasi kas
  Future<void> recordCloseShift({
    int? merchantId,
    required String cashierName,
    required double startingCash,
    required double cashSales,
    required double qrisSales,
    required double bankSales,
    required double totalSales,
    required double physicalCash,
    required double difference,
    String? notes,
  }) async {
    final db = await database;
    final mId = merchantId ?? _activeMerchantId;
    final nowIso = DateTime.now().toIso8601String();
    await _ensureShiftTable(db);

    final active = await getActiveShift(merchantId: mId);
    if (active != null) {
      await db.update(
        'cashier_shifts',
        {
          'starting_cash': startingCash,
          'cash_sales': cashSales,
          'qris_sales': qrisSales,
          'bank_sales': bankSales,
          'total_sales': totalSales,
          'physical_cash': physicalCash,
          'difference': difference,
          'notes': notes,
          'status': 'closed',
          'closed_at': nowIso,
        },
        where: 'id = ?',
        whereArgs: [active['id']],
      );
    } else {
      await db.insert('cashier_shifts', {
        'merchant_id': mId,
        'cashier_name': cashierName,
        'shift_name': 'Shift Utama',
        'starting_cash': startingCash,
        'cash_sales': cashSales,
        'qris_sales': qrisSales,
        'bank_sales': bankSales,
        'total_sales': totalSales,
        'physical_cash': physicalCash,
        'difference': difference,
        'notes': notes,
        'status': 'closed',
        'opened_at': nowIso,
        'closed_at': nowIso,
      });
    }
  }

  /// Buka shift kasir baru
  Future<void> openNewShift({
    int? merchantId,
    required String cashierName,
    double startingCash = 200000.0,
    String shiftName = 'Shift Utama',
  }) async {
    final db = await database;
    final mId = merchantId ?? _activeMerchantId;
    final nowIso = DateTime.now().toIso8601String();
    await _ensureShiftTable(db);

    // Tutup shift lama jika masih terbuka
    await db.update(
      'cashier_shifts',
      {'status': 'closed', 'closed_at': nowIso},
      where: mId != null ? 'merchant_id = ? AND status = ?' : 'status = ?',
      whereArgs: mId != null ? [mId, 'open'] : ['open'],
    );

    // Buka shift baru
    await db.insert('cashier_shifts', {
      'merchant_id': mId,
      'cashier_name': cashierName,
      'shift_name': shiftName,
      'starting_cash': startingCash,
      'status': 'open',
      'opened_at': nowIso,
    });
  }

  Future<void> _ensureShiftTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cashier_shifts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        merchant_id INTEGER,
        cashier_id TEXT,
        cashier_name TEXT,
        shift_name TEXT,
        starting_cash REAL NOT NULL DEFAULT 200000.0,
        cash_sales REAL NOT NULL DEFAULT 0.0,
        qris_sales REAL NOT NULL DEFAULT 0.0,
        bank_sales REAL NOT NULL DEFAULT 0.0,
        total_sales REAL NOT NULL DEFAULT 0.0,
        physical_cash REAL NOT NULL DEFAULT 0.0,
        difference REAL NOT NULL DEFAULT 0.0,
        notes TEXT,
        status TEXT NOT NULL DEFAULT 'open',
        opened_at TEXT NOT NULL,
        closed_at TEXT
      )
    ''');
  }

  // ===========================================================================
  // ATTENDANCE METHODS (OFFLINE-FIRST & SYNC)
  // ===========================================================================

  Future<void> saveAttendanceRecord(AttendanceRecordModel record, {String syncStatus = 'synced'}) async {
    final db = await database;
    await db.insert(
      'attendances',
      {
        'id': record.id,
        'user_id': record.userId,
        'user_name': record.userName,
        'role': record.role,
        'merchant_id': _activeMerchantId,
        'date': record.date.toIso8601String().split('T')[0],
        'check_in_time': record.checkInTime?.toIso8601String(),
        'check_out_time': record.checkOutTime?.toIso8601String(),
        'status': record.status == AttendanceStatus.working
            ? 'working'
            : (record.status == AttendanceStatus.completed ? 'completed' : 'notCheckedIn'),
        'notes': record.notes,
        'sync_status': syncStatus,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveAttendanceBatch(List<AttendanceRecordModel> records) async {
    if (records.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final r in records) {
      batch.insert(
        'attendances',
        {
          'id': r.id,
          'user_id': r.userId,
          'user_name': r.userName,
          'role': r.role,
          'merchant_id': _activeMerchantId,
          'date': r.date.toIso8601String().split('T')[0],
          'check_in_time': r.checkInTime?.toIso8601String(),
          'check_out_time': r.checkOutTime?.toIso8601String(),
          'status': r.status == AttendanceStatus.working
              ? 'working'
              : (r.status == AttendanceStatus.completed ? 'completed' : 'notCheckedIn'),
          'notes': r.notes,
          'sync_status': 'synced',
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<AttendanceRecordModel?> getTodayAttendance(String userId) async {
    final db = await database;
    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    final rows = await db.query(
      'attendances',
      where: 'user_id = ? AND date = ?',
      whereArgs: [userId, todayStr],
      orderBy: 'id DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _mapRowToAttendance(rows.first);
  }

  Future<List<AttendanceRecordModel>> getAttendanceHistory(String userId, {int limit = 50}) async {
    final db = await database;
    final rows = await db.query(
      'attendances',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'date DESC, check_in_time DESC',
      limit: limit,
    );
    return rows.map((r) => _mapRowToAttendance(r)).toList();
  }

  AttendanceRecordModel _mapRowToAttendance(Map<String, dynamic> row) {
    AttendanceStatus parsedStatus = AttendanceStatus.notCheckedIn;
    final statusStr = row['status']?.toString();
    if (statusStr == 'working' || statusStr == 'Sedang Bekerja') {
      parsedStatus = AttendanceStatus.working;
    } else if (statusStr == 'completed' || statusStr == 'Selesai Bekerja') {
      parsedStatus = AttendanceStatus.completed;
    }

    return AttendanceRecordModel(
      id: row['id']?.toString() ?? '',
      userId: row['user_id']?.toString() ?? '',
      userName: row['user_name']?.toString() ?? 'Karyawan',
      role: row['role']?.toString() ?? 'kasir',
      date: row['date'] != null
          ? DateTime.tryParse(row['date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      checkInTime: row['check_in_time'] != null
          ? DateTime.tryParse(row['check_in_time'].toString())
          : null,
      checkOutTime: row['check_out_time'] != null
          ? DateTime.tryParse(row['check_out_time'].toString())
          : null,
      status: parsedStatus,
      notes: row['notes']?.toString(),
    );
  }
}

