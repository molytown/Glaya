import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../shared/services/api_service.dart';
import '../../../../shared/services/config_service.dart';
import '../../../../shared/theme/colors.dart';
import '../../auth/presentation/providers/auth_notifier.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _nameController = TextEditingController();
  Map<String, dynamic>? _user;
  bool _isLoading = true;
  bool _isSaving = false;
  XFile? _pickedPhoto;
  Uint8List? _pickedPhotoBytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final resp = await ApiService.dio.get('/users/me');
      final data = resp.data['data'] as Map<String, dynamic>;
      setState(() {
        _user = data;
        _nameController.text = data['name'] as String? ?? '';
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _pickedPhoto = picked;
        _pickedPhotoBytes = bytes;
      });
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      if (_pickedPhoto != null) {
        // Upload photo as multipart
        final formData = await _buildFormData(name);
        await ApiService.dio.put('/users/me',
            data: formData, options: ApiService.multipartOptions());
      } else {
        await ApiService.dio.put('/users/me', data: {'name': name});
      }
      // Update local state without triggering auth refresh
      setState(() {
        _user?['name'] = name;
        if (_pickedPhotoBytes != null) {
          _user?['photoUrl'] =
              null; // Clear old URL, new one will be from server
        }
        _pickedPhoto = null;
        _pickedPhotoBytes = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<dynamic> _buildFormData(String name) async {
    return ApiService.buildMultipart(
      fields: {'name': name},
      filePath: _pickedPhoto?.path,
      fileBytes: _pickedPhotoBytes,
      fileName: _pickedPhoto?.name,
      fileField: 'photo',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final photoUrl =
        _user?['photoUrl'] as String? ?? _user?['photo_url'] as String?;
    final initials =
        (_user?['name'] as String? ?? 'U').substring(0, 1).toUpperCase();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: GlayaColors.berry,
        foregroundColor: Colors.white,
        title: const Text('Settings',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Save',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Avatar
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 52,
                    backgroundColor: GlayaColors.berry.withValues(alpha: 0.15),
                    backgroundImage: _pickedPhotoBytes != null
                        ? MemoryImage(_pickedPhotoBytes!)
                            as ImageProvider<Object>
                        : (photoUrl != null
                            ? NetworkImage(
                                ConfigService().replaceLocalhost(photoUrl))
                            : null),
                    child: (_pickedPhotoBytes == null && photoUrl == null)
                        ? Text(initials,
                            style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: GlayaColors.berry))
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _pickPhoto,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: GlayaColors.berry,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Name & phone are edited on the Edit Profile screen —
            // intentionally not duplicated here.
            const SizedBox(height: 4),

            const Divider(),
            const SizedBox(height: 8),
            const Text('Account',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF000000))),
            const SizedBox(height: 12),

            _buildTile(Icons.notifications_outlined, 'Notifications',
                () => context.push('/notifications')),
            _buildTile(Icons.card_giftcard_outlined, 'Loyalty & Rewards',
                () => context.push('/loyalty')),
            _buildTile(Icons.account_balance_wallet_outlined, 'Wallet',
                () => context.push('/wallet')),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            const Text('Legal',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF000000))),
            const SizedBox(height: 12),
            _buildTile(Icons.description_outlined, 'Terms of Service',
                () => context.push('/cms/terms-of-service')),
            _buildTile(Icons.privacy_tip_outlined, 'Privacy Policy',
                () => context.push('/cms/privacy-policy')),
            _buildTile(Icons.info_outline, 'About Glaya',
                () => context.push('/cms/about-us')),
            const SizedBox(height: 8),
            // Delete Account — required for App Store compliance
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading:
                  const Icon(Icons.delete_forever_outlined, color: Colors.red),
              title: const Text('Delete Account',
                  style: TextStyle(
                      color: Colors.red, fontWeight: FontWeight.w600)),
              subtitle: const Text(
                'Permanently delete your account and data',
                style: TextStyle(fontSize: 12, color: Color(0xFF000000)),
              ),
              onTap: _deleteAccount,
            ),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Log Out',
                  style: TextStyle(
                      color: Colors.red, fontWeight: FontWeight.w600)),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Log Out'),
                    content: const Text('Are you sure you want to log out?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('Cancel')),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red),
                        child: const Text('Log Out',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
                if (confirm == true && mounted) {
                  try {
                    await ApiService.dio.post('/auth/logout');
                  } catch (_) {}
                  ref.read(authNotifierProvider.notifier).logout();
                  if (mounted) context.go('/login');
                }
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text(
          'This will permanently delete your Glaya account and personal data. '
          'This action cannot be undone.\n\n'
          'Note: Booking, payment and review records are retained in anonymized '
          'form for legal and financial purposes.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete My Account',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await ApiService.dio.delete('/users/me');
      if (!mounted) return;
      Navigator.of(context).pop(); // dismiss spinner
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your account has been deleted')),
      );
      // Clear local session and return to login
      try {
        await ApiService.dio.post('/auth/logout');
      } catch (_) {}
      ref.read(authNotifierProvider.notifier).logout();
      if (mounted) context.go('/login');
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // dismiss spinner
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete account: $e')),
      );
    }
  }

  Widget _buildTile(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: GlayaColors.berry),
      title: Text(label,
          style: const TextStyle(fontSize: 15, color: Color(0xFF000000))),
      trailing: const Icon(Icons.chevron_right, color: Color(0xFF000000)),
      onTap: onTap,
    );
  }
}
