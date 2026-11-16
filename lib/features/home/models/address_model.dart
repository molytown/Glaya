class ZoneData {
  String? zoneCurrency;
  double? perKmShippingCharge;
  double? minimumShippingCharge;
  bool? cod;

  ZoneData({
    this.zoneCurrency,
    this.perKmShippingCharge,
    this.minimumShippingCharge,
    this.cod,
  });

  factory ZoneData.fromJson(Map<String, dynamic> json) {
    return ZoneData(
      zoneCurrency: json['zone_currency'],
      perKmShippingCharge: json['per_km_shipping_charge']?.toDouble(),
      minimumShippingCharge: json['minimum_shipping_charge']?.toDouble(),
      cod: json['cod'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'zone_currency': zoneCurrency,
      'per_km_shipping_charge': perKmShippingCharge,
      'minimum_shipping_charge': minimumShippingCharge,
      'cod': cod,
    };
  }
}

class AddressModel {
  String? latitude;
  String? longitude;
  String? addressType;
  String? address;
  int? zoneId;
  List<int>? zoneIds;
  List<ZoneData>? zoneData;

  AddressModel({
    this.latitude,
    this.longitude,
    this.addressType,
    this.address,
    this.zoneId,
    this.zoneIds,
    this.zoneData,
  });

  factory AddressModel.fromJson(Map<String, dynamic> json) {
    return AddressModel(
      latitude: json['latitude'],
      longitude: json['longitude'],
      addressType: json['address_type'],
      address: json['address'],
      zoneId: json['zone_id'],
      zoneIds: json['zone_ids'] != null 
          ? List<int>.from(json['zone_ids'].map((x) => x)) 
          : null,
      zoneData: json['zone_data'] != null
          ? List<ZoneData>.from(json['zone_data'].map((x) => ZoneData.fromJson(x)))
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'address_type': addressType,
      'address': address,
      'zone_id': zoneId,
      'zone_ids': zoneIds,
      'zone_data': zoneData?.map((x) => x.toJson()).toList(),
    };
  }
}
