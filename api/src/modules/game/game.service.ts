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

export class GameService {
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
