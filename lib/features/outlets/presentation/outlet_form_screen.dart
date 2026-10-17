import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../domain/outlet_models.dart';
import 'outlets_provider.dart';

class OutletFormScreen extends ConsumerStatefulWidget {
  final String? outletId;

  const OutletFormScreen({super.key, this.outletId});

  @override
  ConsumerState<OutletFormScreen> createState() => _OutletFormScreenState();
}

class _OutletFormScreenState extends ConsumerState<OutletFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  String _selectedTimezone = 'Asia/Jakarta';
  bool _isActive = true;

  final List<String> _timezones = [
    'Asia/Jakarta',
    'Asia/Makassar',
    'Asia/Jayapura',
    'Europe/London',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Prefill edit dijadwalkan setelah frame pertama (aturan E26:
    // tanpa side-effect sinkron di build). Data susulan ditangani
    // ref.listen di build.
    if (widget.outletId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(outletDetailProvider(widget.outletId!)).whenData(_fillForm);
      });
    }
  }

  bool _isInit = false;

  void _fillForm(OutletModel outlet) {
    if (_isInit || !mounted) return;
    _isInit = true;
    setState(() {
      _nameController.text = outlet.name;
      _addressController.text = outlet.address;
      _latController.text = outlet.latitude.toString();
      _lngController.text = outlet.longitude.toString();
      _selectedTimezone = outlet.timezone;
      _isActive = outlet.isActive;
    });
  }

  void _applyCityPreset(String city, double lat, double lng, String tz) {
    setState(() {
      _latController.text = lat.toString();
      _lngController.text = lng.toString();
      _selectedTimezone = tz;
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final address = _addressController.text.trim();
    final lat = double.tryParse(_latController.text.trim()) ?? 0.0;
    final lng = double.tryParse(_lngController.text.trim()) ?? 0.0;

    bool success;
    if (widget.outletId == null) {
      success = await ref.read(outletMutationProvider.notifier).createOutlet(
            name: name,
            address: address,
            latitude: lat,
            longitude: lng,
            timezone: _selectedTimezone,
          );
    } else {
      success = await ref.read(outletMutationProvider.notifier).updateOutlet(
            widget.outletId!,
            name: name,
            address: address,
            latitude: lat,
            longitude: lng,
            timezone: _selectedTimezone,
            isActive: _isActive,
          );
    }

    if (!mounted) return;

    if (success) {
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.outletId == null
                ? 'Outlet baru berhasil ditambahkan.'
                : 'Informasi outlet berhasil diperbarui.',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      final err = ref.read(outletMutationProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan: $err', maxLines: 3, overflow: TextOverflow.ellipsis),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.outletId != null;
    final mutationState = ref.watch(outletMutationProvider);

    // Data yang tiba belakangan (FutureProvider) didengar di sini tanpa
    // memutasi state sinkron di build (aturan E26): whenData + guard _isInit.
    if (isEditing) {
      ref.listen(outletDetailProvider(widget.outletId!), (prev, next) {
        next.whenData(_fillForm);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? 'Edit Informasi Cabang' : 'Tambah Cabang Baru',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppTextField(
              controller: _nameController,
              labelText: 'Nama Cabang / Outlet *',
              hintText: 'Misal: ARUS Surabaya Tunjungan',
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Nama outlet wajib diisi';
                return null;
              },
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _addressController,
              maxLines: 2,
              labelText: 'Alamat Lengkap *',
              hintText: 'Jl. Pemuda No. 10, Surabaya',
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Alamat outlet wajib diisi';
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _latController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    labelText: 'Latitude *',
                    hintText: '-7.2612',
                    validator: (val) {
                      if (val == null || double.tryParse(val) == null) {
                        return 'Latitude tidak valid';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppTextField(
                    controller: _lngController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    labelText: 'Longitude *',
                    hintText: '112.7388',
                    validator: (val) {
                      if (val == null || double.tryParse(val) == null) {
                        return 'Longitude tidak valid';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Preset Koordinat Cepat:',
              style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ActionChip(
                    label: const Text('Jakarta'),
                    onPressed: () => _applyCityPreset('Jakarta', -6.2088, 106.8456, 'Asia/Jakarta'),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    label: const Text('Jogja'),
                    onPressed: () => _applyCityPreset('Jogja', -7.7828, 110.3670, 'Asia/Jakarta'),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    label: const Text('Bali'),
                    onPressed: () => _applyCityPreset('Bali', -8.6705, 115.2126, 'Asia/Makassar'),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    label: const Text('London'),
                    onPressed: () => _applyCityPreset('London', 51.5074, -0.1278, 'Europe/London'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppDropdown<String>(
              value: _selectedTimezone,
              items: _timezones.map((tz) {
                return DropdownMenuItem(value: tz, child: Text(tz, maxLines: 1, overflow: TextOverflow.ellipsis));
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedTimezone = val);
              },
              labelText: 'Zona Waktu Cabang',
            ),
            if (isEditing) ...[
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Status Operasional Aktif', maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: const Text('Cabang aktif dapat bertransaksi dan menerima pesanan kasir', maxLines: 2, overflow: TextOverflow.ellipsis),
                value: _isActive,
                onChanged: (val) => setState(() => _isActive = val),
              ),
            ],
            const SizedBox(height: 28),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: mutationState.isLoading ? null : _handleSubmit,
              child: mutationState.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(isEditing ? 'Simpan Perubahan' : 'Buat Cabang', maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}
