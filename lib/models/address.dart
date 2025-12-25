class Address {
  final int? id;
  final String title;
  final String addressType; // 'home', 'office', 'other'
  final String addressLine1;
  final String addressLine2;
  final String landmark;
  final String city;
  final String state;
  final String pincode;
  final bool isDefault;
  final double? latitude;
  final double? longitude;

  Address({
    this.id,
    required this.title,
    this.addressType = 'home',
    required this.addressLine1,
    this.addressLine2 = '',
    this.landmark = '',
    required this.city,
    required this.state,
    required this.pincode,
    this.isDefault = false,
    this.latitude,
    this.longitude,
  });

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      id: json['id'],
      title: json['title'] ?? '',
      addressType: json['address_type'] ?? 'home',
      addressLine1: json['address_line1'] ?? '',
      addressLine2: json['address_line2'] ?? '',
      landmark: json['landmark'] ?? '',
      city: json['city'] ?? '',
      state: json['state'] ?? '',
      pincode: json['pincode'] ?? '',
      isDefault: json['is_default'] ?? false,
      latitude: json['latitude'] != null
          ? double.parse(json['latitude'].toString())
          : null,
      longitude: json['longitude'] != null
          ? double.parse(json['longitude'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'address_type': addressType,
      'address_line1': addressLine1,
      'address_line2': addressLine2,
      'landmark': landmark,
      'city': city,
      'state': state,
      'pincode': pincode,
      'is_default': isDefault,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}
