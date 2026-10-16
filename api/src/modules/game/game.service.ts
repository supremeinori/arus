import { GameMode } from '@prisma/client';
import { prisma } from '../../config/db';
import { AppError } from '../../shared/errors';

export interface GameOption {
  key: string;
  label: string;
  value: string;
}

export interface GameQuestion {
  question_no: number;
  product_id: string;
  image_url: string;
  category_name: string;
  prompt_title: string;
  options: GameOption[];
  correct_option_key: string;
}

export interface SaveSessionInput {
  mode: GameMode;
  score: number;
  correct_count: number;
  total_questions: number;
  duration_sec: number;
}

function shuffleArray<T>(array: T[]): T[] {
  const shuffled = [...array];
  for (let i = shuffled.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
  }
  return shuffled;
}

function formatRupiah(amount: number): string {
  return `Rp ${amount.toLocaleString('id-ID')}`;
}

export interface GameScenario {
  id: string;
  title: string;
  difficulty: 'easy' | 'medium' | 'hard';
  description: string;
  options: Array<{
    id: string;
    text: string;
    points: number;
    feedback: string;
    is_best_practice: boolean;
  }>;
}

export class GameService {
  private scenarios: GameScenario[] = [
    {
      id: 'scen-01',
      title: 'Lonjakan Jam Makan Siang (Lunch Rush)',
      difficulty: 'easy',
      description: 'Antrean kasir menumpuk hingga 15 orang pada pukul 12.30 WIB. Satu mesin espresso mengalami overheat.',
      options: [
        {
          id: 'opt-1a',
          text: 'Panggil staf cadangan, buka kasir kedua, dan rekomendasikan menu signature ready-to-drink.',
          points: 100,
          feedback: 'Sangat tepat! Menjaga antrean tetap cepat dan memaksimalkan kepuasan pelanggan.',
          is_best_practice: true,
        },
        {
          id: 'opt-1b',
          text: 'Tutup pintu masuk toko sementara sampai antrean selesai.',
          points: 20,
          feedback: 'Kurang tepat. Menolak pelanggan menyebabkan kehilangan potensi omset dan reputasi buruk.',
          is_best_practice: false,
        },
        {
          id: 'opt-1c',
          text: 'Tetap layani satu per satu dengan satu mesin tanpa memberi tahu pelanggan.',
          points: 50,
          feedback: 'Pelanggan menunggu terlalu lama (>20 menit) dan memicu komplain antrean.',
          is_best_practice: false,
        },
      ],
    },
    {
      id: 'scen-02',
      title: 'Stok Susu Oat Habis Mendadak',
      difficulty: 'medium',
      description: 'Menu favorit Matcha Latte Oatmilk dipesan berturut-turut, tetapi persediaan susu oat di chiller habis total.',
      options: [
        {
          id: 'opt-2a',
          text: 'Ganti diam-diam dengan susu sapi biasa tanpa konfirmasi ke pembeli.',
          points: 0,
          feedback: 'Fatal! Pelanggan mungkin memiliki intoleransi laktosa atau alergi. Pelanggaran SOP serius.',
          is_best_practice: false,
        },
        {
          id: 'opt-2b',
          text: 'Informasikan pelanggan dengan ramah, tawarkan opsi pengganti (Susu Almond/Kedelai) dengan diskon 15%, dan buat permintaan transfer stok darurat ke cabang terdekat.',
          points: 95,
          feedback: 'SOP Excellent! Transparansi menjaga loyalitas dan mitigasi stok tercatat rapi.',
          is_best_practice: true,
        },
        {
          id: 'opt-2c',
          text: 'Langsung batalkan pesanan pelanggan dengan ketus.',
          points: 30,
          feedback: 'Kurang solutif. Kasir sebaiknya memberikan opsi alternatif sebelum membatalkan.',
          is_best_practice: false,
        },
      ],
    },
    {
      id: 'scen-03',
      title: 'Kesalahan Nominal Input Transaksi Kasir',
      difficulty: 'hard',
      description: 'Pelanggan membayar lewat QRIS Rp 45.000, tetapi kasir terburu-buru dan menginput Tunai Rp 450.000 sehingga pembukuan kas tidak seimbang.',
      options: [
        {
          id: 'opt-3a',
          text: 'Laporkan segera ke Manager, lakukan VOID transaksi resmi dengan catatan audit, dan input ulang transaksi QRIS yang benar.',
          points: 100,
          feedback: 'Sempurna! Integritas buku kas terjaga dan rekam jejak audit SHA-256 tercatat bersih.',
          is_best_practice: true,
        },
        {
          id: 'opt-3b',
          text: 'Ambil selisih uang dari dompet pribadi untuk menutupi kas tanpa melapor.',
          points: 40,
          feedback: 'Niat baik tetapi salah prosedur. Menyulitkan audit akuntansi harian dan rawan dicurigai kecurangan.',
          is_best_practice: false,
        },
        {
          id: 'opt-3c',
          text: 'Biarkan saja dan berharap Manager tidak menyadari saat closing shift.',
          points: 10,
          feedback: 'Pelanggaran integritas kerja. Selisih kas pasti terdeteksi pada rekonsiliasi akhir hari.',
          is_best_practice: false,
        },
      ],
    },
  ];

  getScenarios(): GameScenario[] {
    return this.scenarios;
  }

  submitSession(answers: Array<{ scenario_id: string; option_id: string }>) {
    let totalScore = 0;
    const details = answers.map((ans) => {
      const scen = this.scenarios.find((s) => s.id === ans.scenario_id);
      const opt = scen?.options.find((o) => o.id === ans.option_id);
      const points = opt?.points ?? 0;
      totalScore += points;
      return {
        scenario_id: ans.scenario_id,
        scenario_title: scen?.title ?? '',
        selected_option: opt?.text ?? '',
        points,
        feedback: opt?.feedback ?? '',
        is_best_practice: opt?.is_best_practice ?? false,
      };
    });

    const maxScore = answers.length * 100;
    const scorePercentage = maxScore > 0 ? Math.round((totalScore / maxScore) * 100) : 0;
    let rank = 'Barista Pemula';
    if (scorePercentage >= 90) rank = 'Master Store Manager ⭐⭐⭐';
    else if (scorePercentage >= 75) rank = 'Supervisor Handal ⭐⭐';
    else if (scorePercentage >= 50) rank = 'Kasir Kompeten ⭐';

    return {
      total_score: totalScore,
      max_score: maxScore,
      score_percentage: scorePercentage,
      rank,
      details,
      completed_at: new Date().toISOString(),
    };
  }
  /**
   * Mengambil daftar soal mini game "Guess the Menu" secara dinamis dari tabel products
   */
  async getQuestions(mode: GameMode = GameMode.guess_name, limit: number = 5): Promise<{
    mode: GameMode;
    time_limit_per_question_sec: number;
    questions: GameQuestion[];
  }> {
    // 1. Ambil semua produk aktif yang memiliki image_url
    let products = await prisma.product.findMany({
      where: {
        is_active: true,
        image_url: { not: null },
      },
      include: {
        category: true,
      },
    });

    // Fallback jika belum ada foto, ambil semua produk aktif
    if (products.length < 4) {
      products = await prisma.product.findMany({
        where: { is_active: true },
        include: { category: true },
      });
    }

    if (products.length < 2) {
      throw new AppError('GAME_INSUFFICIENT_PRODUCTS', 400, 'Katalog produk belum cukup untuk memulai permainan (minimal 2 produk aktif).');
    }

    // 2. Acak produk target
    const shuffledProducts = shuffleArray(products);
    const selectedTargets = shuffledProducts.slice(0, Math.min(limit, products.length));

    const questions: GameQuestion[] = [];

    for (let i = 0; i < selectedTargets.length; i++) {
      const target = selectedTargets[i];
      const categoryName = target.category?.name || 'Menu Toko';
      const imageUrl = target.image_url || 'https://images.unsplash.com/photo-1517701550927-30cf4ba1dba5?auto=format&fit=crop&w=500&q=80';

      if (mode === GameMode.guess_name) {
        // Mode 1: Tebak Nama Menu
        // Pengecoh: 3 nama produk lain
        const otherProducts = products.filter((p) => p.id !== target.id);
        const shuffledOthers = shuffleArray(otherProducts);
        const distractors = shuffledOthers.slice(0, 3).map((p) => p.name);

        const rawChoices = [
          { label: target.name, value: target.name, isCorrect: true },
          ...distractors.map((name) => ({ label: name, value: name, isCorrect: false })),
        ];

        const shuffledChoices = shuffleArray(rawChoices);
        const options: GameOption[] = [];
        let correctKey = 'opt_1';

        shuffledChoices.forEach((ch, idx) => {
          const key = `opt_${idx + 1}`;
          options.push({ key, label: ch.label, value: ch.value });
          if (ch.isCorrect) correctKey = key;
        });

        questions.push({
          question_no: i + 1,
          product_id: target.id,
          image_url: imageUrl,
          category_name: categoryName,
          prompt_title: 'Menu apakah yang ada pada gambar di atas?',
          options,
          correct_option_key: correctKey,
        });
      } else {
        // Mode 2: Tebak Harga Jual (guess_price)
        const correctPrice = target.price_idr;

        // Buat 3 harga pengecoh yang realistis
        const otherPrices = products
          .filter((p) => p.id !== target.id && p.price_idr !== correctPrice)
          .map((p) => p.price_idr);

        const distractorPrices: number[] = [];
        const possibleShuffled = shuffleArray(otherPrices);

        for (const p of possibleShuffled) {
          if (!distractorPrices.includes(p) && p !== correctPrice) {
            distractorPrices.push(p);
            if (distractorPrices.length >= 3) break;
          }
        }

        // Jika harga dari produk lain kurang, bangkitkan variasi harga
        const offsets = [-4000, 4000, -2000, 6000, 8000, -6000];
        for (const off of offsets) {
          if (distractorPrices.length >= 3) break;
          const candidate = Math.max(5000, correctPrice + off);
          if (candidate !== correctPrice && !distractorPrices.includes(candidate)) {
            distractorPrices.push(candidate);
          }
        }

        const rawChoices = [
          { label: formatRupiah(correctPrice), value: String(correctPrice), isCorrect: true },
          ...distractorPrices.slice(0, 3).map((price) => ({
            label: formatRupiah(price),
            value: String(price),
            isCorrect: false,
          })),
        ];

        const shuffledChoices = shuffleArray(rawChoices);
        const options: GameOption[] = [];
        let correctKey = 'opt_1';

        shuffledChoices.forEach((ch, idx) => {
          const key = `opt_${idx + 1}`;
          options.push({ key, label: ch.label, value: ch.value });
          if (ch.isCorrect) correctKey = key;
        });

        questions.push({
          question_no: i + 1,
          product_id: target.id,
          image_url: imageUrl,
          category_name: categoryName,
          prompt_title: target.name,
          options,
          correct_option_key: correctKey,
        });
      }
    }

    return {
      mode,
      time_limit_per_question_sec: 10,
      questions,
    };
  }

  /**
   * Menyimpan hasil sesi permainan mini game dan memeriksa rekor skor pribadi
   */
  async saveSession(userId: string, data: SaveSessionInput) {
    // Cari rekor tertinggi sebelumnya untuk user pada mode ini
    const previousBest = await prisma.gameSession.findFirst({
      where: {
        user_id: userId,
        mode: data.mode,
      },
      orderBy: {
        score: 'desc',
      },
    });

    const isNewHighScore = !previousBest || data.score > previousBest.score;

    const session = await prisma.gameSession.create({
      data: {
        user_id: userId,
        mode: data.mode,
        score: data.score,
        correct_count: data.correct_count,
        total_questions: data.total_questions,
        duration_sec: data.duration_sec,
      },
    });

    return {
      session,
      is_new_high_score: isNewHighScore,
      previous_high_score: previousBest?.score ?? 0,
    };
  }

  /**
   * Mengambil riwayat dan skor tertinggi pengguna
   */
  async getUserStats(userId: string) {
    const bestGuessName = await prisma.gameSession.findFirst({
      where: { user_id: userId, mode: GameMode.guess_name },
      orderBy: { score: 'desc' },
    });

    const bestGuessPrice = await prisma.gameSession.findFirst({
      where: { user_id: userId, mode: GameMode.guess_price },
      orderBy: { score: 'desc' },
    });

    const recentSessions = await prisma.gameSession.findMany({
      where: { user_id: userId },
      orderBy: { played_at: 'desc' },
      take: 10,
    });

    const totalGamesPlayed = await prisma.gameSession.count({
      where: { user_id: userId },
    });

    return {
      high_scores: {
        guess_name: bestGuessName?.score ?? 0,
        guess_price: bestGuessPrice?.score ?? 0,
      },
      total_games_played: totalGamesPlayed,
      recent_sessions: recentSessions,
    };
  }
}

export const gameService = new GameService();
