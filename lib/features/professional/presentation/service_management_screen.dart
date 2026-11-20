import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../../../../shared/services/api_service.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/text_styles.dart';
import '../../../../shared/widgets/bottom_nav.dart';
import '../../auth/presentation/providers/auth_notifier.dart';

class ServiceManagementScreen extends ConsumerStatefulWidget {
  const ServiceManagementScreen({super.key});

  @override
  ConsumerState<ServiceManagementScreen> createState() =>
      _ServiceManagementScreenState();
}

class _ServiceManagementScreenState
    extends ConsumerState<ServiceManagementScreen> {
  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;
  bool _isLoadingCategories = true;
  final ImagePicker _picker = ImagePicker();
  XFile? _pickedImage;
  Uint8List? _pickedImageBytes;
  bool _isUploadingImage = false;

  Future<void> _loadCategories() async {
    print('[DEBUG] _loadCategories called');
    try {
      final response = await ApiService.dio.get('/categories/public');
      print('[DEBUG] Categories response: ${response.data}');
      setState(() => _categories =
          (response.data['data'] as List).cast<Map<String, dynamic>>());
      print('[DEBUG] Loaded ${_categories.length} categories');
    } catch (e) {
      print('[DEBUG] Error loading categories: $e');
      // Fallback categories (no IDs since this is error case)
      setState(() => _categories = []);
    } finally {
      setState(() => _isLoadingCategories = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadServices();
    _loadCategories();
  }

  Future<void> _loadServices() async {
    print('[DEBUG] _loadServices called');
    try {
      print('[DEBUG] Fetching user profile');
      // Get professional profile first
      final meResponse = await ApiService.dio.get('/users/me');
      print('[DEBUG] User profile response: ${meResponse.data}');
      final professionalId =
          meResponse.data['data']?['professional']?['id'] as String?;
      print('[DEBUG] Professional ID: $professionalId');
      if (professionalId == null) {
        print('[DEBUG] No professional ID found');
        setState(() => _isLoading = false);
        return;
      }

      print('[DEBUG] Fetching services for professional: $professionalId');
      final response = await ApiService.dio.get('/services', queryParameters: {
        'professional_id': professionalId,
      });
      print('[DEBUG] Services response: ${response.data}');
      setState(() => _services =
          (response.data['data'] as List).cast<Map<String, dynamic>>());
      print('[DEBUG] Loaded ${_services.length} services');
    } catch (e) {
      print('[DEBUG] Error loading services: $e');
      if (e is DioException) {
        print('[DEBUG] Dio error response: ${e.response}');
        print('[DEBUG] Dio error type: ${e.type}');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load services: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteService(String id) async {
    try {
      await ApiService.dio.delete('/services/$id');
      await _loadServices();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    final pickedFile =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _pickedImage = pickedFile;
        _pickedImageBytes = bytes;
      });
    }
  }

  Future<String?> _uploadImage() async {
    print('[DEBUG] _uploadImage called');
    if (_pickedImage == null || _pickedImageBytes == null) {
      print('[DEBUG] No image picked');
      return null;
    }

    print('[DEBUG] Uploading image: ${_pickedImage!.name}');
    setState(() => _isUploadingImage = true);
    try {
      final formData = FormData.fromMap({
        'photo': MultipartFile.fromBytes(
          _pickedImageBytes!,
          filename: _pickedImage!.name,
        ),
      });
      print('[DEBUG] Sending image upload request to /users/me/photo');
      final response = await ApiService.dio.post(
        '/users/me/photo',
        data: formData,
        options: ApiService.multipartOptions(),
      );
      print('[DEBUG] Image upload response: ${response.data}');
      final photoUrl = response.data['data']['photoUrl'] as String?;
      print('[DEBUG] Uploaded photo URL: $photoUrl');
      return photoUrl;
    } catch (e) {
      print('[DEBUG] Image upload error: $e');
      if (e is DioException) {
        print('[DEBUG] Dio error response: ${e.response}');
        print('[DEBUG] Dio error type: ${e.type}');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload image: ${e.toString()}')),
        );
      }
      return null;
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Services'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddDialog(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _services.length,
              itemBuilder: (context, index) {
                final service = _services[index];
                return Card(
                  child: ListTile(
                    title: Text(service['name'] as String,
                        style: GlayaTextStyles.titleMedium()),
                    subtitle: Text(
                      '${service['price']} • ${service['durationMins'] ?? service['duration_mins']} min • ${service['locationType'] ?? service['location_type']}',
                      style: GlayaTextStyles.bodySmall(),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: GlayaColors.error),
                      onPressed: () => _deleteService(service['id'] as String),
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: user?.role == 'customer'
          ? null
          : GlayaBottomNav(
              currentIndex: 0,
              userRole: user?.role,
            ),
    );
  }

  void _showAddDialog() {
    // Check if categories are loaded
    if (_categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait for categories to load')),
      );
      return;
    }

    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final durationController = TextEditingController();
    final depositController = TextEditingController();
    String categoryId =
        _categories.isNotEmpty ? (_categories[0]['id']?.toString() ?? '') : '';
    String locationType = 'salon';

    // Reset image state
    setState(() {
      _pickedImage = null;
      _pickedImageBytes = null;
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Service'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Image upload field
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE0E0E0)),
                  ),
                  child: _pickedImageBytes != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.memory(
                            _pickedImageBytes!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: 120,
                            cacheWidth: 400,
                          ),
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined,
                                size: 32, color: Color(0xFF000000)),
                            SizedBox(height: 8),
                            Text('Tap to add service photo',
                                style: TextStyle(
                                    fontSize: 12, color: Color(0xFF000000))),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: categoryId.isEmpty ? null : categoryId,
                decoration: InputDecoration(
                  labelText: 'Category',
                  labelStyle: const TextStyle(color: Color(0xFF000000)),
                  hintStyle: const TextStyle(color: Color(0xFF000000)),
                  filled: true,
                  fillColor: const Color(0xFFFAFAFA),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
                ),
                items: _categories.map((cat) {
                  return DropdownMenuItem<String>(
                    value: cat['id']?.toString(),
                    child: Text(cat['name'] as String),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => categoryId = value ?? '');
                },
              ),
              const SizedBox(height: 16),
              TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                      labelText: 'Name',
                      labelStyle: const TextStyle(color: Color(0xFF000000)),
                      hintStyle: const TextStyle(color: Color(0xFF000000)),
                      filled: true,
                      fillColor: const Color(0xFFFAFAFA),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Color(0xFFE0E0E0))))),
              TextField(
                  controller: priceController,
                  decoration: InputDecoration(
                      labelText: 'Price',
                      labelStyle: const TextStyle(color: Color(0xFF000000)),
                      hintStyle: const TextStyle(color: Color(0xFF000000)),
                      filled: true,
                      fillColor: const Color(0xFFFAFAFA),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Color(0xFFE0E0E0)))),
                  keyboardType: TextInputType.number),
              TextField(
                  controller: durationController,
                  decoration: InputDecoration(
                      labelText: 'Duration (mins)',
                      labelStyle: const TextStyle(color: Color(0xFF000000)),
                      hintStyle: const TextStyle(color: Color(0xFF000000)),
                      filled: true,
                      fillColor: const Color(0xFFFAFAFA),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Color(0xFFE0E0E0)))),
                  keyboardType: TextInputType.number),
              TextField(
                  controller: depositController,
                  decoration: InputDecoration(
                      labelText: 'Deposit',
                      labelStyle: const TextStyle(color: Color(0xFF000000)),
                      hintStyle: const TextStyle(color: Color(0xFF000000)),
                      filled: true,
                      fillColor: const Color(0xFFFAFAFA),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Color(0xFFE0E0E0)))),
                  keyboardType: TextInputType.number),
              DropdownButtonFormField<String>(
                initialValue: locationType,
                decoration: InputDecoration(
                  labelText: 'Location Type',
                  labelStyle: const TextStyle(color: Color(0xFF000000)),
                  hintStyle: const TextStyle(color: Color(0xFF000000)),
                  filled: true,
                  fillColor: const Color(0xFFFAFAFA),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
                ),
                items: const [
                  DropdownMenuItem(value: 'salon', child: Text('Salon')),
                  DropdownMenuItem(value: 'home', child: Text('Home Service')),
                  DropdownMenuItem(value: 'both', child: Text('Both')),
                ],
                onChanged: (value) {
                  setState(() => locationType = value!);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              print('[DEBUG] Add service button pressed');
              // Upload image first if selected
              String? imageUrl;
              if (_pickedImage != null) {
                print('[DEBUG] Uploading service image');
                imageUrl = await _uploadImage();
                if (imageUrl == null) {
                  print('[DEBUG] Image upload failed, aborting');
                  return; // Upload failed
                }
              }

              try {
                print('[DEBUG] Creating service data');
                final serviceData = {
                  'name': nameController.text,
                  'categoryId': categoryId,
                  'price': double.parse(priceController.text),
                  'durationMins': int.parse(durationController.text),
                  'depositAmount': double.parse(depositController.text.isEmpty
                      ? '0'
                      : depositController.text),
                  'locationType': locationType,
                };
                if (imageUrl != null) {
                  serviceData['imageUrl'] = imageUrl;
                }
                print('[DEBUG] Service data: $serviceData');

                print('[DEBUG] Sending POST request to /services');
                await ApiService.dio.post('/services', data: serviceData);
                print('[DEBUG] Service created successfully');
                if (mounted) {
                  Navigator.pop(context);
                  await _loadServices();
                }
              } catch (e) {
                print('[DEBUG] Error adding service: $e');
                if (e is DioException) {
                  print('[DEBUG] Dio error response: ${e.response}');
                  print('[DEBUG] Dio error type: ${e.type}');
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to add: ${e.toString()}')),
                  );
                }
              }
            },
            child: _isUploadingImage
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Add'),
          ),
        ],
      ),
    );
  }
}
