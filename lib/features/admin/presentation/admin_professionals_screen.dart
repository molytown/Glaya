import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/services/api_service.dart';
import '../../../../shared/services/config_service.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/text_styles.dart';

class AdminProfessionalsScreen extends ConsumerStatefulWidget {
  const AdminProfessionalsScreen({super.key});

  @override
  ConsumerState<AdminProfessionalsScreen> createState() => _AdminProfessionalsScreenState();
}

class _AdminProfessionalsScreenState extends ConsumerState<AdminProfessionalsScreen> {
  List<Map<String, dynamic>> _professionals = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _filterStatus = 'all';

  @override
  void initState() {
    super.initState();
    _loadProfessionals();
  }

  Future<void> _loadProfessionals() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.dio.get('/admin/professionals');
      if (mounted) {
        setState(() {
          _professionals = (response.data['data'] as List).cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load professionals: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _deleteProfessional(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Professional'),
        content: const Text('Are you sure you want to delete this professional?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: GlayaColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService.dio.delete('/admin/professionals/$id');
        await _loadProfessionals();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Professional deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete professional: ${e.toString()}')),
          );
        }
      }
    }
  }

  List<Map<String, dynamic>> get _filteredProfessionals {
    var filtered = _professionals;

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((p) {
        final name = (p['user']?['name'] as String? ?? '').toLowerCase();
        final category = (p['category'] as String? ?? '').toLowerCase();
        return name.contains(_searchQuery.toLowerCase()) || category.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    if (_filterStatus != 'all') {
      filtered = filtered.where((p) => p['verificationStatus'] == _filterStatus).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Professionals'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProfessionals,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSearchAndFilter(),
                Expanded(
                  child: _filteredProfessionals.isEmpty
                      ? const Center(child: Text('No professionals found'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredProfessionals.length,
                          itemBuilder: (context, index) {
                            final pro = _filteredProfessionals[index];
                            return _buildProfessionalCard(pro);
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddProfessionalDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Professional'),
        backgroundColor: GlayaColors.berry,
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Search professionals...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('All', 'all'),
                _filterChip('Pending', 'pending'),
                _filterChip('Approved', 'approved'),
                _filterChip('Rejected', 'rejected'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final selected = _filterStatus == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _filterStatus = value),
        selectedColor: GlayaColors.berry.withOpacity(0.2),
        checkmarkColor: GlayaColors.berry,
      ),
    );
  }

  Widget _buildProfessionalCard(Map<String, dynamic> pro) {
    final name = pro['user']?['name'] as String? ?? 'Unknown';
    final category = pro['category'] as String? ?? 'Unknown';
    final status = pro['verificationStatus'] as String? ?? 'pending';
    final statusColor = _getStatusColor(status);
    final photoUrl = pro['user']?['photoUrl'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: photoUrl != null ? NetworkImage(ConfigService().replaceLocalhost(photoUrl)) : null,
          child: photoUrl == null ? Text(name[0].toUpperCase()) : null,
        ),
        title: Text(name, style: GlayaTextStyles.titleMedium()),
        subtitle: Text(category),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              onSelected: (action) {
                if (action == 'delete') {
                  _deleteProfessional(pro['id'] as String);
                } else if (action == 'view') {
                  context.push('/professional/${pro['id']}');
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'view', child: Text('View Profile')),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return GlayaColors.success;
      case 'rejected':
        return GlayaColors.error;
      case 'pending':
      default:
        return GlayaColors.warning;
    }
  }

  Future<void> _showAddProfessionalDialog() async {
    await showDialog(
      context: context,
      builder: (_) => const AddProfessionalDialog(),
    );
    await _loadProfessionals();
  }
}

class AddProfessionalDialog extends ConsumerStatefulWidget {
  const AddProfessionalDialog({super.key});

  @override
  ConsumerState<AddProfessionalDialog> createState() => _AddProfessionalDialogState();
}

class _AddProfessionalDialogState extends ConsumerState<AddProfessionalDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _categoryController = TextEditingController();
  final _bioController = TextEditingController();
  String _selectedCategory = 'hair';
  bool _isLoading = false;

  final List<String> _categories = [
    'hair',
    'nails',
    'barber',
    'spa',
    'makeup',
    'lashes',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _categoryController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      // Use admin endpoint to create professional directly
      await ApiService.dio.post('/admin/professionals', data: {
        'name': _nameController.text,
        'email': _emailController.text,
        'phone': _phoneController.text,
        'category': _selectedCategory,
        'bio': _bioController.text,
        'verificationStatus': 'approved', // Auto-approve for admin-created professionals
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Professional added successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add professional: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Professional'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: _categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category.toUpperCase()),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedCategory = value!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bioController,
                decoration: const InputDecoration(
                  labelText: 'Bio',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: GlayaColors.berry),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add Professional'),
        ),
      ],
    );
  }
}
