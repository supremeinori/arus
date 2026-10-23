import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../domain/outlet_models.dart';
import 'outlets_provider.dart';
import 'widgets/outlet_map_widget.dart';

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

  double? _selectedLat;
  double? _selectedLng;
  String _selectedTimezone = 'Asia/Jakarta';
  bool _isActive = true;
  String? _locationError;

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
    // Prefill edit dijadwalkan setelah frame pertama (aturan E26)
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
      _selectedLat = outlet.latitude;
      _selectedLng = outlet.longitude;
      _latController.text = outlet.latitude.toString();
      _lngController.text = outlet.longitude.toString();
      _selectedTimezone = outlet.timezone;
      _isActive = outlet.isActive;
      _locationError = null;
    });
  }

  void _handleLocationSelected(LatLng point) {
    setState(() {
      _selectedLat = point.latitude;
      _selectedLng = point.longitude;
      _latController.text = point.latitude.toStringAsFixed(6);
      _lngController.text = point.longitude.toStringAsFixed(6);
      _locationError = null;
    });
  }

  void _applyCityPreset(String city, double lat, double lng, String tz) {
    setState(() {
      _selectedLat = lat;
      _selectedLng = lng;
      _latController.text = lat.toStringAsFixed(6);
      _lngController.text = lng.toStringAsFixed(6);
      _selectedTimezone = tz;
      _locationError = null;
    });
  }

  Future<void> _handleSubmit() async {
    final lat = _selectedLat ?? double.tryParse(_latController.text.trim()) ?? 0.0;
    final lng = _selectedLng ?? double.tryParse(_lngController.text.trim()) ?? 0.0;

    if (lat == 0.0 && lng == 0.0) {
      setState(() {
        _locationError = 'Harap tentukan lokasi cabang dengan mengetuk titik pada peta.';
      });
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final address = _addressController.text.trim();

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
          backgroundColor: AppTheme.jadeTosca,
        ),
      );
    } else {
      final err = ref.read(outletMutationProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan: $err', maxLines: 3, overflow: TextOverflow.ellipsis),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.outletId != null;
    final mutationState = ref.watch(outletMutationProvider);

    if (isEditing) {
      ref.listen(outletDetailProvider(widget.outletId!), (prev, next) {
        next.whenData(_fillForm);
      });
    }

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        centerTitle: true,
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
            const SizedBox(height: 20),

            // Bagian Peta Interaktif & Pemilihan Lokasi LBS
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Lokasi Cabang pada Peta *',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimaryDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  _selectedLat != null ? 'Koordinat Terpilih' : 'Ketuk Peta',
                  style: TextStyle(
                    fontSize: 12,
                    color: _selectedLat != null ? AppTheme.jadeTosca : AppTheme.textMutedDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Ketuk titik cabang di peta atau gunakan GPS. Koordinat terisi otomatis tanpa input manual.',
              style: TextStyle(fontSize: 12, color: AppTheme.textMutedDark),
            ),
            const SizedBox(height: 10),

            // Peta Interaktif
            OutletLocationPickerWidget(
              initialLatitude: _selectedLat,
              initialLongitude: _selectedLng,
              onLocationSelected: _handleLocationSelected,
            ),

            if (_locationError != null) ...[
              const SizedBox(height: 6),
              Text(
                _locationError!,
                style: const TextStyle(color: AppTheme.dangerRed, fontSize: 12),
              ),
            ],

            const SizedBox(height: 14),

            // Preset Kota Cepat
            const Text(
              'Preset Kota Cepat:',
              style: TextStyle(fontSize: 12, color: AppTheme.textMutedDark, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ActionChip(
                    backgroundColor: AppTheme.darkCardSurfaceElevated,
                    side: const BorderSide(color: AppTheme.darkCardBorder),
                    avatar: const Icon(Icons.location_city_rounded, size: 16, color: AppTheme.jadeTosca),
                    label: const Text('Jakarta', style: TextStyle(color: AppTheme.textPrimaryDark, fontSize: 12)),
                    onPressed: () => _applyCityPreset('Jakarta', -6.2088, 106.8456, 'Asia/Jakarta'),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    backgroundColor: AppTheme.darkCardSurfaceElevated,
                    side: const BorderSide(color: AppTheme.darkCardBorder),
                    avatar: const Icon(Icons.location_city_rounded, size: 16, color: AppTheme.jadeTosca),
                    label: const Text('Jogja', style: TextStyle(color: AppTheme.textPrimaryDark, fontSize: 12)),
                    onPressed: () => _applyCityPreset('Jogja', -7.7828, 110.3670, 'Asia/Jakarta'),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    backgroundColor: AppTheme.darkCardSurfaceElevated,
                    side: const BorderSide(color: AppTheme.darkCardBorder),
                    avatar: const Icon(Icons.location_city_rounded, size: 16, color: AppTheme.jadeTosca),
                    label: const Text('Bali', style: TextStyle(color: AppTheme.textPrimaryDark, fontSize: 12)),
                    onPressed: () => _applyCityPreset('Bali', -8.6705, 115.2126, 'Asia/Makassar'),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    backgroundColor: AppTheme.darkCardSurfaceElevated,
                    side: const BorderSide(color: AppTheme.darkCardBorder),
                    avatar: const Icon(Icons.location_city_rounded, size: 16, color: AppTheme.jadeTosca),
                    label: const Text('London', style: TextStyle(color: AppTheme.textPrimaryDark, fontSize: 12)),
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
                activeThumbColor: AppTheme.jadeTosca,
                title: const Text('Status Operasional Aktif', maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: const Text('Cabang aktif dapat bertransaksi dan menerima pesanan kasir', maxLines: 2, overflow: TextOverflow.ellipsis),
                value: _isActive,
                onChanged: (val) => setState(() => _isActive = val),
              ),
            ],
            const SizedBox(height: 28),
          ],
        ),
      ),
      // Tombol simpan melekat di bawah layar (lihat mockup Form Cabang).
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: BoxDecoration(
            color: AppTheme.darkBackground,
            border: Border(top: BorderSide(color: AppTheme.darkCardBorder)),
          ),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.jadeTosca,
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
        ),
      ),
    );
  }
}
