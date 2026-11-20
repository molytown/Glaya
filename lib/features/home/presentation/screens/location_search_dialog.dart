import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import '../../controller/location_controller.dart';
import '../../models/prediction_model.dart';

class LocationSearchDialog extends StatefulWidget {
  final GoogleMapController? mapController;

  const LocationSearchDialog({super.key, this.mapController});

  @override
  State<LocationSearchDialog> createState() => _LocationSearchDialogState();
}

class _LocationSearchDialogState extends State<LocationSearchDialog> {
  final TextEditingController _controller = TextEditingController();
  List<PredictionModel> _predictionList = [];
  Timer? _debounce;
  String? _currentLocationText;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onSearchChanged);
    _loadCurrentLocation();
  }

  Future<void> _loadCurrentLocation() async {
    // Reverted - only apply location autofill to signup map, not set address map
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _searchLocation(_controller.text);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _searchLocation(String text) {
    if (text.isNotEmpty) {
      Get.find<LocationController>()
          .searchLocation(context, text)
          .then((predictions) {
        setState(() {
          _predictionList = predictions;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        brightness: Brightness.light,
        textTheme: Theme.of(context).textTheme.copyWith(
              bodyLarge: const TextStyle(color: Colors.black),
              bodyMedium: const TextStyle(color: Colors.black),
              titleMedium: const TextStyle(color: Colors.black),
            ),
        inputDecorationTheme: const InputDecorationTheme(
          hintStyle: TextStyle(color: Colors.grey),
        ),
      ),
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.search, color: Color(0xFFD6006E)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: const TextStyle(
                        color: Color(0xFFD6006E),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      cursorColor: const Color(0xFFD6006E),
                      decoration: InputDecoration(
                        hintText: _currentLocationText ?? 'Search location...',
                        border: InputBorder.none,
                        hintStyle: TextStyle(
                          color: _currentLocationText != null
                              ? const Color(0xFFD6006E)
                              : Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                      autofocus: true,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _controller.clear();
                      setState(() {
                        _predictionList = [];
                      });
                    },
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 10),
              SizedBox(
                height: 200,
                child: _predictionList.isEmpty
                    ? const Center(
                        child: Text(
                          'Search for a location',
                          style: TextStyle(color: Colors.black),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _predictionList.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            leading: const Icon(Icons.location_on,
                                color: Color(0xFFD6006E)),
                            title: Text(
                              _predictionList[index].description ?? '',
                              style: const TextStyle(color: Colors.black),
                            ),
                            onTap: () {
                              Get.find<LocationController>()
                                  .setLocation(
                                _predictionList[index].placeId,
                                _predictionList[index].description,
                                widget.mapController,
                              )
                                  .then((position) {
                                Get.back();
                              });
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
