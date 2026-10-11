import 'product_model.dart';

class CartItemModel {
  final ProductModel product;
  int quantity;
  String? note;
  final String unitLabel;

  CartItemModel({
    required this.product,
    required this.quantity,
    this.note,
    this.unitLabel = 'porsi',
  });

  double get subtotal => product.price * quantity;

  CartItemModel copyWith({
    ProductModel? product,
    int? quantity,
    String? note,
    String? unitLabel,
  }) {
    return CartItemModel(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      note: note ?? this.note,
      unitLabel: unitLabel ?? this.unitLabel,
    );
  }
}

class OrderInfoModel {
  final String orderType;
  final String station;
  final double discount;
  final double taxRate;
  final String? orderNote;

  const OrderInfoModel({
    this.orderType = 'Dine In',
    this.station = 'Kasir Utama',
    this.discount = 0.0,
    this.taxRate = 0.0,
    this.orderNote,
  });

  OrderInfoModel copyWith({
    String? orderType,
    String? station,
    double? discount,
    double? taxRate,
    String? orderNote,
  }) {
    return OrderInfoModel(
      orderType: orderType ?? this.orderType,
      station: station ?? this.station,
      discount: discount ?? this.discount,
      taxRate: taxRate ?? this.taxRate,
      orderNote: orderNote ?? this.orderNote,
    );
  }
}
