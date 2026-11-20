import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:get/get.dart';
import '../repository/location_repository.dart';
import '../models/address_model.dart';
import '../models/zone_response_model.dart';
import '../models/prediction_model.dart';

class LocationController extends GetxController implements GetxService {
  final LocationRepository locationRepository;

  LocationController({required this.locationRepository});

  Position _position = Position(
      longitude: 0,
      latitude: 0,
      timestamp: DateTime.now(),
      accuracy: 1,
      altitude: 1,
      altitudeAccuracy: 1,
      heading: 1,
      headingAccuracy: 1,
      speed: 1,
      speedAccuracy: 1);

  Position _pickPosition = Position(
      longitude: 0,
      latitude: 0,
      timestamp: DateTime.now(),
      accuracy: 1,
      altitude: 1,
      altitudeAccuracy: 1,
      heading: 1,
      headingAccuracy: 1,
      speed: 1,
      speedAccuracy: 1);

  bool _loading = false;
  String? _address = '';
  String? _pickAddress = '';
  final List<Marker> _markers = <Marker>[];
  List<AddressModel>? _addressList;
  late List<AddressModel> _allAddressList;
  int _addressTypeIndex = 0;
  final List<String?> _addressTypeList = ['home', 'office', 'others'];
  bool _isLoading = false;
  bool _inZone = false;
  int _zoneID = 0;
  bool _buttonDisabled = true;
  bool _changeAddress = true;
  GoogleMapController? _mapController;
  List<PredictionModel> _predictionList = [];
  bool _updateAddAddressData = true;
  bool _showLocationSuggestion = true;

  List<PredictionModel> get predictionList => _predictionList;
  bool get isLoading => _isLoading;
  bool get loading => _loading;
  Position get position => _position;
  Position get pickPosition => _pickPosition;
  String? get address => _address;
  String? get pickAddress => _pickAddress;
  List<Marker> get markers => _markers;
  List<AddressModel>? get addressList => _addressList;
  List<String?> get addressTypeList => _addressTypeList;
  int get addressTypeIndex => _addressTypeIndex;
  bool get inZone => _inZone;
  int get zoneID => _zoneID;
  bool get buttonDisabled => _buttonDisabled;
  GoogleMapController? get mapController => _mapController;
  bool get showLocationSuggestion => _showLocationSuggestion;

  void hideSuggestedLocation() {
    _showLocationSuggestion = !_showLocationSuggestion;
    update();
  }

  Future<AddressModel> getCurrentLocation(bool fromAddress,
      {GoogleMapController? mapController,
      LatLng? defaultLatLng,
      bool notify = true,
      bool showSnackBar = false}) async {
    _loading = true;
    if (notify) {
      update();
    }
    AddressModel addressModel;
    Position myPosition;
    try {
      await Geolocator.requestPermission();
      Position newLocalData = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      myPosition = newLocalData;
    } catch (e) {
      myPosition = Position(
        latitude: defaultLatLng != null ? defaultLatLng.latitude : 0,
        longitude: defaultLatLng != null ? defaultLatLng.longitude : 0,
        timestamp: DateTime.now(),
        accuracy: 1,
        altitude: 1,
        altitudeAccuracy: 1,
        heading: 1,
        headingAccuracy: 1,
        speed: 1,
        speedAccuracy: 1,
      );
    }

    if (fromAddress) {
      _position = myPosition;
    } else {
      _pickPosition = myPosition;
    }

    if (mapController != null) {
      mapController.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(
            target: LatLng(myPosition.latitude, myPosition.longitude),
            zoom: 16),
      ));
    }

    String addressFromGeocode = await getAddressFromGeocode(
        LatLng(myPosition.latitude, myPosition.longitude));

    fromAddress
        ? _address = addressFromGeocode
        : _pickAddress = addressFromGeocode;

    ZoneResponseModel responseModel = await getZone(
        myPosition.latitude.toString(), myPosition.longitude.toString(), true,
        showSnackBar: showSnackBar);

    _buttonDisabled = !responseModel.isSuccess;

    addressModel = AddressModel(
      latitude: myPosition.latitude.toString(),
      longitude: myPosition.longitude.toString(),
      addressType: 'others',
      zoneId: responseModel.isSuccess ? responseModel.zoneIds[0] : 0,
      zoneIds: responseModel.zoneIds,
      address: addressFromGeocode,
      zoneData: responseModel.zoneData,
    );

    _loading = false;
    update();
    return addressModel;
  }

  Future<ZoneResponseModel> getZone(
      String? lat, String? long, bool updateInAddress,
      {bool markerLoad = false, bool showSnackBar = true}) async {
    if (lat == null || lat.isEmpty || long == null || long.isEmpty) {
      return ZoneResponseModel(false, 'Invalid coordinates', [], []);
    }

    _loading = true;
    if (!updateInAddress) {
      update();
    }

    final cachedZone = await locationRepository.getCachedZone(lat, long);
    if (cachedZone != null && cachedZone.isSuccess) {
      _inZone = true;
      _zoneID = cachedZone.zoneIds.isNotEmpty ? cachedZone.zoneIds[0] : 0;

      if (updateInAddress) {
        AddressModel? address = await getUserAddress();
        if (address != null) {
          address.zoneData = cachedZone.zoneData;
          saveUserAddress(address);
        }
      }

      if (markerLoad) {
        _loading = false;
      } else {
        _isLoading = false;
      }
      update();
      return cachedZone;
    }

    final response = await locationRepository.getZone(lat, long);

    ZoneResponseModel responseModel;
    if (response.statusCode == 200) {
      _inZone = true;
      List<int> zoneIds = [];

      Map<String, dynamic> body = {};
      try {
        body = jsonDecode(response.body);
      } catch (e) {
        body = {};
      }

      try {
        final zoneIdData = body['zone_id'];
        if (zoneIdData == null) {
          _zoneID = 0;
        } else if (zoneIdData is List) {
          for (var zoneId in zoneIdData) {
            zoneIds.add(int.parse(zoneId.toString()));
          }
          _zoneID = zoneIds.isNotEmpty ? zoneIds[0] : 0;
        } else if (zoneIdData is String) {
          try {
            List<dynamic> zoneIdList = jsonDecode(zoneIdData);
            for (var zoneId in zoneIdList) {
              zoneIds.add(int.parse(zoneId.toString()));
            }
            _zoneID = zoneIds.isNotEmpty ? zoneIds[0] : 0;
          } catch (e) {
            _zoneID = int.parse(zoneIdData);
            zoneIds.add(_zoneID);
          }
        } else {
          _zoneID = int.parse(zoneIdData.toString());
          zoneIds.add(_zoneID);
        }
      } catch (e) {
        _zoneID = 0;
      }

      List<ZoneData> zoneData = [];
      final zoneDataRaw = body['zone_data'];
      if (zoneDataRaw != null && zoneDataRaw is List) {
        for (var data in zoneDataRaw) {
          zoneData.add(ZoneData.fromJson(data));
        }
      }

      responseModel = ZoneResponseModel(true, '', zoneIds, zoneData);

      await locationRepository.saveZoneToCache(lat, long, responseModel);

      if (updateInAddress) {
        AddressModel? address = await getUserAddress();
        if (address != null) {
          address.zoneData = zoneData;
          saveUserAddress(address);
        }
      }
    } else {
      _inZone = false;
      responseModel = ZoneResponseModel(false, 'Failed to get zone', [], []);
    }

    if (markerLoad) {
      _loading = false;
    } else {
      _isLoading = false;
    }
    update();
    return responseModel;
  }

  void updatePosition(CameraPosition? position, bool fromAddress) async {
    if (_updateAddAddressData) {
      _loading = true;
      update();
      try {
        if (fromAddress) {
          _position = Position(
            latitude: position!.target.latitude,
            longitude: position.target.longitude,
            timestamp: DateTime.now(),
            heading: 1,
            accuracy: 1,
            altitude: 1,
            altitudeAccuracy: 1,
            headingAccuracy: 1,
            speedAccuracy: 1,
            speed: 1,
          );
        } else {
          _pickPosition = Position(
            latitude: position!.target.latitude,
            longitude: position.target.longitude,
            timestamp: DateTime.now(),
            heading: 1,
            accuracy: 1,
            altitude: 1,
            altitudeAccuracy: 1,
            headingAccuracy: 1,
            speedAccuracy: 1,
            speed: 1,
          );
        }

        ZoneResponseModel responseModel = await getZone(
            position.target.latitude.toString(),
            position.target.longitude.toString(),
            true);

        _buttonDisabled = !responseModel.isSuccess;

        if (_changeAddress) {
          String addressFromGeocode = await getAddressFromGeocode(
              LatLng(position.target.latitude, position.target.longitude));
          fromAddress
              ? _address = addressFromGeocode
              : _pickAddress = addressFromGeocode;
        } else {
          _changeAddress = true;
        }
      } catch (_) {}
      _loading = false;
      update();
    } else {
      _updateAddAddressData = true;
    }
  }

  Future<bool> saveUserAddress(AddressModel address) async {
    String userAddress = jsonEncode(address.toJson());
    return await locationRepository.saveUserAddress(
        userAddress, address.zoneIds, address.latitude, address.longitude);
  }

  Future<AddressModel?> getUserAddress() async {
    AddressModel? addressModel;
    try {
      String? addressString = await locationRepository.getUserAddress();
      if (addressString != null && addressString.isNotEmpty) {
        addressModel = AddressModel.fromJson(jsonDecode(addressString));
      }
    } catch (_) {}
    return addressModel;
  }

  void setAddressTypeIndex(int index, {bool notify = true}) {
    _addressTypeIndex = index;
    if (notify) {
      update();
    }
  }

  Future<Position> setLocation(String? placeID, String? address,
      GoogleMapController? mapController) async {
    _loading = true;
    update();

    LatLng latLng = const LatLng(0, 0);
    final response = await locationRepository.getPlaceDetails(placeID);

    if (response.statusCode == 200) {
      try {
        final body = jsonDecode(response.body);
        if (body['status'] == 'OK' && body['result'] != null) {
          final geometry = body['result']['geometry'];
          final location = geometry['location'];
          latLng = LatLng(
              double.tryParse(location['lat']?.toString() ?? '0') ?? 0,
              double.tryParse(location['lng']?.toString() ?? '0') ?? 0);
        }
      } catch (e) {
        // Handle JSON decode error
      }
    }

    _pickPosition = Position(
      latitude: latLng.latitude,
      longitude: latLng.longitude,
      timestamp: DateTime.now(),
      accuracy: 1,
      altitude: 1,
      altitudeAccuracy: 1,
      heading: 1,
      headingAccuracy: 1,
      speed: 1,
      speedAccuracy: 1,
    );

    _pickAddress = address;
    _changeAddress = false;

    if (mapController != null) {
      mapController.animateCamera(CameraUpdate.newCameraPosition(
          CameraPosition(target: latLng, zoom: 16)));
    }
    _loading = false;
    update();
    return _pickPosition;
  }

  void disableButton() {
    _buttonDisabled = true;
    _inZone = true;
    update();
  }

  void setAddAddressData() {
    _position = _pickPosition;
    _address = _pickAddress;
    _updateAddAddressData = false;
    update();
  }

  void setUpdateAddress(AddressModel address) {
    _position = Position(
      latitude: double.parse(address.latitude!),
      longitude: double.parse(address.longitude!),
      timestamp: DateTime.now(),
      altitude: 1,
      altitudeAccuracy: 1,
      headingAccuracy: 1,
      heading: 1,
      speed: 1,
      speedAccuracy: 1,
      floor: 1,
      accuracy: 1,
    );
    _address = address.address;
    _addressTypeIndex = _addressTypeList.indexOf(address.addressType);
  }

  void setPickData() {
    _pickPosition = _position;
    _pickAddress = _address;
  }

  void setMapController(GoogleMapController mapController) {
    _mapController = mapController;
  }

  Future<String> getAddressFromGeocode(LatLng latLng) async {
    final response = await locationRepository.getAddressFromGeocode(latLng);
    String address = 'Unknown Location Found';
    if (response.statusCode == 200) {
      try {
        final body = jsonDecode(response.body);
        if (body['status'] == 'OK') {
          final results = body['results'];
          if (results != null && results is List && results.isNotEmpty) {
            address = results[0]['formatted_address'].toString();
          }
        } else if (body['status'] != 'ZERO_RESULTS') {
          final errorMessage =
              body['error_message']?.toString() ?? 'Failed to get address';
          Get.snackbar('Error', errorMessage);
        }
      } catch (e) {
        // Handle JSON decode error
      }
    }
    return address;
  }

  Future<List<PredictionModel>> searchLocation(
      BuildContext context, String text) async {
    if (text.isNotEmpty) {
      final response = await locationRepository.searchLocation(text);
      if (response.statusCode == 200) {
        try {
          final body = jsonDecode(response.body);
          if (body['status'] == 'OK') {
            _predictionList = [];
            final predictions = body['predictions'];
            if (predictions != null && predictions is List) {
              for (var prediction in predictions) {
                _predictionList.add(PredictionModel.fromJson(prediction));
              }
            }
          } else {
            final errorMessage = body['error_message']?.toString() ??
                'Failed to search location';
            Get.snackbar('Error', errorMessage);
          }
        } catch (e) {
          // Handle JSON decode error
        }
      }
    }
    return _predictionList;
  }

  void setPlaceMark(String address) {
    _address = address;
  }

  void checkPermission(Function onTap) async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      Get.snackbar(
          'Permission Denied', 'You have to allow location permission');
    } else if (permission == LocationPermission.deniedForever) {
      Get.dialog(
        AlertDialog(
          title: const Text('Location Permission'),
          content: const Text(
              'Location permission is permanently denied. Please enable it from app settings.'),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Geolocator.openAppSettings(),
              child: const Text('Settings'),
            ),
          ],
        ),
      );
    } else {
      onTap();
    }
  }

  Future<bool> checkLocationActive() async {
    bool isActiveLocation = await Geolocator.isLocationServiceEnabled();

    if (isActiveLocation) {
      AddressModel currentAddress = await getCurrentLocation(true);
      AddressModel? selectedAddress = await getUserAddress();

      if (selectedAddress == null) {
        return false;
      }

      double distance = Geolocator.distanceBetween(
            double.parse(currentAddress.latitude!),
            double.parse(currentAddress.longitude!),
            double.parse(selectedAddress.latitude!),
            double.parse(selectedAddress.longitude!),
          ) /
          1000;

      if (distance > 1) {
        return true;
      } else {
        return false;
      }
    } else {
      return false;
    }
  }
}
