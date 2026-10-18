import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../../shared/widgets/empty_state.dart';
import 'inventory_provider.dart';

/// E21: formatter dibuat sekali di luar build, bukan di dalam build().
final _movementDateFormat = DateFormat('dd MMM yyyy, HH:mm');

class StockMovementScreen extends ConsumerWidget {
  final String? outletId;

  const StockMovementScreen({super.key, this.outletId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movementsAsync = ref.watch(inventoryMovementsProvider(outletId));

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: Text('Riwayat Mutasi Stok', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 17)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(inventoryMovementsProvider(outletId)),
          ),
        ],
      ),
      body: AsyncStateView(
        value: movementsAsync,
        onRetry: () => ref.invalidate(inventoryMovementsProvider(outletId)),
        dataBuilder: (movements) {
          if (movements.isEmpty) {
            return const EmptyStateView(
              message: 'Belum ada riwayat mutasi stok.',
              icon: Icons.history_toggle_off_rounded,
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: movements.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = movements[index];
              final isPositive = item.quantityDelta > 0;

              return Card(
                color: AppTheme.darkCardSurface,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: AppTheme.darkCardBorder, width: 1.0),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isPositive ? const Color(0x2210B981) : const Color(0x22EF4444),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isPositive ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                          color: isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.productName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimaryDark),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${item.typeLabel} • ${item.outletName}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(color: AppTheme.textSecondaryDark, fontSize: 12),
                            ),
                            if (item.note != null && item.note!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Catatan: ${item.note}',
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(fontSize: 12, fontStyle: FontStyle.italic, color: AppTheme.textMutedDark),
                              ),
                            ],
                            const SizedBox(height: 4),
                            Text(
                              'Oleh: ${item.creatorName} • ${_movementDateFormat.format(item.createdAt)}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(color: AppTheme.textMutedDark, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // B9: trailing dibatasi lebarnya agar tidak unbounded width.
                      SizedBox(
                        width: 88,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${isPositive ? '+' : ''}${item.quantityDelta} ${item.unit}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: isPositive ? const Color(0xFF34D399) : const Color(0xFFF87171),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Sisa: ${item.quantityAfter}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(color: AppTheme.textMutedDark, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
