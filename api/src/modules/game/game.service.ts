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
}

export const gameService = new GameService();
