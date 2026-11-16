import 'address_model.dart';

class ZoneResponseModel {
  bool isSuccess;
  String message;
  List<int> zoneIds;
  List<ZoneData> zoneData;

  ZoneResponseModel(
    this.isSuccess,
    this.message,
    this.zoneIds,
    this.zoneData,
  );
}
