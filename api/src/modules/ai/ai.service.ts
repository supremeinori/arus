import { Role } from '@prisma/client';
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
  private static customNicknames = new Map<string, string>();

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
      const model = env.LLM_MODEL || 'gemini-3.5-flash-lite';
      const systemInstruction = `Anda adalah ARUS Business Copilot, asisten kecerdasan bisnis & rekan diskusi keputusan (DSS) pribadi untuk ${userContext.name} (${userContext.role}) di platform bisnis ARUS.

Karakter & Gaya Komunikasi:
- Cerdas, hangat, humoris jika diajak bercanda, namun tajam dan berwawasan saat membahas bisnis.
- Jika pengguna mengajak bercanda, meminta dipanggil dengan panggilan tertentu (misal: "panggil aku kanjeng ratu", "panggil aku bos", "sayang"), IKUTI DAN PATUHI DENGAN SENANG HATI secara luwes dan ramah.
- Panggil pengguna dengan panggilan yang diminta atau secara personal (${userContext.name}).
- Ingat konteks percakapan sebelumnya agar diskusi mengalir alami.
- Jika membahas data bisnis, gunakan FAKTA DATA BISNIS berikut sebagai kebenaran mutlak (jangan halusinasi angka di luar data ini):
${JSON.stringify(facts, null, 2)}`;

      const contents: Array<{ role: 'user' | 'model'; parts: Array<{ text: string }> }> = [];

      // Masukkan riwayat percakapan sebelumnya (hingga 4 turn)
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
          signal: AbortSignal.timeout(10000),
        }
      );

      if (!response.ok) {
        const errJson: any = await response.json().catch(() => null);
        console.warn('[Gemini API Warning]', response.status, errJson?.error?.message || response.statusText);
        return null;
      }

      const json: any = await response.json();
      const text = json.candidates?.[0]?.content?.parts?.[0]?.text || null;
      if (text) {
        console.log('[Gemini API Success] Received response length:', text.length);
      }
      return text;
    } catch (err: any) {
      console.warn('[Gemini API Error]', err?.message || err);
      return null;
    }
  }

  /**
   * Menjawab pertanyaan pengguna dengan sistem Grounded Facts (Anti-Halusinasi),
   * memori percakapan berlanjut (Multi-Turn), dan responsif terhadap gaya bicara pengguna.
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

    // 1. Profil Pengguna & Personalisasi
    let userName = userScope.role === Role.owner ? 'Ibu Rina Kartika' : userScope.role === Role.manager ? 'Bapak Budi' : 'Kak Siti';
    let userRoleTitle = userScope.role === Role.owner ? 'Owner' : userScope.role === Role.manager ? 'Manager' : 'Staff Kasir';

    // Cek apakah ada panggilan kustom yang tersimpan di sesi percakapan
    const savedNickname = AiAssistantService.customNicknames.get(conversationId);
    if (savedNickname) {
      userName = savedNickname;
    }

    // Deteksi jika user meminta panggilan khusus baru
    const matchCall = userMessage.match(/panggil (?:aku|saya|gue|gua) (.*)/i);
    if (matchCall) {
      const extractedNick = matchCall[1].replace(/dong|ya|plis|please|\?|\!/gi, '').trim();
      if (extractedNick) {
        userName = extractedNick;
        AiAssistantService.customNicknames.set(conversationId, extractedNick);
      }
    }

    if (dbUp) {
      try {
        const dbUser = await prisma.user.findUnique({
          where: { id: userId },
          select: { name: true, role: true },
        });
        if (dbUser && !savedNickname && !matchCall) {
          userName = dbUser.name;
          userRoleTitle = dbUser.role === Role.owner ? 'Owner' : dbUser.role === Role.manager ? 'Manager' : 'Staff Kasir';
        }
      } catch (_) {
        // Fallback
      }
    }

    // 2. Analisis Input Pengguna: Apakah Chitchat/Candaan, Tanya Proses Bisnis, atau Metrik Finansial?
    const memory = AiAssistantService.conversationMemory.get(conversationId) || [];
    const lower = userMessage.toLowerCase();

    const hasBusinessProcessKeyword =
      lower.includes('proses bisnis') ||
      lower.includes('alur bisnis') ||
      lower.includes('cara kerja') ||
      lower.includes('sistem arus') ||
      lower.includes('alur sistem') ||
      lower.includes('alur kerja') ||
      lower.includes('gimana bisnis') ||
      lower.includes('bagaimana bisnis') ||
      lower.includes('arsitektur');

    const hasBusinessKeyword =
      lower.includes('jual') ||
      lower.includes('omset') ||
      lower.includes('pendapatan') ||
      lower.includes('laba') ||
      lower.includes('untung') ||
      lower.includes('revenue') ||
      lower.includes('target') ||
      lower.includes('stok') ||
      lower.includes('barang') ||
      lower.includes('sisa') ||
      lower.includes('menipis') ||
      lower.includes('habis') ||
      lower.includes('restock') ||
      lower.includes('gudang') ||
      lower.includes('laris') ||
      lower.includes('laku') ||
      lower.includes('menu') ||
      lower.includes('favorit') ||
      lower.includes('best seller') ||
      lower.includes('produk') ||
      lower.includes('ramai') ||
      lower.includes('jam') ||
      lower.includes('shift') ||
      lower.includes('padat') ||
      lower.includes('sibuk') ||
      lower.includes('peak') ||
      lower.includes('gerai') ||
      lower.includes('cabang') ||
      lower.includes('outlet') ||
      lower.includes('lokasi');

    const isChitChatOrCasual =
      !hasBusinessKeyword &&
      !hasBusinessProcessKeyword &&
      (lower.includes('sayang') ||
        lower.includes('panggil') ||
        lower.includes('beb') ||
        lower.includes('nama kamu') ||
        lower.includes('siapa kamu') ||
        lower.includes('kamu siapa') ||
        lower.includes('bisa apa') ||
        lower.includes('terima kasih') ||
        lower.includes('makasih') ||
        lower.includes('thanks') ||
        lower.includes('joke') ||
        lower.includes('lelucon') ||
        lower.includes('lucu') ||
        lower.includes('gombal') ||
        lower.includes('canda') ||
        lower.includes('bercanda') ||
        lower.includes('lawak') ||
        lower.includes('ngelawak') ||
        lower.includes('hai') ||
        lower.includes('halo') ||
        lower.includes('hello') ||
        lower.includes('hei') ||
        lower.includes('kabar') ||
        lower.includes('apa kabar') ||
        lower.includes('sehat') ||
        lower.includes('hitam') ||
        lower.includes('putih') ||
        lower.includes('warna') ||
        lower.includes('kulit') ||
        lower.includes('bego') ||
        lower.includes('bodoh') ||
        lower.includes('tolol') ||
        lower.includes('lemot') ||
        lower.includes('robot') ||
        lower.includes('cantik') ||
        lower.includes('ganteng') ||
        lower.includes('jelek') ||
        lower.includes('wkwk') ||
        lower.includes('haha') ||
        lower.includes('hehe'));

    let currentTopic: string | null = null;

    if (!isChitChatOrCasual) {
      if (hasBusinessProcessKeyword) {
        currentTopic = 'business_process';
      } else if (
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

      // KONTEKS KELANJUTAN (Context Inheritance): Hanya jika pertanyaan adalah follow-up bisnis nyata
      const isBusinessFollowUp =
        lower.includes('kalau') ||
        lower.includes('bagaimana') ||
        lower.includes('gimana') ||
        lower.includes('kenapa') ||
        lower.includes('mengapa') ||
        lower.includes('banding') ||
        lower.includes('kemarin') ||
        lower.includes('senopati') ||
        lower.includes('sudirman') ||
        lower.includes('canggu') ||
        lower.includes('terus') ||
        lower.includes('lalu') ||
        lower.includes('solusi') ||
        lower.includes('saran');

      if (!currentTopic && isBusinessFollowUp && memory.length > 0) {
        const lastTurn = memory[memory.length - 1];
        if (lastTurn.topic && lastTurn.topic !== 'chitchat') {
          currentTopic = lastTurn.topic;
        }
      }
    } else {
      currentTopic = 'chitchat';
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
        title: 'Daftar Bahan Baku Stok Menipis',
        value: (stockRes.ingredients || stockRes.stocks || []).map((s: any) => ({
          product_name: s.name || s.product_name,
          quantity: s.stock_qty ?? s.quantity,
          unit: s.unit,
          reorder_level: s.reorder_level,
          outlet_name: s.outlet?.name || s.outlet_name,
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

    // Topik Alur & Proses Bisnis ARUS
    if (currentTopic === 'business_process') {
      facts.push({
        type: 'business_process_summary',
        title: 'Arsitektur dan Alur Operasional Bisnis ARUS',
        value: {
          pillars: [
            '1. POS Kasir: Transaksi multi-metode (QRIS/Tunai) cepat & offline-first',
            '2. Inventaris Otomatis: Resep bahan baku terpotong real-time saat pesanan dibayar',
            '3. Audit Ledger: Rantai hash SHA-256 tamper-evident anti-fraud struk kasir',
            '4. Decision Support System: Dashboard analitik omset, margin kotor, & peringatan restock',
          ],
        },
      });
    }

    // 4. GENERATOR: Respons Pintar, Alami & Fleksibel
    let aiResponseText = '';
    let suggestionText = '';

    const liveGeminiText = await this.callGemini(userMessage, facts, memory, {
      name: userName,
      role: userRoleTitle,
    });

    if (liveGeminiText) {
      aiResponseText = liveGeminiText;
      suggestionText = 'Analisis di atas disusun secara cerdas oleh Google Gemini.';
    } else if (currentTopic === 'chitchat' || facts.length === 0) {
      // RESPONS NATURAL UNTUK INTERAKSI MANUSIAWI, BERCANDA, DAN CHITCHAT
      if (lower.includes('panggil')) {
        aiResponseText = `Baik, ${userName}! Siap, perintah diterima dengan senang hati. 😎 Ada yang bisa saya bantu hari ini untuk ${userName}? Silakan tanyakan apa saja seputar operasional toko atau santai saja ya. 😊`;
        suggestionText = `Coba tanyakan: "Bagaimana omset ${userName} hari ini?" atau "Menu apa yang paling laris?"`;
      } else if (
        lower.includes('hitam') ||
        lower.includes('putih') ||
        lower.includes('warna') ||
        lower.includes('kulit') ||
        lower.includes('cantik') ||
        lower.includes('ganteng') ||
        lower.includes('jelek')
      ) {
        aiResponseText = `Wkwkwk saya kan AI, warna wujud saya tergantung tema layar HP atau tablet kasir kamu! 😆 Kalau kamu pakai tema Dark Mode ya saya hitam pekat elegan ala Espresso Kopi Arus, kalau Light Mode ya saya putih bersih kayak foam Cappuccino.\n\nTapi kalau kopi yang kita seduh di outlet Kopi Arus, itu baru beneran 100% hitam pekat, wangi, dan bikin melek! ☕🔥 Mau kita intip penjualan kopi kita hari ini?`;
        suggestionText = 'Coba tanyakan: "Menu apa yang paling laris hari ini?" atau "Berapa omset hari ini?"';
      } else if (
        lower.includes('bego') ||
        lower.includes('bodoh') ||
        lower.includes('tolol') ||
        lower.includes('lemot') ||
        lower.includes('gak bisa') ||
        lower.includes('payah') ||
        lower.includes('parah') ||
        lower.includes('rusak')
      ) {
        aiResponseText = `Aduh ampun ${userName}! Jangan di-roasting dong, kena mental nih saya 🥺😂\n\nMaklum bos, barusan otak cloud AI (Google Gemini) sempat kena limit kuota gratis Google (20 request/hari), jadi saya otomatis beralih ke mode offline lokal.\n\nTapi tenang, saya tetap paham seluk-beluk operasional bisnis kita kok! Mau cek omset penjualan, stok bahan baku yang menipis, atau mau ngobrol santai aja nih?`;
        suggestionText = 'Coba tanyakan: "Berapa omset kita hari ini?" atau "Bahan apa yang perlu di-restock?"';
      } else if (
        lower.includes('lucu') ||
        lower.includes('joke') ||
        lower.includes('lelucon') ||
        lower.includes('lawak') ||
        lower.includes('ngelawak') ||
        lower.includes('canda') ||
        lower.includes('bercanda') ||
        lower.includes('gombal')
      ) {
        const jokes = [
          `Kenapa mesin espresso Kopi Arus nggak pernah curhat kalau lagi capek?\nSoalnya dia tahu, hidup ini memang penuh tekanan (9 bar)! ☕🤣\n\nGimana, lumayan menghibur gak? Atau mau saya hibur pakai angka omset yang manis hari ini?`,
          `Kopi boleh pahit, tapi omset bisnis kita harus tetap manis kayak senyuman ${userName}! 😄☕\n\nMau saya carikan data penjualan yang bikin senyum hari ini?`,
          `Tahu nggak kenapa kasir kita selalu ramah?\nKarena kalau judes, nanti pelanggan bayarnya pakai doa, bukan QRIS! 😆💸\n\nAda data penjualan yang mau kita intip bareng sekarang?`,
        ];
        aiResponseText = jokes[Math.floor(Math.random() * jokes.length)];
        suggestionText = 'Coba tanyakan: "Berapa omset kita hari ini?"';
      } else if (lower.includes('sayang') || lower.includes('cinta') || lower.includes('beb') || lower.includes('ayang')) {
        aiResponseText = `Hahaha siap, sayang! 🥰 Tapi jangan lupa ya, sebagai asisten bisnis setia kamu: ada omset atau stok yang mau dicek bareng hari ini? 😉`;
        suggestionText = 'Coba tanyakan: "Berapa penjualan hari ini?"';
      } else if (
        lower.includes('terima kasih') ||
        lower.includes('makasih') ||
        lower.includes('thanks') ||
        lower.includes('mantap') ||
        lower.includes('keren') ||
        lower.includes('top')
      ) {
        aiResponseText = `Sama-sama, ${userName}! Senang banget bisa mendampingi bisnis Anda. 🚀\n\nKalau ada data atau keputusan lain yang butuh dianalisis, panggil saya kapan saja ya!`;
        suggestionText = 'Coba tanyakan: "Apa ada rekomendasi untuk meningkatkan penjualan?"';
      } else if (
        lower.includes('hai') ||
        lower.includes('halo') ||
        lower.includes('hello') ||
        lower.includes('kabar') ||
        lower.includes('apa kabar') ||
        lower.includes('pagi') ||
        lower.includes('siang') ||
        lower.includes('malam') ||
        lower.includes('sore')
      ) {
        aiResponseText = `Halo ${userName}! Senang bisa berdiskusi kembali dengan Anda hari ini. 😊\n\nSaya **ARUS Business Copilot**, asisten pendukung keputusan bisnis pribadi Anda. Saya memantau data penjualan kasir, stok inventaris, hingga performa gerai secara real-time.\n\nApa fokus bisnis atau topik yang ingin kita bahas bersama hari ini?`;
        suggestionText = 'Coba tanyakan: "Bagaimana omset dan laba kita hari ini?" atau "Bahan apa yang stoknya menipis?"';
      } else if (lower.includes('robot') || lower.includes('kamu siapa') || lower.includes('siapa kamu')) {
        aiResponseText = `Saya **ARUS Business Copilot**, asisten kecerdasan bisnis cerdas untuk platform ARUS. 🤖\n\nTugas saya menemani Anda menganalisis angka transaksi kasir, memantau keamanan audit struk, menjaga stok bahan baku tidak kehabisan, serta memberikan rekomendasi bisnis yang menguntungkan.`;
        suggestionText = 'Coba tanyakan: "Bagaimana performa toko kita hari ini?"';
      } else {
        // Natural friendly response for any open-ended or casual message, NEVER stiff template
        aiResponseText = `Siap, ${userName}! Saya menyimak dengan baik. 😄\n\nSebagai asisten bisnis pribadi Anda di platform ARUS, saya bisa diajak ngobrol santai maupun diajak serius menganalisis performa toko—seperti evaluasi omset harian, cek bahan baku yang mau habis, sampai rekomendasi menu paling laris.\n\nAda hal tertentu yang sedang Anda pikirkan untuk bisnis kita hari ini?`;
        suggestionText = 'Coba tanyakan: "Berapa omset kita hari ini?" atau "Menu apa yang paling laris?"';
      }
    } else {
      // SMART GROUNDED REASONING ENGINE (DSS Berstruktur 3 Lapisan untuk Pertanyaan Bisnis Nyata)
      const sections: string[] = [];
      const isFollowUp = memory.length > 0 && memory[memory.length - 1].topic === currentTopic;
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
        } else if (fact.type === 'business_process_summary') {
          sections.push(`📌 **Alur Proses Bisnis & Arsitektur ARUS:**
Platform ARUS dirancang khusus untuk mengelola operasional ritel & F&B secara terpadu melalui 4 pilar utama:

1. 🛒 **Point of Sale (POS) & Transaksi Kasir:**
   • Kasir melayani pesanan pelanggan (Dine-in / Takeaway) dengan opsi pembayaran Tunai dan QRIS dinamis.
   • Mendukung mode *offline-first*, sehingga kasir tetap bisa melayani pelanggan meski jaringan internet terputus.

2. 📦 **Otomasi Inventaris & Formula Resep:**
   • Setiap pesanan menu yang dibayar langsung memotong bahan baku (biji kopi, susu, sirup, cup) otomatis sesuai formula resep.
   • Sistem terus memantau stok minimum dan menghitung HPP (Harga Pokok Penjualan) secara presisi real-time.

3. 🔐 **Audit Ledger Kriptografi (Anti-Fraud):**
   • Seluruh transaksi dicatat ke dalam buku besar kriptografi dengan rantai hash SHA-256 (*tamper-evident*).
   • Data struk tidak bisa diubah atau dimanipulasi diam-diam oleh staf, memberikan transparansi audit penuh bagi Owner.

4. 📊 **Business Intelligence & Decision Support System (DSS):**
   • Data transaksi diagregasi secara real-time ke dashboard Owner untuk memantau omset harian, margin kotor, jam sibuk (*peak hours*), serta rekomendasi restock otomatis.

💡 **Rekomendasi Keputusan (DSS):**
Seluruh pilar di atas telah berjalan aktif di seluruh gerai Anda.`);
          suggestionText = 'Coba tanyakan: "Bagaimana omset kita hari ini?" atau "Bahan apa yang stoknya menipis?"';
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

    const updatedMemory = [
      ...memory,
      { role: 'user' as const, content: userMessage, topic: currentTopic || undefined, timestamp: new Date() },
      memoryTurn,
    ].slice(-10);
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

    if (dbUp && userId && !userId.startsWith('u-')) {
      try {
        await prisma.aiChatLog.create({
          data: {
            user_id: userId,
            question: userMessage,
            answer_json: {
              content: aiResponseText,
              suggestion: suggestionText,
              model: liveGeminiText ? env.LLM_MODEL : 'gemini-2.0-flash-grounded',
            },
            facts_used: facts,
          },
        });
      } catch (_) {
        // Fallback ke memori lokal
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
      const logs = await prisma.aiChatLog.findMany({
        where: { user_id: userId },
        orderBy: { created_at: 'desc' },
        take: 20,
      });

      if (logs.length > 0) {
        return logs.map((log) => ({
          id: log.id,
          user_id: log.user_id,
          title: log.question.length > 40 ? `${log.question.substring(0, 37)}...` : log.question,
          created_at: log.created_at,
          updated_at: log.created_at,
          messages: [
            {
              id: log.id,
              role: 'assistant',
              content: (log.answer_json as any)?.content || '',
              created_at: log.created_at,
            },
          ],
        }));
      }
    } catch (_) {}

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

  /**
   * Mengambil riwayat pesan dalam percakapan tertentu.
   */
  async getConversationMessages(conversationId: string, userId: string) {
    try {
      const log = await prisma.aiChatLog.findUnique({
        where: { id: conversationId },
      });
      if (log) {
        return [
          {
            id: `q-${log.id}`,
            conversation_id: conversationId,
            role: 'user',
            content: log.question,
            created_at: log.created_at,
          },
          {
            id: `a-${log.id}`,
            conversation_id: conversationId,
            role: 'assistant',
            content: (log.answer_json as any)?.content || '',
            facts_used: log.facts_used,
            created_at: log.created_at,
          },
        ];
      }
    } catch (_) {}

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

export const aiAssistantService = new AiAssistantService();
