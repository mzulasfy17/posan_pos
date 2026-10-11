class ProductModel {
  final String id;
  final String name;
  final String categoryId;
  final String category;
  final double price;
  final String imageAsset;
  final bool isAvailable;
  int cartQuantity;

  ProductModel({
    required this.id,
    required this.name,
    this.categoryId = '',
    required this.category,
    required this.price,
    required this.imageAsset,
    this.isAvailable = true,
    this.cartQuantity = 0,
  });

  ProductModel copyWith({
    String? id,
    String? name,
    String? categoryId,
    String? category,
    double? price,
    String? imageAsset,
    bool? isAvailable,
    int? cartQuantity,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      category: category ?? this.category,
      price: price ?? this.price,
      imageAsset: imageAsset ?? this.imageAsset,
      isAvailable: isAvailable ?? this.isAvailable,
      cartQuantity: cartQuantity ?? this.cartQuantity,
    );
  }
}
