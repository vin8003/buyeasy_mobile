class Product {
  final int id;
  final String name;
  final String description;
  final double price;
  final String image; // Field name from API
  final double mrp; // Field name from API is 'original_price'
  final double discountPercent; // Field name from API is 'discount_percentage'
  final String unit;
  final String categoryName;
  final String brandName;
  final int stockQuantity;
  final bool isAvailable;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.image,
    required this.mrp,
    required this.discountPercent,
    required this.unit,
    required this.categoryName,
    required this.brandName,
    required this.stockQuantity,
    this.isAvailable = true,
  });

  // A factory constructor to safely create a Product from JSON data
  factory Product.fromJson(Map<String, dynamic> json) {
    // Helper to safely parse numbers (int or double) to double
    double safeParseDouble(dynamic value) {
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return Product(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] ?? 'No description available.',
      price: safeParseDouble(
        json['discounted_price'] ?? json['price'],
      ), // Use the calculated discounted price
      mrp: safeParseDouble(
        json['original_price'] ?? json['price'],
      ), // Fallback to price if original_price is null
      discountPercent: safeParseDouble(json['discount_percentage']),
      image: json['image'] ?? '', // This should be the main image URL
      unit: json['unit'] ?? 'piece',
      categoryName: json['category_name'] ?? '',
      brandName: json['brand_name'] ?? '',
      stockQuantity: json['quantity'] ?? 0,
      isAvailable: json['is_available'] ?? true,
    );
  }

  // Override toString for easy debugging
  @override
  String toString() {
    return 'Product{id: $id, name: $name, price: $price}';
  }
}
