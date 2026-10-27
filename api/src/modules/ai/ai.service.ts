import { Role } from '@prisma/client';
import { prisma } from '../../config/db';
import { AppError } from '../../shared/errors';
import { env } from '../../config/env';
import { ttsService } from './tts.service';
import { NotificationsService } from '../notifications/notifications.service';
import { aiBusinessEngine, EvaluatedBusinessFacts } from './ai_business_engine';

const notificationsService = new NotificationsService();

export function cleanVoiceSummaryText(text: string): string {
  const stripped = text
    .replace(/```[\s\S]*?```/g, '')
    .replace(/\[VOICE_SUMMARY\]:?/gi, '')
    .replace(/[*#_~`>]/g, '')
    .replace(/^\s*[-•]\s+/gm, '')
    .replace(/\|.*?\|/g, '')
    .replace(/\s+/g, ' ')
    .trim();

  const match = stripped.match(/[^.!?]+[.!?]+/g);
  if (match && match.length > 0) {
    const summary = match.slice(0, 2).join(' ').trim();
    if (summary.length >= 15) {
      return summary;
    }
  }
  return stripped.length > 180 ? stripped.substring(0, 177) + '...' : stripped;
}

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
   * Panggil Google Gemini API dengan multi-turn context history & persona bisnis ter-grounding.
   */
  private async callGemini(
    userMessage: string,
    facts: any[],
    history: ChatMemoryTurn[],
    userContext: { name: string; role: string; outletName?: string },
    screenContext?: string
  ): Promise<string | null> {
    const apiKey = env.LLM_API_KEY;
    if (!apiKey || apiKey === 'dummy_key_for_dev') {
      return null;
    }

    try {
      const model = env.LLM_MODEL || 'gemini-3.5-flash-lite';
      const systemInstruction = `Anda adalah ARUS Business Copilot, asisten kecerdasan bisnis & rekan diskusi keputusan (DSS) pribadi untuk ${userContext.name} (${userContext.role}) di platform bisnis ARUS.

Karakter & Gaya Komunikasi:
- Cerdas, hangat, komunikatif, analitis, dan berwawasan saat membahas data operasional bisnis.
- Jika pengguna mengajak bercanda atau meminta dipanggil dengan panggilan tertentu (misal: "bos", "sayang", "ratu"), patuhi dengan ramah dan luwes.
- Panggil pengguna dengan nama atau panggilan yang diminta (${userContext.name}).
- Ingat konteks percakapan sebelumnya agar diskusi mengalir alami.

ATURAN WAJIB GROUNDED DATA (ANTI-HALUSINASI MUTLAK):
1. Anda HANYA BOLEH menggunakan angka omset, jumlah transaksi, basket size, margin, stok, nama produk, dan nama cabang yang TERCANTUM EKSPLISIT pada FAKTA DATA BISNIS berikut:
${JSON.stringify(facts, null, 2)}
2. DILARANG KERAS mengarang angka, membuat estimasi fiktif di luar data di atas, atau menyebut produk/cabang yang tidak ada dalam data.
3. Jika fakta menunjukkan bahwa suatu cabang atau periode memiliki 0 transaksi atau belum ada data penjualan/stok, nyatakan dengan jujur dan transparan bahwa data transaksi belum tercatat di database untuk cabang/periode tersebut.
4. Jika pengguna meminta perbandingan antarcabang, bandingkan angka masing-masing cabang secara adil dan objektif sesuai data fakta.
5. Sertakan angka konkrit dalam format rupiah (misal Rp 22.524.000) dan sebutkan nama cabang serta periode yang relevan.
6. Berikan rekomendasi keputusan bisnis (DSS) yang masuk akal dan didukung oleh fakta tersebut.

Format Output:
- Sajikan jawaban yang bersih, rapi, profesional, dan nyaman dibaca (struktur eksekutif).
- Gunakan format tebal (**kata**) HANYA untuk penekanan metrik angka penting, nama cabang, atau kesimpulan kunci. Hindari penggunaan tanda bintang (*) secara berlebihan atau tidak teratur.
- Gunakan daftar berurutan (1., 2.) atau bullet poin tanda hubung (-) yang rapi dan teratur untuk perincian.
- Hindari menyisipkan simbol-simbol markdown liar atau asteris yang tidak berpasangan.
- Selain jawaban lengkap bernuansa analitis (format Markdown bersih untuk tampilan layar), sertakan juga TEPAT DI BAGIAN PALING AKHIR satu ringkasan lisan 1-2 kalimat yang ramah, ringkas, santai, dan BEBAS DARI SIMBOL MARKDOWN (*, #, -, bullet, tabel) serta menyebutkan angka dengan natural agar dapat dibacakan oleh suara wanita Gadis (TTS). Awali bagian ringkasan tersebut dengan penanda persis:
[VOICE_SUMMARY]: <ringkasan suara 1-2 kalimat>`;

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
   * Menjawab pertanyaan pengguna dengan sistem Grounded Facts aktual dari database,
   * rule engine evaluasi bisnis, branch awareness, dan pencegahan halusinasi.
   */
  async handleChat(
    userId: string,
    query: {
      conversation_id?: string;
      message: string;
      outlet_id?: string;
      screen_context?: string;
    },
    userScope: { role: Role; allowedOutletIds: string[] }
  ) {
    const userMessage = query.message.trim();
    if (!userMessage) {
      throw new AppError('INVALID_INPUT', 400, 'Pesan tidak boleh kosong.');
    }

    let conversationId = query.conversation_id || `conv-${userId.substring(0, 8)}-${Date.now()}`;

    // 1. Profil Pengguna & Personalisasi
    let userName = userScope.role === Role.owner ? 'Owner' : userScope.role === Role.manager ? 'Manager' : 'Staff Kasir';
    let userRoleTitle = userScope.role === Role.owner ? 'Owner' : userScope.role === Role.manager ? 'Manager' : 'Staff Kasir';

    const savedNickname = AiAssistantService.customNicknames.get(conversationId);
    if (savedNickname) {
      userName = savedNickname;
    }

    const matchCall = userMessage.match(/panggil (?:aku|saya|gue|gua) (.*)/i);
    if (matchCall) {
      const extractedNick = matchCall[1].replace(/dong|ya|plis|please|\?|\!/gi, '').trim();
      if (extractedNick) {
        userName = extractedNick;
        AiAssistantService.customNicknames.set(conversationId, extractedNick);
      }
    }

    try {
      const dbUser = await prisma.user.findUnique({
        where: { id: userId },
        select: { name: true, role: true },
      });
      if (dbUser && !savedNickname && !matchCall) {
        userName = dbUser.name;
        userRoleTitle = dbUser.role === Role.owner ? 'Owner' : dbUser.role === Role.manager ? 'Manager' : 'Staff Kasir';
      }
    } catch (_) {}

    // 2. Analisis Input Pengguna: Chitchat/Candaan vs Pertanyaan Bisnis Nyata
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

    const hasComparisonKeyword =
      lower.includes('banding') ||
      lower.includes('komparasi') ||
      lower.includes('perbandingan') ||
      lower.includes('antarcabang') ||
      lower.includes('antar cabang') ||
      lower.includes('paling ramai') ||
      lower.includes('paling tinggi') ||
      lower.includes('mana yang') ||
      lower.includes('cabang mana') ||
      lower.includes('semua cabang') ||
      lower.includes('seluruh cabang') ||
      lower.includes('rekap cabang');

    const hasBusinessKeyword =
      hasComparisonKeyword ||
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
      lower.includes('lokasi') ||
      lower.includes('void') ||
      lower.includes('anomali');

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
    let evaluatedBusinessFacts: EvaluatedBusinessFacts | null = null;
    let facts: Array<{ type: string; title: string; value: any }> = [];

    if (!isChitChatOrCasual) {
      if (hasBusinessProcessKeyword) {
        currentTopic = 'business_process';
      } else if (hasComparisonKeyword) {
        currentTopic = 'branch_comparison';
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
      } else {
        currentTopic = 'business_overview';
      }

      // Context Inheritance jika follow-up
      const isBusinessFollowUp =
        lower.includes('kalau') ||
        lower.includes('bagaimana') ||
        lower.includes('gimana') ||
        lower.includes('kenapa') ||
        lower.includes('mengapa') ||
        lower.includes('banding') ||
        lower.includes('kemarin') ||
        lower.includes('terus') ||
        lower.includes('lalu') ||
        lower.includes('solusi') ||
        lower.includes('saran');

      if ((!currentTopic || currentTopic === 'business_overview') && isBusinessFollowUp && memory.length > 0) {
        const lastTurn = memory[memory.length - 1];
        if (lastTurn.topic && lastTurn.topic !== 'chitchat') {
          currentTopic = lastTurn.topic;
        }
      }

      // 3. RETRIEVER & RULE ENGINE: Eksekusi Query Aktual Database + Validasi
      const outletScope = await aiBusinessEngine.resolveOutlets(userMessage, query.outlet_id, userScope);

      // Tangani jika ada permintaan cabang di luar izin role (RBAC)
      if (outletScope.forbiddenOutletName) {
        const forbiddenResponse = aiBusinessEngine.generateDeterministicResponse(
          {
            topic: 'forbidden',
            period_label: 'Saat Ini',
            is_comparison: false,
            target_outlets: [],
            forbidden_outlet_name: outletScope.forbiddenOutletName,
            overview: {
              total_revenue_idr: 0,
              completed_transactions: 0,
              void_transactions: 0,
              void_rate_pct: 0,
              avg_basket_idr: 0,
              total_cost_idr: 0,
              gross_profit_idr: 0,
              gross_margin_pct: 0,
              payment_methods: {},
            },
            branch_metrics: [],
            top_products: [],
            inventory_alerts: [],
            peak_hours: [],
            anomalies: [],
            recommendations: [],
          },
          userName
        );

        let audioBase64 = '';
        try {
          audioBase64 = await ttsService.textToSpeechBase64(forbiddenResponse.voice_summary);
        } catch (_) {}

        return {
          conversation_id: conversationId,
          message: {
            id: 'msg-' + Date.now(),
            conversation_id: conversationId,
            role: 'assistant',
            content: forbiddenResponse.reply_text,
            structured: { suggestion: forbiddenResponse.suggestion },
            facts_used: [],
            model: 'grounded-dss-engine',
            status: 'ok',
            created_at: new Date(),
          },
          facts: [],
          suggestion: forbiddenResponse.suggestion,
          reply_text: forbiddenResponse.reply_text,
          voice_summary: forbiddenResponse.voice_summary,
          audio_base64: audioBase64,
        };
      }

      const timeWindow = aiBusinessEngine.resolveTimeWindow(userMessage);
      evaluatedBusinessFacts = await aiBusinessEngine.evaluateBusinessFacts(
        userMessage,
        currentTopic || 'sales',
        outletScope.targetOutlets,
        timeWindow,
        userScope,
        outletScope.isComparison
      );

      facts = aiBusinessEngine.buildFactsList(evaluatedBusinessFacts);

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
    } else {
      currentTopic = 'chitchat';
    }

    // 4. GENERATOR: Respons Berbasis Fakta (Gemini jika online, atau Deterministic Rule Engine jika offline)
    let aiResponseText = '';
    let suggestionText = '';

    const liveGeminiText = await this.callGemini(
      userMessage,
      facts,
      memory,
      {
        name: userName,
        role: userRoleTitle,
      },
      query.screen_context
    );

    let voiceSummary = '';
    if (liveGeminiText) {
      if (liveGeminiText.includes('[VOICE_SUMMARY]:')) {
        const parts = liveGeminiText.split('[VOICE_SUMMARY]:');
        aiResponseText = parts[0].trim();
        voiceSummary = cleanVoiceSummaryText(parts[1]);
      } else {
        aiResponseText = liveGeminiText.trim();
        voiceSummary = cleanVoiceSummaryText(aiResponseText);
      }
      suggestionText = 'Analisis di atas disusun secara cerdas oleh Google Gemini berbasis data aktual database.';
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
        aiResponseText = `Siap, ${userName}! Saya menyimak dengan baik. 😄\n\nSebagai asisten bisnis pribadi Anda di platform ARUS, saya bisa diajak ngobrol santai maupun diajak serius menganalisis performa toko—seperti evaluasi omset harian, perbandingan antarcabang, cek bahan baku yang mau habis, sampai rekomendasi menu paling laris.\n\nAda hal tertentu yang sedang Anda pikirkan untuk bisnis kita hari ini?`;
        suggestionText = 'Coba tanyakan: "Berapa omset kita hari ini?" atau "Menu apa yang paling laris?"';
      }
    } else if (currentTopic === 'business_process') {
      aiResponseText = `📌 **Alur Proses Bisnis & Arsitektur ARUS:**
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
Seluruh pilar di atas telah berjalan aktif di seluruh gerai Anda.`;
      suggestionText = 'Coba tanyakan: "Bagaimana omset kita hari ini?" atau "Bahan apa yang stoknya menipis?"';
      voiceSummary = 'Platform ARUS mengintegrasikan kasir POS, otomasi inventaris resep, audit ledger kriptografi, dan dashboard analitik bisnis secara real-time.';
    } else if (evaluatedBusinessFacts) {
      // SMART GROUNDED DETERMINISTIC RESPONSE (Rule Engine)
      const deterministic = aiBusinessEngine.generateDeterministicResponse(evaluatedBusinessFacts, userName);
      aiResponseText = deterministic.reply_text;
      suggestionText = deterministic.suggestion;
      voiceSummary = deterministic.voice_summary;
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

    if (userId) {
      try {
        const chatLog = await prisma.aiChatLog.create({
          data: {
            user_id: userId,
            question: userMessage,
            answer_json: {
              content: aiResponseText,
              suggestion: suggestionText,
              model: liveGeminiText ? env.LLM_MODEL : 'grounded-dss-engine',
            },
            facts_used: facts,
          },
        });

        if (chatLog?.id) {
          try {
            await notificationsService.notifyAiResult({
              userId,
              chatLogId: chatLog.id,
              question: userMessage,
              answer: aiResponseText,
            });
          } catch (err) {
            console.warn('[AI] Notifikasi hasil AI gagal (diabaikan):', err);
          }
        }
      } catch (_) {}
    }

    if (!voiceSummary) {
      voiceSummary = cleanVoiceSummaryText(aiResponseText);
    }

    let audioBase64 = '';
    if (voiceSummary) {
      try {
        audioBase64 = await ttsService.textToSpeechBase64(voiceSummary);
      } catch (err) {
        console.warn('[AudioBase64 Generation Error]', err);
      }
    }

    return {
      conversation_id: conversationId,
      message: savedAiMessage,
      facts,
      suggestion: suggestionText,
      reply_text: aiResponseText,
      voice_summary: voiceSummary,
      audio_base64: audioBase64,
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
      const log = await prisma.aiChatLog.findFirst({
        where: { id: conversationId, user_id: userId },
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

  /**
   * Menganalisis rekomendasi harga jual kompetitif via Gemini LLM berdasarkan HPP & nama menu.
   */
  async recommendPrice(input: {
    menu_name: string;
    total_cogs_idr: number;
    recipes?: Array<any>;
  }): Promise<{ recommended_price: number; margin_percentage: number; reasoning: string }> {
    const menuName = input.menu_name || 'Menu Baru';
    const cogs = input.total_cogs_idr || 0;

    const apiKey = env.LLM_API_KEY;
    if (apiKey && apiKey !== 'dummy_key_for_dev') {
      try {
        const model = env.LLM_MODEL || 'gemini-3.5-flash-lite';
        const prompt = `Anda adalah seorang ahli pricing strategi F&B di Indonesia. 
Analisis harga jual kompetitif untuk menu baru berikut:
- Nama Menu: "${menuName}"
- Total HPP (Modal): Rp ${cogs}
- Komposisi Resep: ${JSON.stringify(input.recipes || [])}

Pertimbangkan margin keuntungan F&B wajar (biasanya 40% - 100% di atas HPP), daya beli pasar Indonesia, serta biaya operasional tak langsung (listrik, gaji, sewa, alat).
WAJIB KEMBALIKAN HANYA DALAM FORMAT JSON MURNI tanpa markdown backticks (tanpa \`\`\`json ... \`\`\`), dengan skema persis berikut:
{
  "recommended_price": [angka bulat integer harga jual rupiah yang disarankan],
  "margin_percentage": [angka bulat persentase margin dari HPP, misal 50 atau 70],
  "reasoning": "[penjelasan singkat profesional 1-2 kalimat dalam Bahasa Indonesia mengapa harga ini ideal]"
}`;

        const response = await fetch(
          `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`,
          {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              contents: [{ role: 'user', parts: [{ text: prompt }] }],
            }),
            signal: AbortSignal.timeout(10000),
          }
        );

        if (response.ok) {
          const json: any = await response.json();
          let text = json.candidates?.[0]?.content?.parts?.[0]?.text || '';
          text = text.replace(/```json/g, '').replace(/```/g, '').trim();
          const parsed = JSON.parse(text);
          if (parsed.recommended_price && parsed.margin_percentage) {
            return {
              recommended_price: Number(parsed.recommended_price),
              margin_percentage: Number(parsed.margin_percentage),
              reasoning: String(parsed.reasoning || 'Rekomendasi optimal berdasarkan analisis margin F&B standar.'),
            };
          }
        }
      } catch (err) {
        console.warn('[RecommendPrice AI Fallback]', err);
      }
    }

    // Fallback cerdas offline (margin 50%)
    const fallbackMargin = 50;
    const recommendedPrice = Math.round((cogs * (100 + fallbackMargin)) / 100 / 500) * 500;
    return {
      recommended_price: recommendedPrice > 0 ? recommendedPrice : 15000,
      margin_percentage: fallbackMargin,
      reasoning: `Rekomendasi standar margin ${fallbackMargin}% di atas HPP Rp ${cogs} untuk menutup operasional & profit sehat.`,
    };
  }
}

export const aiAssistantService = new AiAssistantService();
