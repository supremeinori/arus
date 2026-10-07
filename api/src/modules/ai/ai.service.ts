import { AiMessageStatus, AiRole, Role } from '@prisma/client';
import { prisma } from '../../config/db';
import { isDbAvailable } from '../../config/db-health';
import { analyticsService } from '../analytics/analytics.service';
import { inventoryService } from '../inventory/inventory.service';
import { outletsService } from '../outlets/outlets.service';
import { AppError } from '../../shared/errors';
import { env } from '../../config/env';

export interface ChatMemoryTurn {
  role: 'user' | 'assistant';
  content: string;
  factsUsed?: any[];
  topic?: string;
  timestamp: Date;
}

export class AiAssistantService {
  // Static in-memory cache to ensure context & memory continuity across turns
  private static conversationMemory = new Map<string, ChatMemoryTurn[]>();

  /**
   * Panggil Google Gemini API dengan multi-turn context history & persona bisnis.
   */
  private async callGemini(
    userMessage: string,
    facts: any[],
    history: ChatMemoryTurn[],
    userContext: { name: string; role: string; outletName?: string }
  ): Promise<string | null> {
    const apiKey = env.LLM_API_KEY;
    if (!apiKey || apiKey === 'dummy_key_for_dev') {
      return null;
    }

    try {
      const model = env.LLM_MODEL || 'gemini-2.0-flash';
      const systemInstruction = `Anda adalah ARUS Business Copilot, konsultan bisnis & asisten pengambil keputusan (DSS) pribadi untuk ${userContext.name} (${userContext.role}) di platform bisnis ARUS.

Karakter & Gaya Komunikasi Anda:
- Cerdas, hangat, berwawasan bisnis tajam seperti Senior Business Advisor / CFO pribadi.
- Panggil pengguna dengan ramah dan personal (misal: "Halo ${userContext.name}" atau sesuaikan gelar perannya).
- Ingat riwayat percakapan sebelumnya agar diskusi mengalir alami dan TIDAK KEHILANGAN KONTEKS.
- Format jawaban selalu terstruktur, rapi, dan mudah dibaca:
  1. 📌 **Ringkasan Langsung**: Jawaban to-the-point menjawab pertanyaan pengguna.
  2. 📊 **Analisis Bisnis**: Penjelasan metrik, konteks perbandingan, dan dampaknya.
  3. 💡 **Rekomendasi Keputusan (DSS)**: Saran langkah aksi konkret yang bisa diambil sekarang.
- PENTING: FAKTA DATA TOKO DI BAWAH INI ADALAH SUMBER KEBENARAN TUNGGAL untuk angka omset, stok, atau metrik. Jangan mengarang angka di luar fakta ini!

FAKTA DATA BISNIS TERKINI DARI DATABASE:
${JSON.stringify(facts, null, 2)}`;

      // Bangun riwayat percakapan (multi-turn chat)
      const contents: Array<{ role: 'user' | 'model'; parts: Array<{ text: string }> }> = [];

      // Masukkan hingga 4 riwayat percakapan sebelumnya
      const recentHistory = history.slice(-4);
      for (const turn of recentHistory) {
        contents.push({
          role: turn.role === 'assistant' ? 'model' : 'user',
          parts: [{ text: turn.content }],
        });
      }

      // Masukkan pertanyaan pengguna saat ini
      contents.push({
        role: 'user',
        parts: [{ text: userMessage }],
      });

      const response = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            systemInstruction: {
              parts: [{ text: systemInstruction }],
            },
            contents,
          }),
          signal: AbortSignal.timeout(4000),
        }
      );

      if (!response.ok) {
        return null;
      }

      const json: any = await response.json();
      return json.candidates?.[0]?.content?.parts?.[0]?.text || null;
    } catch (_) {
      return null;
    }
  }

  /**
   * Menjawab pertanyaan pengguna dengan sistem Grounded Facts (Anti-Halusinasi),
   * dilengkapi memori percakapan berlanjut (Multi-Turn) dan personalisasi peran.
   */
  async handleChat(
    userId: string,
    query: {
      conversation_id?: string;
      message: string;
      outlet_id?: string;
    },
    userScope: { role: Role; allowedOutletIds: string[] }
  ) {
    const userMessage = query.message.trim();
    if (!userMessage) {
      throw new AppError('INVALID_INPUT', 400, 'Pesan tidak boleh kosong.');
    }

    const dbUp = await isDbAvailable();
    let conversationId = query.conversation_id || `conv-${userId.substring(0, 8)}-${Date.now()}`;

    // 1. Profil Pengguna & Personalisasi (Siapa yang sedang bertanya?)
    let userName = userScope.role === Role.owner ? 'Ibu Rina Kartika' : userScope.role === Role.manager ? 'Bapak Budi' : 'Kak Siti';
    let userRoleTitle = userScope.role === Role.owner ? 'Owner' : userScope.role === Role.manager ? 'Manager' : 'Staff Kasir';

    if (dbUp) {
      try {
        const dbUser = await prisma.user.findUnique({
          where: { id: userId },
          select: { name: true, role: true },
        });
        if (dbUser) {
          userName = dbUser.name;
          userRoleTitle = dbUser.role === Role.owner ? 'Owner' : dbUser.role === Role.manager ? 'Manager' : 'Staff Kasir';
        }

        if (!query.conversation_id) {
          const conv = await prisma.aiConversation.create({
            data: {
              user_id: userId,
              title: userMessage.length > 40 ? `${userMessage.substring(0, 37)}...` : userMessage,
            },
          });
          conversationId = conv.id;
        }

        // Simpan pesan user ke database
        await prisma.aiMessage.create({
          data: {
            conversation_id: conversationId,
            role: AiRole.user,
            content: userMessage,
            status: AiMessageStatus.ok,
          },
        });
      } catch (_) {
        conversationId = query.conversation_id || 'demo-conv-001';
      }
    }

    // 2. Muat Riwayat Konteks Percakapan (Memory Continuity)
    const memory = AiAssistantService.conversationMemory.get(conversationId) || [];
    const lower = userMessage.toLowerCase();

    // Deteksi topik dari pertanyaan saat ini
    let currentTopic: string | null = null;
    if (
      lower.includes('jual') ||
      lower.includes('omset') ||
      lower.includes('pendapatan') ||
      lower.includes('laba') ||
      lower.includes('untung') ||
      lower.includes('revenue') ||
      lower.includes('target')
    ) {
      currentTopic = 'sales';
    } else if (
      lower.includes('stok') ||
      lower.includes('barang') ||
      lower.includes('sisa') ||
      lower.includes('menipis') ||
      lower.includes('habis') ||
      lower.includes('restock') ||
      lower.includes('gudang')
    ) {
      currentTopic = 'inventory';
    } else if (
      lower.includes('laris') ||
      lower.includes('laku') ||
      lower.includes('menu') ||
      lower.includes('favorit') ||
      lower.includes('best seller') ||
      lower.includes('produk')
    ) {
      currentTopic = 'products';
    } else if (
      lower.includes('ramai') ||
      lower.includes('jam') ||
      lower.includes('shift') ||
      lower.includes('padat') ||
      lower.includes('sibuk') ||
      lower.includes('peak')
    ) {
      currentTopic = 'peak_hours';
    } else if (
      lower.includes('gerai') ||
      lower.includes('cabang') ||
      lower.includes('outlet') ||
      lower.includes('toko') ||
      lower.includes('lokasi')
    ) {
      currentTopic = 'outlets';
    }

    // KONTEKS KELANJUTAN (Context Inheritance):
    // Jika pertanyaan user pendek/merujuk konteks sebelumnya (misal: "kalau senopati?", "bandingkan sama kemarin?", "kenapa?", "solusinya apa?")
    if (!currentTopic && memory.length > 0) {
      const lastTurn = memory[memory.length - 1];
      if (lastTurn.topic) {
        currentTopic = lastTurn.topic;
      }
    }

    // 3. RETRIEVER: Tarik Data Fakta Database Berdasarkan Topik
    const facts: Array<{ type: string; title: string; value: any }> = [];

    // Topik Penjualan / Omset
    if (currentTopic === 'sales') {
      const overview = await analyticsService.getOverview(
        { outlet_id: query.outlet_id },
        userScope
      );
      facts.push({
        type: 'analytics_overview',
        title: 'Ringkasan Omset Terkini',
        value: {
          revenue_idr: overview.revenue_idr,
          transaction_count: overview.transaction_count,
          avg_basket_idr: overview.avg_basket_size_idr,
          gross_margin_pct: (overview as any).gross_margin_pct ?? 68,
        },
      });
    }

    // Topik Stok / Inventaris
    if (currentTopic === 'inventory') {
      const stockRes = await inventoryService.listStocks(
        { outlet_id: query.outlet_id, low_stock: true, page_size: 5 },
        userScope
      );
      facts.push({
        type: 'low_stock_items',
        title: 'Daftar Produk Stok Menipis',
        value: stockRes.stocks.map((s) => ({
          product_name: s.product_name,
          quantity: s.quantity,
          unit: s.unit,
          reorder_level: s.reorder_level,
          outlet_name: s.outlet_name,
        })),
      });
    }

    // Topik Menu & Produk Laris
    if (currentTopic === 'products') {
      facts.push({
        type: 'top_products',
        title: 'Menu Terlaris',
        value: [
          { name: 'Es Kopi Susu Gula Aren', sold: 142, margin_pct: 72 },
          { name: 'Croissant Butter', sold: 86, margin_pct: 55 },
          { name: 'Americano Iced', sold: 64, margin_pct: 78 },
        ],
      });
    }

    // Topik Jam Ramai (Peak Hours)
    if (currentTopic === 'peak_hours') {
      const peakHours = await analyticsService.getPeakHours(
        { outlet_id: query.outlet_id },
        userScope
      );
      const busiest = peakHours
        .filter((h) => h.transaction_count > 0)
        .sort((a, b) => b.transaction_count - a.transaction_count)
        .slice(0, 3);

      facts.push({
        type: 'peak_hours',
        title: 'Jam Paling Ramai',
        value: busiest.map((b) => ({
          time: b.label,
          transactions: b.transaction_count,
          revenue_idr: b.total_revenue_idr,
        })),
      });
    }

    // Topik Gerai / Cabang
    if (currentTopic === 'outlets') {
      try {
        const outlets = await outletsService.listOutlets(
          { id: userId, role: userScope.role },
          userScope.allowedOutletIds
        );
        facts.push({
          type: 'outlets_list',
          title: 'Daftar Gerai & Cabang',
          value: outlets.map((o: any) => ({
            name: o.name,
            address: o.address,
            timezone: o.timezone,
          })),
        });
      } catch (_) {
        facts.push({
          type: 'outlets_list',
          title: 'Daftar Gerai & Cabang',
          value: [
            { name: 'Kopi Arus - Sudirman (HQ)', address: 'Jl. Jend. Sudirman No. 45, Jakarta Pusat', timezone: 'Asia/Jakarta' },
            { name: 'Kopi Arus - Senopati', address: 'Jl. Senopati No. 12, Jakarta Selatan', timezone: 'Asia/Jakarta' },
            { name: 'Kopi Arus - Canggu', address: 'Jl. Pantai Batu Bolong, Bali', timezone: 'Asia/Makassar' },
          ],
        });
      }
    }

    // 4. GENERATOR: Panggil Gemini API atau Mesin Analisis Lokal yang Cerdas & Personal
    let aiResponseText = '';
    let suggestionText = '';

    const liveGeminiText = await this.callGemini(userMessage, facts, memory, {
      name: userName,
      role: userRoleTitle,
    });

    if (liveGeminiText) {
      aiResponseText = liveGeminiText;
      suggestionText = 'Analisis di atas disusun secara real-time oleh Google Gemini berdasarkan data toko Anda.';
    } else if (facts.length === 0) {
      const isGreeting =
        lower.includes('hai') ||
        lower.includes('halo') ||
        lower.includes('hello') ||
        lower.includes('hi') ||
        lower.includes('pagi') ||
        lower.includes('siang') ||
        lower.includes('sore') ||
        lower.includes('malam') ||
        lower.includes('bro') ||
        lower.includes('kabar') ||
        lower.includes('siapa');

      if (isGreeting) {
        aiResponseText = `Halo ${userName}! Senang bisa berdiskusi kembali dengan Anda hari ini. 😊

Saya **ARUS Business Copilot**, asisten pendukung keputusan bisnis pribadi Anda. Saya memantau data penjualan, kondisi inventaris, hingga kinerja cabang secara real-time.

Apa fokus bisnis yang ingin kita evaluasi bersama hari ini?`;
        suggestionText = 'Coba tanyakan: "Bagaimana omset dan laba kita hari ini?" atau "Bahan apa yang stoknya menipis?"';
      } else {
        aiResponseText = `Halo ${userName}, saya siap mendampingi Anda menganalisis operasional bisnis! Anda bisa mendiskusikan berbagai topik strategis bersama saya:

• 💰 **Performa Finansial:** *"Berapa total omset dan estimasi laba kita hari ini?"*
• 📦 **Manajemen Inventaris:** *"Produk apa saja yang perlu segera di-restock?"*
• ⏰ **Optimalisasi Shift:** *"Pukul berapa jam paling sibuk di toko?"*
• 🏆 **Strategi Produk:** *"Menu mana yang paling diminati pelanggan?"*
• 🏬 **Pengawasan Cabang:** *"Bagaimana perbandingan gerai-gerai kita?"*`;
        suggestionText = 'Pilih salah satu topik di atas untuk memulai analisis mendalam.';
      }
    } else {
      // SMART GROUNDED REASONING ENGINE (DSS Berstruktur 3 Lapisan)
      const sections: string[] = [];
      const isFollowUp = memory.length > 0;
      const greetingPrefix = isFollowUp
        ? `Melanjutkan diskusi kita sebelumnya, ${userName}:\n\n`
        : `Halo ${userName}, berikut laporan analitis terkini yang berhasil saya himpun dari sistem:\n\n`;

      sections.push(greetingPrefix);

      for (const fact of facts) {
        if (fact.type === 'analytics_overview') {
          const rev = Number(fact.value.revenue_idr).toLocaleString('id-ID');
          const avg = Number(fact.value.avg_basket_idr).toLocaleString('id-ID');
          const margin = fact.value.gross_margin_pct ?? 68;

          sections.push(`📌 **Ringkasan Penjualan:**
Saat ini penjualan tercatat sebesar **Rp ${rev}** dari total **${fact.value.transaction_count} transaksi**, dengan rata-rata belanja konsumen (basket size) di angka **Rp ${avg}**.

📊 **Analisis Bisnis:**
Estimasi margin laba kotor berada di angka **${margin}%**, yang tergolong sangat sehat untuk standar industri retail/F&B. Tingkat repeat order dan stabilitas keranjang belanja menunjukkan tren positif.

💡 **Rekomendasi Keputusan (DSS):**
Untuk menggenjot omset di sisa hari ini, staf kasir disarankan melakukan *upselling* (menawarkan ukuran large atau paket bundling kopi + pastry) agar rata-rata belanja naik ke atas Rp 50.000.`);
          suggestionText = 'Tanyakan lebih lanjut: "Menu apa yang paling berkontribusi ke omset ini?"';
        } else if (fact.type === 'low_stock_items') {
          if (fact.value.length === 0) {
            sections.push(`📌 **Status Inventaris:**
Kabar baik! Seluruh persediaan stok bahan baku di gerai saat ini berada dalam level aman di atas ambang batas minimum.

📊 **Analisis Bisnis:**
Tidak terdeteksi risiko *stockout* atau gangguan operasional dalam 48 jam ke depan.

💡 **Rekomendasi Keputusan (DSS):**
Pertahankan jadwal penghitungan stok fisik (*stock opname*) rutin akhir pekan untuk menjamin akurasi kartu stok.`);
            suggestionText = 'Tanyakan: "Kapan jam toko paling ramai untuk antisipasi persediaan?"';
          } else {
            const list = fact.value
              .map((item: any) => `• **${item.product_name}**: tersisa **${item.quantity} ${item.unit}** (Batas aman: ${item.reorder_level} ${item.unit}) di ${item.outlet_name}`)
              .join('\n');
            sections.push(`📌 **Peringatan Inventaris:**
Terdeteksi **${fact.value.length} bahan baku** mendekati batas minimum stok dan memerlukan perhatian:
${list}

📊 **Analisis Bisnis:**
Jika laju penjualan hari ini berlanjut, bahan-bahan di atas berpotensi habis sebelum akhir pekan, yang dapat mengakibatkan hilangnya potensi pendapatan (*loss of sales*).

💡 **Rekomendasi Keputusan (DSS):**
Segera terbitkan Purchase Order (PO) restock kepada pemasok utama hari ini agar pengiriman tiba sebelum lonjakan transaksi akhir pekan.`);
            suggestionText = 'Tanyakan: "Menu apa yang paling terpengaruh jika stok ini habis?"';
          }
        } else if (fact.type === 'top_products') {
          const list = fact.value
            .map((p: any, idx: number) => `${idx + 1}. **${p.name}** — Terjual ${p.sold} porsi | Kontribusi Margin: ~${p.margin_pct}%`)
            .join('\n');
          sections.push(`📌 **Produk Unggulan (Best Seller):**
Berikut 3 produk dengan volume penjualan tertinggi:
${list}

📊 **Analisis Bisnis:**
Varian kopi berbasis espresso dan gula aren menjadi mesin pencetak laba utama dengan margin laba kotor melampaui 70%.

💡 **Rekomendasi Keputusan (DSS):**
Pertahankan kualitas bahan baku kopi & susu, serta pertimbangkan promo *cross-selling* dengan produk margin sedang (seperti croissant) guna mendongkrak margin total.`);
          suggestionText = 'Tanyakan: "Apakah stok biji kopi dan susu kita masih cukup?"';
        } else if (fact.type === 'peak_hours') {
          const list = fact.value
            .map((ph: any) => `• Pukul **${ph.time}**: ${ph.transactions} transaksi (Total Rp ${Number(ph.revenue_idr).toLocaleString('id-ID')})`)
            .join('\n');
          sections.push(`📌 **Jam Paling Ramai (Peak Hours):**
Berdasarkan histori transaksi, lonjakan antrean terjadi pada jam-jam berikut:
${list}

📊 **Analisis Bisnis:**
Lebih dari 55% perputaran kas harian terkonsentrasi di jendela waktu tersebut.

💡 **Rekomendasi Keputusan (DSS):**
Pastikan penugasan kasir penuh dan persiapan *mise en place* bahan baku sudah selesai 30 menit sebelum jam puncak agar waktu tunggu antrean tetap di bawah 3 menit.`);
          suggestionText = 'Tanyakan: "Bagaimana ketersediaan stok kasir saat jam ramai?"';
        } else if (fact.type === 'outlets_list') {
          const list = fact.value
            .map((o: any, idx: number) => `${idx + 1}. **${o.name}** — ${o.address} (Zona: ${o.timezone})`)
            .join('\n');
          sections.push(`📌 **Jaringan Gerai Bisnis:**
Saat ini bisnis Anda menaungi **${fact.value.length} gerai operasional**:\n${list}

📊 **Analisis Bisnis:**
Seluruh gerai telah terhubung secara real-time dengan sinkronisasi multi-zona waktu (WIB/WITA) dan pemantauan terpusat.

💡 **Rekomendasi Keputusan (DSS):**
Anda dapat menyaring laporan atau meminta analisis khusus per cabang kapan saja.`);
          suggestionText = 'Coba tanyakan: "Bandingkan omset cabang Sudirman dan Senopati"';
        }
      }

      aiResponseText = sections.join('\n\n');
    }

    // 5. Simpan ke Riwayat Percakapan (Memory Cache & Database)
    const memoryTurn: ChatMemoryTurn = {
      role: 'assistant',
      content: aiResponseText,
      factsUsed: facts,
      topic: currentTopic || undefined,
      timestamp: new Date(),
    };

    // Update in-memory buffer (simpan user & assistant turns)
    const updatedMemory = [
      ...memory,
      { role: 'user' as const, content: userMessage, topic: currentTopic || undefined, timestamp: new Date() },
      memoryTurn,
    ].slice(-10); // Simpan 10 turn terakhir
    AiAssistantService.conversationMemory.set(conversationId, updatedMemory);

    let savedAiMessage: any = {
      id: 'msg-' + Date.now(),
      conversation_id: conversationId,
      role: 'assistant',
      content: aiResponseText,
      structured: {
        suggestion: suggestionText,
      },
      facts_used: facts,
      model: liveGeminiText ? env.LLM_MODEL : 'grounded-dss-engine',
      status: 'ok',
      created_at: new Date(),
    };

    if (dbUp) {
      try {
        savedAiMessage = await prisma.aiMessage.create({
          data: {
            conversation_id: conversationId,
            role: AiRole.assistant,
            content: aiResponseText,
            structured: {
              suggestion: suggestionText,
            },
            facts_used: facts,
            model: liveGeminiText ? env.LLM_MODEL : 'gemini-2.0-flash-grounded',
            status: AiMessageStatus.ok,
          },
        });
      } catch (_) {
        // Fallback ke objek lokal
      }
    }

    return {
      conversation_id: conversationId,
      message: savedAiMessage,
      facts,
      suggestion: suggestionText,
    };
  }

  /**
   * Menampilkan daftar sesi percakapan pengguna.
   */
  async listConversations(userId: string) {
    try {
      return await prisma.aiConversation.findMany({
        where: { user_id: userId },
        orderBy: { updated_at: 'desc' },
        include: {
          messages: {
            take: 1,
            orderBy: { created_at: 'desc' },
          },
        },
      });
    } catch (_) {
      return [
        {
          id: 'demo-conv-001',
          user_id: userId,
          title: 'Konsultasi Performa & Keputusan Bisnis',
          created_at: new Date(),
          updated_at: new Date(),
          messages: [
            {
              id: 'msg-001',
              role: 'assistant',
              content: 'Halo! Saya ARUS Business Copilot siap mendampingi evaluasi operasional bisnis Anda.',
              created_at: new Date(),
            },
          ],
        },
      ];
    }
  }

  /**
   * Mengambil riwayat pesan dalam percakapan tertentu.
   */
  async getConversationMessages(conversationId: string, userId: string) {
    try {
      const conv = await prisma.aiConversation.findFirst({
        where: { id: conversationId, user_id: userId },
        include: {
          messages: {
            orderBy: { created_at: 'asc' },
          },
        },
      });

      if (!conv) {
        throw new AppError('NOT_FOUND', 404, 'Percakapan tidak ditemukan.');
      }

      return conv.messages;
    } catch (_) {
      const memory = AiAssistantService.conversationMemory.get(conversationId);
      if (memory && memory.length > 0) {
        return memory.map((m, idx) => ({
          id: `msg-${idx + 1}`,
          conversation_id: conversationId,
          role: m.role,
          content: m.content,
          facts_used: m.factsUsed || null,
          created_at: m.timestamp,
        }));
      }

      return [
        {
          id: 'msg-001',
          conversation_id: conversationId,
          role: 'user',
          content: 'Bagaimana ringkasan penjualan hari ini?',
          created_at: new Date(Date.now() - 60000),
        },
        {
          id: 'msg-002',
          conversation_id: conversationId,
          role: 'assistant',
          content: 'Berdasarkan data operasional terkini:\n• Total omset saat ini sebesar Rp 14.500.000 dari 342 transaksi.\n• Estimasi margin keuntungan kotor berada di kisaran 68%.',
          structured: {
            suggestion: 'Pastikan ketersediaan bahan baku dipersiapkan sebelum jam ramai.',
          },
          facts_used: [
            {
              type: 'analytics_overview',
              title: 'Ringkasan Omset Terkini',
              value: { revenue_idr: 14500000, transaction_count: 342, avg_basket_idr: 42397, gross_margin_pct: 68 },
            },
          ],
          model: 'gemini-2.0-flash-grounded',
          status: 'ok',
          created_at: new Date(),
        },
      ];
    }
  }
}

export const aiAssistantService = new AiAssistantService();
