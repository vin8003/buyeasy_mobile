class WishlistItem {
  final int id;
  final int productId;
  final String productName;
  final double productPrice;
  final String? productImage;
  final String retailerName;

  WishlistItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.productPrice,
    this.productImage,
    required this.retailerName,
  });

  factory WishlistItem.fromJson(Map<String, dynamic> json) {
    return WishlistItem(
      id: json['id'],
      productId: json['product'],
      productName: json['product_name'],
      productPrice: double.parse(json['product_price'].toString()),
      productImage: json['product_image'],
      retailerName: json['retailer_name'],
    );
  }
}
