class Retailer {
  final int id;
  final String shopName;
  final String shopDescription;
  final String businessType;
  final String city;
  final String state;
  final String pincode;
  final double averageRating;
  final String? logo;
  final bool offersDelivery;
  final bool offersPickup;

  Retailer({
    required this.id,
    required this.shopName,
    required this.shopDescription,
    required this.businessType,
    required this.city,
    required this.state,
    required this.pincode,
    required this.averageRating,
    this.logo,
    required this.offersDelivery,
    required this.offersPickup,
  });

  factory Retailer.fromJson(Map<String, dynamic> json) {
    return Retailer(
      id: json['id'],
      shopName: json['shop_name'] ?? '',
      shopDescription: json['shop_description'] ?? '',
      businessType: json['business_type'] ?? '',
      city: json['city'] ?? '',
      state: json['state'] ?? '',
      pincode: json['pincode'] ?? '',
      averageRating: json['average_rating'] != null
          ? double.tryParse(json['average_rating'].toString()) ?? 0.0
          : 0.0,
      logo: json['logo'],
      offersDelivery: json['offers_delivery'] ?? false,
      offersPickup: json['offers_pickup'] ?? false,
    );
  }
}
