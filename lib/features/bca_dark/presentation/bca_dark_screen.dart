import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/money_formatter.dart';
import '../../auth/domain/user_model.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../analytics/presentation/analytics_provider.dart';

/// Tema warna BCA Mobile Dark Edition
class BcaDarkColors {
  static const bgDarkest = Color(0xFF060B16); // Midnight obsidian
  static const bgDark = Color(0xFF0A1325); // Deep sapphire
  static const bgSurface = Color(0xFF101E38); // Card surface
  static const bgElevated = Color(0xFF16284D); // Elevated squircle button
  static const bluePrimary = Color(0xFF1D4ED8); // Royal blue
  static const blueGlossyStart = Color(0xFF1E40AF); // Glossy button gradient start
  static const blueGlossyEnd = Color(0xFF2563EB); // Glossy button gradient end
  static const cyanAccent = Color(0xFF38BDF8); // Glow cyan
  static const greenStatus = Color(0xFF22C55E); // BCA Traffic light green
  static const textWhite = Color(0xFFFFFFFF);
  static const textMuted = Color(0xFF94A3B8);
  static const textSlate = Color(0xFF64748B);
  static const borderSubtle = Color(0xFF1E293B);
  static const borderBlue = Color(0xFF2563EB);
}

class BcaDarkScreen extends ConsumerStatefulWidget {
  const BcaDarkScreen({super.key});

  @override
  ConsumerState<BcaDarkScreen> createState() => _BcaDarkScreenState();
}

class _BcaDarkScreenState extends ConsumerState<BcaDarkScreen> {
  // Mode tampilan: 0 = Gateway (Landing), 1 = Dashboard (Home), 2 = Akun Saya (Kartu Paspor)
  int _activeView = 1; // Default ke Dashboard Hub
  int _bottomNavIndex = 0;
  bool _cardRevealed = false;

  void _showMInfoDialog(BuildContext context, int todayOmzet) {
    final now = DateTime.now();
    final timeStr = DateFormat('dd/MM HH:mm:ss').format(now);
    final formattedOmzet = MoneyFormatter.format(todayOmzet);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0D172E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x6638BDF8), width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x99000000),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
              BoxShadow(
                color: Color(0x331D4ED8),
                blurRadius: 15,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Dialog
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Color(0xFF1E293B), width: 1.2),
                  ),
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: BcaDarkColors.bluePrimary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(Icons.info_outline, color: Colors.white, size: 16),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'm-Info',
                        style: GoogleFonts.lexend(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Content Dialog (Informasi Saldo & Omzet Kasir)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'm-Info:\n$timeStr',
                      style: GoogleFonts.lexend(
                        color: BcaDarkColors.textMuted,
                        fontSize: 12.5,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF070E1E),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF1E293B)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Rek. Kasir: 8829-019',
                                style: GoogleFonts.lexend(
                                  color: BcaDarkColors.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0x2622C55E),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: BcaDarkColors.greenStatus, width: 1),
                                ),
                                child: Text(
                                  'ONLINE',
                                  style: GoogleFonts.lexend(
                                    color: BcaDarkColors.greenStatus,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Omzet Kasir Hari Ini:',
                            style: GoogleFonts.lexend(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formattedOmzet,
                            style: GoogleFonts.lexend(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Tombol OK Glossy Blue
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF2563EB),
                        Color(0xFF1D4ED8),
                        Color(0xFF1E3A8A),
                      ],
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x661D4ED8),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => Navigator.of(ctx).pop(),
                      child: Center(
                        child: Text(
                          'OK',
                          style: GoogleFonts.lexend(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final overviewAsync = ref.watch(analyticsOverviewProvider);
    final todayOmzet = overviewAsync.asData?.value.revenueIdr ?? 1450000;

    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: BcaDarkColors.bgDarkest,
        textTheme: GoogleFonts.lexendTextTheme(ThemeData.dark().textTheme),
      ),
      child: Scaffold(
        backgroundColor: BcaDarkColors.bgDarkest,
        appBar: _buildTopControlBar(context),
        body: _buildCurrentView(user, todayOmzet),
        bottomNavigationBar: _activeView == 0 ? null : _buildBcaBottomNav(),
      ),
    );
  }

  /// App bar kontrol atas: Memungkinkan beralih antara 3 mode tampilan BCA & kembali
  PreferredSizeWidget _buildTopControlBar(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFF0B1426),
      elevation: 0,
      centerTitle: false,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        tooltip: 'Kembali ke Tema Standar',
        onPressed: () => Navigator.of(context).canPop() ? Navigator.of(context).pop() : context.go('/shell'),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'ARUS ',
                style: GoogleFonts.lexend(
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                  fontStyle: FontStyle.italic,
                  color: Colors.white,
                ),
              ),
              Text(
                'mobile',
                style: GoogleFonts.lexend(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                  color: BcaDarkColors.cyanAccent,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0x4D1D4ED8),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: BcaDarkColors.cyanAccent, width: 0.8),
                ),
                child: Text(
                  'DARK VIBE',
                  style: GoogleFonts.lexend(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: BcaDarkColors.cyanAccent,
                  ),
                ),
              ),
            ],
          ),
          Text(
            'Mode Uji Coba UI Vibe BCA Mobile',
            style: GoogleFonts.lexend(fontSize: 10, color: BcaDarkColors.textMuted),
          ),
        ],
      ),
      actions: [
        // Indikator lampu hijau BCA
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Center(
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: BcaDarkColors.greenStatus,
                borderRadius: BorderRadius.circular(3),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0xB322C55E),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.white70, size: 20),
          tooltip: 'Keluar',
          onPressed: () => Navigator.of(context).canPop() ? Navigator.of(context).pop() : context.go('/login'),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(42),
        child: Container(
          color: const Color(0xFF070E1C),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              _buildViewSwitchChip(
                label: 'Gateway',
                icon: Icons.meeting_room_outlined,
                isActive: _activeView == 0,
                onTap: () => setState(() => _activeView = 0),
              ),
              const SizedBox(width: 6),
              _buildViewSwitchChip(
                label: 'Menu Hub',
                icon: Icons.grid_view_rounded,
                isActive: _activeView == 1,
                onTap: () => setState(() => _activeView = 1),
              ),
              const SizedBox(width: 6),
              _buildViewSwitchChip(
                label: 'Akun Paspor',
                icon: Icons.credit_card_rounded,
                isActive: _activeView == 2,
                onTap: () => setState(() => _activeView = 2),
              ),
              const Spacer(),
              // Tombol Uji Pop-up m-Info
              InkWell(
                onTap: () {
                  final overview = ref.read(analyticsOverviewProvider);
                  final omzet = overview.asData?.value.revenueIdr ?? 1450000;
                  _showMInfoDialog(context, omzet);
                },
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: BcaDarkColors.bluePrimary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 12, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        'm-Info',
                        style: GoogleFonts.lexend(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildViewSwitchChip({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? BcaDarkColors.bluePrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isActive ? BcaDarkColors.cyanAccent : const Color(0xFF334155),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 12, color: isActive ? Colors.white : BcaDarkColors.textMuted),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.lexend(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? Colors.white : BcaDarkColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentView(UserModel? user, int todayOmzet) {
    switch (_activeView) {
      case 0:
        return _buildGatewayView(context);
      case 2:
        return _buildAkunSayaView(context, user);
      case 1:
      default:
        return _buildDashboardHubView(context, user, todayOmzet);
    }
  }

  // ==========================================
  // VIEW 1: GATEWAY / LANDING SPLASH BCA DARK
  // ==========================================
  Widget _buildGatewayView(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF09142A),
            Color(0xFF060B16),
            Color(0xFF04070E),
          ],
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  // Logo Besar BCA Style
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'ARUS',
                        style: GoogleFonts.lexend(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          fontStyle: FontStyle.italic,
                          color: Colors.white,
                          letterSpacing: 1,
                          shadows: const [
                            Shadow(
                              color: Color(0x8038BDF8),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'mobile',
                        style: GoogleFonts.lexend(
                          fontSize: 32,
                          fontWeight: FontWeight.w600,
                          fontStyle: FontStyle.italic,
                          color: BcaDarkColors.cyanAccent,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // 3 Tombol Utama Glossy Gradasi Biru
                  _buildGlossyMenuCard(
                    iconBadge: Icons.point_of_sale_rounded,
                    title: 'm-ARUS',
                    subtitle: 'Kasir POS & Transaksi Cepat',
                    onTap: () => setState(() => _activeView = 1),
                  ),
                  const SizedBox(height: 12),
                  _buildGlossyMenuCard(
                    iconBadge: Icons.public_rounded,
                    title: 'KlikArus',
                    subtitle: 'Portal Web & Analitik Pusat',
                    onTap: () => context.push('/reports'),
                  ),
                  const SizedBox(height: 12),
                  _buildGlossyMenuCard(
                    iconBadge: Icons.info_outline_rounded,
                    title: 'Info Arus',
                    subtitle: 'Katalog, Stok & Mutasi Realtime',
                    onTap: () => context.push('/catalog'),
                  ),

                  const SizedBox(height: 24),

                  // 3 Tombol Pill Sekunder
                  _buildSecondaryPillButton(
                    title: 'Buka Sesi Kasir Baru',
                    onTap: () => context.push('/shell'),
                  ),
                  const SizedBox(height: 10),
                  _buildSecondaryPillButton(
                    title: 'Ganti Kode Akses / PIN',
                    onTap: () => context.push('/settings'),
                  ),
                  const SizedBox(height: 10),
                  _buildSecondaryPillButton(
                    title: 'Arus Flazz & Saldo Digital',
                    onTap: () {
                      final overview = ref.read(analyticsOverviewProvider);
                      final omzet = overview.asData?.value.revenueIdr ?? 1450000;
                      _showMInfoDialog(context, omzet);
                    },
                  ),
                ],
              ),
            ),
          ),

          // Footer Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFF0F1B30),
              border: Border(
                top: BorderSide(color: Color(0xFF1E293B), width: 1.5),
              ),
            ),
            child: Text(
              'Selamat datang di ARUS mobile',
              textAlign: TextAlign.center,
              style: GoogleFonts.lexend(
                color: Colors.white70,
                fontSize: 13,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlossyMenuCard({
    required IconData iconBadge,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF2563EB),
            Color(0xFF1D4ED8),
            Color(0xFF172554),
          ],
        ),
        border: Border.all(color: const Color(0xFF3B82F6), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x80000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Icon(iconBadge, color: BcaDarkColors.bluePrimary, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.lexend(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          fontStyle: FontStyle.italic,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.lexend(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white70),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryPillButton({
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(23),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1E3A8A),
            Color(0xFF172554),
          ],
        ),
        border: Border.all(color: const Color(0x992563EB), width: 1.2),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(23),
          onTap: onTap,
          child: Center(
            child: Text(
              title,
              style: GoogleFonts.lexend(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // VIEW 2: DASHBOARD HUB (GRID 10 IKON BCA DARK)
  // ==========================================
  Widget _buildDashboardHubView(BuildContext context, UserModel? user, int todayOmzet) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        // Salam Sambutan BCA
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0D172E),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF1E293B)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selamat datang,',
                      style: GoogleFonts.lexend(
                        color: BcaDarkColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user?.name ?? 'Rina Kartika (Owner)',
                      style: GoogleFonts.lexend(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () => _showMInfoDialog(context, todayOmzet),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: BcaDarkColors.bluePrimary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance_wallet_outlined, size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        'Cek Saldo',
                        style: GoogleFonts.lexend(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 22),

        // Grid 4 Kolom Ikon BCA Squircle
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 12,
          childAspectRatio: 0.76,
          children: [
            _buildBcaSquircleIcon(
              icon: Icons.info_outline_rounded,
              label: 'm-Info',
              onTap: () => _showMInfoDialog(context, todayOmzet),
            ),
            _buildBcaSquircleIcon(
              icon: Icons.point_of_sale_rounded,
              label: 'm-Kasir',
              onTap: () => context.push('/shell'),
            ),
            _buildBcaSquircleIcon(
              icon: Icons.inventory_2_outlined,
              label: 'm-Katalog',
              onTap: () => context.push('/catalog'),
            ),
            _buildBcaSquircleIcon(
              icon: Icons.warehouse_outlined,
              label: 'm-Stok',
              onTap: () => context.push('/inventory'),
            ),
            _buildBcaSquircleIcon(
              icon: Icons.bar_chart_rounded,
              label: 'm-Laporan',
              onTap: () => context.push('/reports'),
            ),
            _buildBcaSquircleIcon(
              icon: Icons.auto_awesome_rounded,
              label: 'm-AI',
              onTap: () => context.push('/shell'),
            ),
            _buildBcaSquircleIcon(
              icon: Icons.storefront_outlined,
              label: 'm-Cabang',
              onTap: () => context.push('/outlets'),
            ),
            _buildBcaSquircleIcon(
              icon: Icons.fingerprint_rounded,
              label: 'm-Sensor',
              onTap: () => context.push('/sensors'),
            ),
            _buildBcaSquircleIcon(
              icon: Icons.card_giftcard_rounded,
              label: 'BagiBagi',
              onTap: () => context.push('/insights'),
            ),
            _buildBcaSquircleIcon(
              icon: Icons.tune_rounded,
              label: 'Lifestyle',
              onTap: () => context.push('/settings'),
            ),
            _buildBcaSquircleIcon(
              icon: Icons.notifications_active_outlined,
              label: 'Notif',
              onTap: () => context.push('/notifications'),
            ),
            _buildBcaSquircleIcon(
              icon: Icons.credit_card_rounded,
              label: 'Kartu',
              onTap: () => setState(() => _activeView = 2),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Banner Status Mesin POS BCA
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF0C162A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0x661D4ED8)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0x331D4ED8),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.security_rounded, color: BcaDarkColors.cyanAccent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Terminal POS Siap Digunakan',
                      style: GoogleFonts.lexend(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Terhubung ke server lokal • Mode offline aktif',
                      style: GoogleFonts.lexend(
                        color: BcaDarkColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBcaSquircleIcon({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF1E3A8A),
                Color(0xFF172554),
                Color(0xFF0F172A),
              ],
            ),
            border: Border.all(color: const Color(0xB32563EB), width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x80000000),
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: Center(
                child: Icon(icon, color: Colors.white, size: 28),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.lexend(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // VIEW 3: AKUN SAYA & KARTU PASPOR ARUS GPN
  // ==========================================
  Widget _buildAkunSayaView(BuildContext context, UserModel? user) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      children: [
        Text(
          'Pilih Kartu',
          style: GoogleFonts.lexend(
            color: BcaDarkColors.textMuted,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Paspor ARUS GPN Blue (Merchant)',
          style: GoogleFonts.lexend(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 18),

        // Kartu Debit / Merchant Digital Paspor ARUS Blue
        Container(
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1E40AF),
                Color(0xFF1D4ED8),
                Color(0xFF0F172A),
              ],
            ),
            border: Border.all(color: const Color(0x8060A5FA), width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x661D4ED8),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
              BoxShadow(
                color: Color(0x99000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Motif Watermark Abstrak
              const Positioned(
                right: -30,
                bottom: -20,
                child: Opacity(
                  opacity: 0.12,
                  child: Icon(Icons.waves_rounded, size: 240, color: Colors.white),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Baris Atas: Paspor debit & Logo ARUS
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Paspor debit',
                          style: GoogleFonts.lexend(
                            color: Colors.white,
                            fontSize: 15,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'ARUS',
                          style: GoogleFonts.lexend(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Chip Emas Kartu
                    Container(
                      width: 38,
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4AF37),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFF3E5AB), width: 0.8),
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Container(
                              width: 30,
                              height: 1,
                              color: const Color(0xFF996515),
                            ),
                          ),
                          Center(
                            child: Container(
                              width: 1,
                              height: 20,
                              color: const Color(0xFF996515),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // Nomor Kartu
                    Text(
                      _cardRevealed ? '5211  8829  4012  8829' : '5211  ••••  ••••  8829',
                      style: GoogleFonts.shareTechMono(
                        color: Colors.white,
                        fontSize: 18,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Baris Bawah: Nama & Logo GPN
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'VALID THRU 08/29',
                              style: GoogleFonts.shareTechMono(
                                color: Colors.white70,
                                fontSize: 10,
                              ),
                            ),
                            Text(
                              (user?.name ?? 'RINA KARTIKA').toUpperCase(),
                              style: GoogleFonts.lexend(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        // Badge GPN
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.shade700,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            'GPN',
                            style: GoogleFonts.lexend(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Bar Nomor Kartu & Tombol Copy
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0D172E),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF1E293B)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Nomor Rekening Kasir',
                style: GoogleFonts.lexend(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      _cardRevealed ? Icons.visibility_off : Icons.visibility,
                      color: BcaDarkColors.cyanAccent,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _cardRevealed = !_cardRevealed),
                    tooltip: 'Lihat Nomor',
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, color: BcaDarkColors.cyanAccent, size: 18),
                    onPressed: () {
                      Clipboard.setData(const ClipboardData(text: '5211882940128829'));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: const Color(0xFF1E293B),
                          content: Text(
                            'Nomor kartu berhasil disalin!',
                            style: GoogleFonts.lexend(color: Colors.white),
                          ),
                        ),
                      );
                    },
                    tooltip: 'Salin Nomor',
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // 3 Tombol Aksi Bulat di Bawah Kartu
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildRoundActionButton(
              icon: Icons.tune_rounded,
              label: 'Kontrol',
              onTap: () => context.push('/settings'),
            ),
            _buildRoundActionButton(
              icon: Icons.speed_rounded,
              label: 'Atur Limit',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF1E293B),
                    content: Text(
                      'Limit transaksi harian kasir: Rp 100.000.000',
                      style: GoogleFonts.lexend(color: Colors.white),
                    ),
                  ),
                );
              },
            ),
            _buildRoundActionButton(
              icon: Icons.block_flipped,
              label: 'Blokir',
              isDanger: true,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFFDC2626),
                    content: Text(
                      'Terminal kasir dalam mode pengamanan aktif.',
                      style: GoogleFonts.lexend(color: Colors.white),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRoundActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDanger = false,
  }) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDanger
                  ? const [
                      Color(0xFFDC2626),
                      Color(0xFF991B1B),
                    ]
                  : const [
                      Color(0xFF1E40AF),
                      Color(0xFF172554),
                    ],
            ),
            border: Border.all(
              color: isDanger ? const Color(0xFFEF4444) : const Color(0xFF3B82F6),
              width: 1.2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: Center(
                child: Icon(icon, color: Colors.white, size: 24),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.lexend(
            color: Colors.white,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // BOTTOM NAVIGATION BAR BCA DENGAN QRIS FLOATING
  // ==========================================
  Widget _buildBcaBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF091224),
        border: Border(
          top: BorderSide(color: Color(0xFF1E293B), width: 1.5),
        ),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBcaNavItem(
                icon: Icons.home_rounded,
                label: 'Home',
                index: 0,
                isActive: _activeView == 1 && _bottomNavIndex == 0,
                onTap: () {
                  setState(() {
                    _activeView = 1;
                    _bottomNavIndex = 0;
                  });
                },
              ),
              _buildBcaNavItem(
                icon: Icons.receipt_long_rounded,
                label: 'Transaksi',
                index: 1,
                isActive: _bottomNavIndex == 1,
                onTap: () {
                  setState(() => _bottomNavIndex = 1);
                  context.push('/reports');
                },
              ),

              // Tombol Floating QRIS Tengah Ikonik BCA
              GestureDetector(
                onTap: () => context.push('/shell'),
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF2563EB),
                        Color(0xFF1D4ED8),
                        Color(0xFF1E3A8A),
                      ],
                    ),
                    border: Border.all(color: BcaDarkColors.cyanAccent, width: 1.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x801D4ED8),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Center(
                        child: Icon(Icons.qr_code_2_rounded, color: BcaDarkColors.bluePrimary, size: 20),
                      ),
                    ),
                  ),
                ),
              ),

              _buildBcaNavItem(
                icon: Icons.notifications_none_rounded,
                label: 'Notifikasi',
                index: 3,
                isActive: _bottomNavIndex == 3,
                onTap: () {
                  setState(() => _bottomNavIndex = 3);
                  context.push('/notifications');
                },
              ),
              _buildBcaNavItem(
                icon: Icons.person_outline_rounded,
                label: 'Akun Saya',
                index: 4,
                isActive: _activeView == 2,
                onTap: () {
                  setState(() {
                    _activeView = 2;
                    _bottomNavIndex = 4;
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBcaNavItem({
    required IconData icon,
    required String label,
    required int index,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 22,
            color: isActive ? BcaDarkColors.cyanAccent : BcaDarkColors.textMuted,
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: GoogleFonts.lexend(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive ? BcaDarkColors.cyanAccent : BcaDarkColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
