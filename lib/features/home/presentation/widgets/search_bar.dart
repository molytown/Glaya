import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/services/api_service.dart';
import '../../../../shared/services/config_service.dart';
import '../../../../shared/theme/colors.dart';

class HomeSearchBar extends StatefulWidget {
  final TextEditingController controller;

  const HomeSearchBar({super.key, required this.controller});

  @override
  State<HomeSearchBar> createState() => _HomeSearchBarState();
}

class _HomeSearchBarState extends State<HomeSearchBar> {
  bool _showDropdown = false;
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;
  List<Map<String, dynamic>> _proResults = [];
  List<Map<String, dynamic>> _serviceResults = [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() {
        _showDropdown =
            _focusNode.hasFocus && widget.controller.text.trim().length >= 2;
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final q = value.trim();
    setState(() {
      _showDropdown = _focusNode.hasFocus && q.length >= 2;
      if (q.length < 2) {
        _proResults = [];
        _serviceResults = [];
        _searching = false;
      }
    });
    if (q.length < 2) return;
    _debounce =
        Timer(const Duration(milliseconds: 350), () => _fetchSuggestions(q));
  }

  Future<void> _fetchSuggestions(String q) async {
    setState(() => _searching = true);
    try {
      final resp =
          await ApiService.dio.get('/search', queryParameters: {'q': q});
      final data = resp.data['data'] as Map<String, dynamic>? ?? {};
      if (!mounted) return;
      setState(() {
        _proResults = ((data['professionals'] as List<dynamic>?) ?? [])
            .whereType<Map<String, dynamic>>()
            .take(4)
            .toList();
        _serviceResults = ((data['services'] as List<dynamic>?) ?? [])
            .whereType<Map<String, dynamic>>()
            .take(4)
            .toList();
        _searching = false;
      });
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _handleSearch() {
    final query = widget.controller.text.trim();
    if (query.isNotEmpty) {
      context.push('/search?q=${Uri.encodeComponent(query)}');
      _focusNode.unfocus();
    }
  }

  void _handleFilter() {
    context.push('/search?filter=true');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: GlayaColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(
        children: [
          Container(
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFEEEEEE)),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _handleSearch,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: GlayaColors.berry,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Search',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.search,
                          color: Colors.white,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    textInputAction: TextInputAction.search,
                    style:
                        const TextStyle(fontSize: 14, color: Color(0xFF1A1A1A)),
                    onSubmitted: (_) => _handleSearch(),
                    onChanged: _onQueryChanged,
                    decoration: const InputDecoration(
                      hintText: 'Search services, professionals...',
                      hintStyle:
                          TextStyle(color: Color(0xFF9E9E9E), fontSize: 14),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _handleFilter,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: GlayaColors.vibrantPink.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: GlayaColors.vibrantPink.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.filter_list,
                          color: GlayaColors.berry,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Filter',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: GlayaColors.berry,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_showDropdown)
            Container(
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _SearchDropdown(
                professionals: _proResults,
                services: _serviceResults,
                loading: _searching,
              ),
            ),
        ],
      ),
    );
  }
}

class _SearchDropdown extends StatelessWidget {
  final List<Map<String, dynamic>> professionals;
  final List<Map<String, dynamic>> services;
  final bool loading;

  const _SearchDropdown({
    required this.professionals,
    required this.services,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    if (loading && professionals.isEmpty && services.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (professionals.isEmpty && services.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No results found',
          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (professionals.isNotEmpty)
          _DropdownSection(
            title: 'Professionals',
            children: professionals.map((p) {
              final user = p['user'] as Map<String, dynamic>?;
              final name = user?['name'] as String? ?? 'Unknown';
              final category = p['category'] as String? ?? '';
              return _DropdownItem(
                name: name,
                category: category,
                icon: Icons.person,
                imageUrl: user?['photoUrl'] as String?,
                onTap: () {
                  FocusScope.of(context).unfocus();
                  context.push('/professional/${p['id']}');
                },
              );
            }).toList(),
          ),
        if (services.isNotEmpty)
          _DropdownSection(
            title: 'Services',
            children: services.map((s) {
              final pro = s['professional'] as Map<String, dynamic>?;
              final proUser = pro?['user'] as Map<String, dynamic>?;
              final price = (s['price'] as num?)?.toStringAsFixed(0) ?? '0';
              final currency = s['currency'] as String? ?? 'USD';
              final symbol = currency == 'XAF' ? 'FCFA' : currency;
              return _DropdownItem(
                name: s['name'] as String? ?? '',
                category: '${proUser?['name'] ?? 'Unknown'}  •  $symbol $price',
                icon: Icons.content_cut,
                imageUrl: s['imageUrl'] as String? ?? s['image_url'] as String?,
                onTap: () {
                  FocusScope.of(context).unfocus();
                  final proId = pro?['id'];
                  if (proId != null) context.push('/professional/$proId');
                },
              );
            }).toList(),
          ),
      ],
    );
  }
}

class _DropdownSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _DropdownSection(
      {super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF9E9E9E),
            ),
          ),
        ),
        ...children,
      ],
    );
  }
}

class _DropdownItem extends StatelessWidget {
  final String name;
  final String category;
  final IconData icon;
  final String? imageUrl;
  final VoidCallback? onTap;

  const _DropdownItem({
    super.key,
    required this.name,
    required this.category,
    required this.icon,
    this.imageUrl,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedImage =
        imageUrl != null ? ConfigService().replaceLocalhost(imageUrl!) : null;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: resolvedImage != null
                  ? Image.network(
                      resolvedImage,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _iconBox(),
                    )
                  : _iconBox(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  Text(
                    category,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9E9E9E),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconBox() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: GlayaColors.vibrantPink.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: GlayaColors.berry, size: 20),
    );
  }
}
