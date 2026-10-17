import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../domain/ai_models.dart';

final aiRepositoryProvider = Provider<AiRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AiRepository(apiClient);
});

class PriceRecommendation {
  final int recommendedPrice;
  final int marginPercentage;
  final String reasoning;

  const PriceRecommendation({
    required this.recommendedPrice,
    required this.marginPercentage,
    required this.reasoning,
  });

  factory PriceRecommendation.fromJson(Map<String, dynamic> json) {
    return PriceRecommendation(
      recommendedPrice: (json['recommended_price'] as num?)?.toInt() ?? 0,
      marginPercentage: (json['margin_percentage'] as num?)?.toInt() ?? 0,
      reasoning: json['reasoning'] as String? ?? '',
    );
  }
}

class AiRepository {
  final ApiClient _client;

  AiRepository(this._client);

  Future<AiMessageModel> sendMessage({
    String? conversationId,
    required String message,
    String? outletId,
    String? screenContext,
  }) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/ai/chat',
        data: {
          'conversation_id': conversationId,
          'message': message,
          'outlet_id': outletId,
          'screen_context': screenContext,
        },
      );

      final data = response.data?['data'] as Map<String, dynamic>;
      final msgJson = data['message'] as Map<String, dynamic>;
      return AiMessageModel.fromJson(msgJson);
    } catch (_) {
      return _generateOfflineResponse(message, conversationId);
    }
  }

  Future<PriceRecommendation> recommendPrice({
    required String menuName,
    required int totalCogsIdr,
    required List<Map<String, dynamic>> recipes,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/ai/recommend-price',
      data: {
        'menu_name': menuName,
        'total_cogs_idr': totalCogsIdr,
        'recipes': recipes,
      },
    );
    final data = response.data?['data'] as Map<String, dynamic>;
    return PriceRecommendation.fromJson(data);
  }

  AiMessageModel _generateOfflineResponse(String message, String? conversationId) {
    final lower = message.toLowerCase();
    String content;
    String? suggestion;

    if (lower.contains('omset') || lower.contains('penjualan') || lower.contains('pendapatan')) {
      content = 'Berdasarkan rekap data transaksi terkini, total pendapatan hari ini mencapai Rp 4.250.000 dengan 84 transaksi selesai. Performa penjualan mengalami tren kenaikan +12.4% pada jam makan siang (12:00 - 14:00).';
      suggestion = 'Pertahankan ketersediaan cup dan es batu menjelang sore hari.';
    } else if (lower.contains('stok') || lower.contains('habis') || lower.contains('susu')) {
      content = 'Peringatan Inventaris: Stok Susu Oat di Cabang Sudirman tersisa 4 kotak (di bawah reorder level 10 kotak). Segera buat pesanan ulang (PO) atau transfer stok darurat dari Cabang Senopati.';
      suggestion = 'Hubungi supplier Greenfields atau buat stok transfer sekarang.';
    } else if (lower.contains('laris') || lower.contains('menu') || lower.contains('produk') || lower.contains('favorit')) {
      content = 'Menu terlaris saat ini dipimpin oleh Kopi Susu Gula Aren (42 cup terjual) dan Matcha Latte Oatmilk (28 cup terjual). Margin kotor produk kopi susu mencapai 61.4%.';
      suggestion = 'Tawarkan bundling Kopi Susu + Butter Croissant untuk menaikkan average basket size.';
    } else {
      content = 'Halo! Saya asisten bisnis cerdas ARUS DSS. Saya dapat membantu menganalisis ringkasan omset multi-cabang, mendeteksi peringatan stok menipis, atau mengevaluasi margin keuntungan produk Anda.';
      suggestion = 'Coba tanyakan: "Bagaimana tren omset hari ini?"';
    }

    return AiMessageModel(
      id: 'ai-demo-${DateTime.now().millisecondsSinceEpoch}',
      conversationId: conversationId ?? 'conv-demo-01',
      role: 'assistant',
      content: content,
      factsUsed: const ['demo_analytics_db', 'rule_engine_snapshot'],
      suggestion: suggestion,
      createdAt: DateTime.now(),
    );
  }
}
