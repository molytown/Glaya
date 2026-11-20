import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/services/api_service.dart';

class AddressEditor extends ConsumerStatefulWidget {
  final bool isProfessional;

  const AddressEditor({super.key, this.isProfessional = false});

  @override
  ConsumerState<AddressEditor> createState() => _AddressEditorState();
}

class _AddressEditorState extends ConsumerState<AddressEditor> {
  final _formKey = GlobalKey<FormState>();
  final _countryController = TextEditingController();
  final _stateController = TextEditingController();
  final _cityController = TextEditingController();
  final _neighborhoodController = TextEditingController();
  final _fullAddressController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();

  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentAddress();
  }

  @override
  void dispose() {
    _countryController.dispose();
    _stateController.dispose();
    _cityController.dispose();
    _neighborhoodController.dispose();
    _fullAddressController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentAddress() async {
    setState(() => _isLoading = true);
    try {
      // Fetch full user data from API to get address fields
      final endpoint =
          widget.isProfessional ? '/professionals/me' : '/users/me/profile';
      final response = await ApiService.dio.get(endpoint);
      final userData = response.data['data'] as Map<String, dynamic>;

      if (widget.isProfessional) {
        final pro = userData;
        _countryController.text = pro['country'] ?? '';
        _stateController.text = pro['state'] ?? '';
        _cityController.text = pro['city'] ?? '';
        _neighborhoodController.text = pro['neighborhood'] ?? '';
        if (pro['location'] != null) {
          _latitudeController.text = pro['location']['lat']?.toString() ?? '';
          _longitudeController.text = pro['location']['lng']?.toString() ?? '';
        }
      } else {
        _countryController.text = userData['addressCountry'] ?? '';
        _stateController.text = userData['addressState'] ?? '';
        _cityController.text = userData['addressCity'] ?? '';
        _neighborhoodController.text = userData['addressNeighborhood'] ?? '';
        _fullAddressController.text = userData['fullAddress'] ?? '';
        _latitudeController.text = userData['latitude']?.toString() ?? '';
        _longitudeController.text = userData['longitude']?.toString() ?? '';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load address: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final payload = widget.isProfessional
          ? {
              'country': _countryController.text.trim(),
              'state': _stateController.text.trim(),
              'city': _cityController.text.trim(),
              'neighborhood': _neighborhoodController.text.trim(),
              if (_latitudeController.text.isNotEmpty &&
                  _longitudeController.text.isNotEmpty)
                'location': {
                  'lat': double.parse(_latitudeController.text),
                  'lng': double.parse(_longitudeController.text),
                },
            }
          : {
              'addressCountry': _countryController.text.trim(),
              'addressState': _stateController.text.trim(),
              'addressCity': _cityController.text.trim(),
              'addressNeighborhood': _neighborhoodController.text.trim(),
              'fullAddress': _fullAddressController.text.trim(),
              if (_latitudeController.text.isNotEmpty)
                'latitude': double.parse(_latitudeController.text),
              if (_longitudeController.text.isNotEmpty)
                'longitude': double.parse(_longitudeController.text),
            };

      final endpoint =
          widget.isProfessional ? '/professionals/me' : '/users/me/profile';

      await ApiService.dio.put(endpoint, data: payload);

      // Reload address data after save
      await _loadCurrentAddress();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Address updated successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update address: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Address'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _saveAddress,
              child: const Text('Save'),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Location Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _countryController,
                      decoration: const InputDecoration(
                        labelText: 'Country',
                        hintText: 'Enter country',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _stateController,
                      decoration: const InputDecoration(
                        labelText: 'State',
                        hintText: 'Enter state',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _cityController,
                      decoration: const InputDecoration(
                        labelText: 'City',
                        hintText: 'Enter city',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _neighborhoodController,
                      decoration: const InputDecoration(
                        labelText: 'Neighborhood',
                        hintText: 'Enter neighborhood',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    if (!widget.isProfessional) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _fullAddressController,
                        decoration: const InputDecoration(
                          labelText: 'Full Address',
                          hintText: 'Enter full address',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    ],
                    const SizedBox(height: 24),
                    const Text(
                      'Coordinates (Optional)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _latitudeController,
                            decoration: const InputDecoration(
                              labelText: 'Latitude',
                              hintText: 'e.g. 6.5244',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true, signed: true),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _longitudeController,
                            decoration: const InputDecoration(
                              labelText: 'Longitude',
                              hintText: 'e.g. 3.3792',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true, signed: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Note: Coordinates help us show you nearby professionals or customers.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
