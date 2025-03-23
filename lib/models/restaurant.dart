/// 餐廳類型枚舉
enum RestaurantType {
  chinese,
  japanese,
  korean,
  thai,
  western,
  italian,
  american,
  mexican,
  indian,
  vietnamese,
  seafood,
  bbq,
  hotpot,
  vegetarian,
  fastFood,
  cafe,
  dessert,
  other,
}

/// 餐廳模型
class Restaurant {
  /// 唯一ID
  final String id;

  /// 餐廳名稱
  final String name;

  /// 餐廳類型
  final RestaurantType type;

  /// 餐廳地址
  final String address;

  /// 餐廳照片URL
  final String? photoUrl;

  /// Google Maps 位置ID
  final String? placeId;

  /// 餐廳評分 (0-5)
  final double? rating;

  /// 營業時間
  final Map<String, String>? openingHours;

  /// 聯絡電話
  final String? phoneNumber;

  /// 餐廳網站
  final String? website;

  /// 座位容量估計
  final int? seatCapacity;

  /// 平均價格範圍 (0-4: 0最便宜，4最貴)
  final int? priceLevel;

  /// 創建時間
  final DateTime createdAt;

  /// 更新時間
  final DateTime updatedAt;

  const Restaurant({
    required this.id,
    required this.name,
    required this.type,
    required this.address,
    this.photoUrl,
    this.placeId,
    this.rating,
    this.openingHours,
    this.phoneNumber,
    this.website,
    this.seatCapacity,
    this.priceLevel,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 從JSON創建實例
  factory Restaurant.fromJson(Map<String, dynamic> json) {
    return Restaurant(
      id: json['id'],
      name: json['name'],
      type: RestaurantType.values.byName(json['type']),
      address: json['address'],
      photoUrl: json['photo_url'],
      placeId: json['place_id'],
      rating: json['rating'],
      openingHours:
          json['opening_hours'] != null
              ? Map<String, String>.from(json['opening_hours'])
              : null,
      phoneNumber: json['phone_number'],
      website: json['website'],
      seatCapacity: json['seat_capacity'],
      priceLevel: json['price_level'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  /// 轉換為JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'address': address,
      'photo_url': photoUrl,
      'place_id': placeId,
      'rating': rating,
      'opening_hours': openingHours,
      'phone_number': phoneNumber,
      'website': website,
      'seat_capacity': seatCapacity,
      'price_level': priceLevel,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// 創建副本並更新特定字段
  Restaurant copyWith({
    String? id,
    String? name,
    RestaurantType? type,
    String? address,
    String? photoUrl,
    String? placeId,
    double? rating,
    Map<String, String>? openingHours,
    String? phoneNumber,
    String? website,
    int? seatCapacity,
    int? priceLevel,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Restaurant(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      address: address ?? this.address,
      photoUrl: photoUrl ?? this.photoUrl,
      placeId: placeId ?? this.placeId,
      rating: rating ?? this.rating,
      openingHours: openingHours ?? this.openingHours,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      website: website ?? this.website,
      seatCapacity: seatCapacity ?? this.seatCapacity,
      priceLevel: priceLevel ?? this.priceLevel,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
