import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http_parser/http_parser.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/loading_widget.dart';

class PharmacySettingsScreen extends ConsumerStatefulWidget {
  const PharmacySettingsScreen({super.key});

  @override
  ConsumerState<PharmacySettingsScreen> createState() =>
      _PharmacySettingsScreenState();
}

class _PharmacySettingsScreenState
    extends ConsumerState<PharmacySettingsScreen> {
  final Dio _dio = ApiClient.instance;
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _profile;

  final _nameCtrl = TextEditingController();
  final _licenseCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _radiusCtrl = TextEditingController();
  final _feeCtrl = TextEditingController();
  bool _acceptsInsurance = false;
  String? _logoUrl;
  bool _uploadingLogo = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await _dio.get('/pharmacy-profile/profile/');
      final results = response.data['results'] as List<dynamic>?;
      if (results != null && results.isNotEmpty) {
        _profile = results.first as Map<String, dynamic>;
        _populateFields();
      }
      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  void _populateFields() {
    final p = _profile!;
    _nameCtrl.text = p['name'] ?? '';
    _licenseCtrl.text = p['license_number'] ?? '';
    _descCtrl.text = p['description'] ?? '';
    _radiusCtrl.text = '${p['delivery_radius_km'] ?? 0}';
    _feeCtrl.text = '${p['delivery_fee'] ?? 0}';
    _acceptsInsurance = p['accepts_insurance'] ?? false;
    _logoUrl = p['logo_url'] as String?;
  }

  Future<void> _saveProfile() async {
    final data = {
      'name': _nameCtrl.text.trim(),
      'license_number': _licenseCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'delivery_radius_km': double.tryParse(_radiusCtrl.text) ?? 0,
      'delivery_fee': double.tryParse(_feeCtrl.text) ?? 0,
      'accepts_insurance': _acceptsInsurance,
    };

    try {
      if (_profile != null && _profile!['id'] != null) {
        await _dio.patch('/pharmacy-profile/profile/${_profile!['id']}/', data: data);
      } else {
        final response = await _dio.post('/pharmacy-profile/profile/', data: data);
        _profile = response.data;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Settings saved')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _uploadLogo() async {
    if (_profile == null || _profile!['id'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Save the profile first before uploading a logo.')));
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null) return;

    setState(() => _uploadingLogo = true);
    try {
      final ext = (file.extension ?? 'jpg').toLowerCase();
      final mime = ext == 'png' ? 'png' : ext == 'gif' ? 'gif' : 'jpeg';
      final formData = FormData.fromMap({
        'logo': MultipartFile.fromBytes(
          file.bytes!,
          filename: file.name,
          contentType: MediaType('image', mime),
        ),
      });
      final response = await _dio.post(
        '/pharmacy-profile/profile/${_profile!['id']}/upload-logo/',
        data: formData,
      );
      final updated = response.data as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _profile = updated;
          _logoUrl = updated['logo_url'] as String?;
        });
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Logo uploaded successfully')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploadingLogo = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _licenseCtrl.dispose();
    _descCtrl.dispose();
    _radiusCtrl.dispose();
    _feeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: LoadingWidget());
    if (_error != null) return Center(child: Text('Error: $_error'));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pharmacy Settings',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          // ── Logo ──────────────────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Pharmacy Logo',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      // Logo preview
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _logoUrl != null
                            ? Image.network(
                                _logoUrl!,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.broken_image_outlined,
                                  color: AppColors.border,
                                  size: 36,
                                ),
                              )
                            : Icon(
                                Icons.local_pharmacy_outlined,
                                color: AppColors.border,
                                size: 36,
                              ),
                      ),
                      const SizedBox(width: 20),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _uploadingLogo
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2.5),
                                )
                              : FilledButton.icon(
                                  onPressed: _uploadLogo,
                                  icon: const Icon(Icons.upload_rounded, size: 18),
                                  label: Text(_logoUrl != null ? 'Replace Logo' : 'Upload Logo'),
                                ),
                          const SizedBox(height: 6),
                          Text(
                            'PNG, JPG or GIF recommended.\n96×96 px or larger.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('General Information',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Pharmacy Name',
                        border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _licenseCtrl,
                    decoration: const InputDecoration(
                        labelText: 'License Number',
                        border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder()),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Delivery Settings',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _radiusCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Delivery Radius (km)',
                              border: OutlineInputBorder()),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _feeCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Delivery Fee (KSh)',
                              border: OutlineInputBorder()),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Insurance',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Accepts Insurance'),
                    value: _acceptsInsurance,
                    onChanged: (v) =>
                        setState(() => _acceptsInsurance = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _saveProfile,
              icon: const Icon(Icons.save),
              label: const Text('Save Settings'),
            ),
          ),
        ],
      ),
    );
  }
}
