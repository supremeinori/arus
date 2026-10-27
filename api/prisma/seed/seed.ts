import { PrismaClient, Role } from '@prisma/client';
import * as argon2 from 'argon2';

const prisma = new PrismaClient();

async function hashPassword(password: string): Promise<string> {
  return argon2.hash(password, {
    type: argon2.argon2id,
    memoryCost: 19456, // 19 MiB
    timeCost: 2,
    parallelism: 1,
  });
}

export async function main() {
  console.log('🚀 Memulai Database Reset & Cleanup ARUS...');

  // 0. VERIFIKASI ENVIRONMENT & KEAMANAN TARGET DATABASE
  const nodeEnv = process.env.NODE_ENV || 'development';
  console.log(`🔍 Memeriksa environment target database: ${nodeEnv}`);
  if (nodeEnv === 'production' && !process.env.FORCE_RESET_CONFIRMATION) {
    throw new Error(
      '❌ OPERASI DIBATALKAN: Target database terdeteksi sebagai PRODUCTION tanpa konfirmasi eksplisit! Harap set FORCE_RESET_CONFIRMATION=true jika benar-benar dikehendaki.'
    );
  }

  // 1. RESET DATABASE: Hapus seluruh data bisnis lama & dummy
  console.log('🧹 Menghapus seluruh data bisnis lama: transaksi, riwayat shift, mutasi, stok lama, dan data dummy...');
  await prisma.gameSession.deleteMany();
  await prisma.aiChatLog.deleteMany();
  await prisma.feedback.deleteMany();
  await prisma.notification.deleteMany();
  await prisma.deviceToken.deleteMany();
  await prisma.refreshToken.deleteMany();
  await prisma.blockchainRecord.deleteMany();
  await prisma.transactionItem.deleteMany();
  await prisma.transaction.deleteMany();
  await prisma.inventoryMovement.deleteMany();
  await prisma.productRecipe.deleteMany();
  await prisma.ingredient.deleteMany();
  await prisma.product.deleteMany();
  await prisma.productCategory.deleteMany();
  await prisma.userOutlet.deleteMany();
  await prisma.outlet.deleteMany();
  await prisma.user.deleteMany();
  console.log('✨ Database berhasil dibersihkan.');

  // 2. BUAT EMPAT CABANG DENGAN IANA TIMEZONE
  console.log('🏢 Membuat 4 Cabang ARUS sesuai spesifikasi IANA Timezone...');
  const outletYogyakarta = await prisma.outlet.create({
    data: {
      name: 'Yogyakarta',
      address: 'Jl. Malioboro No. 12, Sosromenduran, Gedong Tengen, Kota Yogyakarta, D.I. Yogyakarta 55271',
      latitude: -7.797068,
      longitude: 110.370529,
      timezone: 'Asia/Jakarta',
      is_active: true,
    },
  });

  const outletDenpasar = await prisma.outlet.create({
    data: {
      name: 'Denpasar',
      address: 'Jl. Gatot Subroto Barat No. 88, Pemecutan Kaja, Kec. Denpasar Utara, Kota Denpasar, Bali 80118',
      latitude: -8.670458,
      longitude: 115.212629,
      timezone: 'Asia/Makassar',
      is_active: true,
    },
  });

  const outletJayapura = await prisma.outlet.create({
    data: {
      name: 'Jayapura',
      address: 'Jl. Percetakan Negara No. 5, Gurabesi, Kec. Jayapura Utara, Kota Jayapura, Papua 99111',
      latitude: -2.533710,
      longitude: 140.718130,
      timezone: 'Asia/Jayapura',
      is_active: true,
    },
  });

  const outletLondon = await prisma.outlet.create({
    data: {
      name: 'London',
      address: '10 Oxford Street, Fitzrovia, London W1D 1AW, United Kingdom',
      latitude: 51.507351,
      longitude: -0.127758,
      timezone: 'Europe/London',
      is_active: true,
    },
  });

  console.log('✅ 4 Cabang berhasil dibuat:');
  console.log(`   - Yogyakarta (${outletYogyakarta.timezone}) [ID: ${outletYogyakarta.id}]`);
  console.log(`   - Denpasar   (${outletDenpasar.timezone}) [ID: ${outletDenpasar.id}]`);
  console.log(`   - Jayapura   (${outletJayapura.timezone}) [ID: ${outletJayapura.id}]`);
  console.log(`   - London     (${outletLondon.timezone}) [ID: ${outletLondon.id}]`);

  // 3. BUAT ENAM AKUN PENGGUNA (Password awal: 12345678, Argon2id)
  console.log('👥 Membuat 6 akun autentikasi dengan Argon2 password hash...');
  const passwordHash = await hashPassword('12345678');

  // Akun 1: Owner (Akses semua cabang)
  const owner = await prisma.user.create({
    data: {
      name: 'Owner ARUS',
      email: 'owner@arus.com',
      password_hash: passwordHash,
      role: Role.owner,
      display_currency: 'IDR',
      is_active: true,
    },
  });

  // Akun 2: Manager 1 (Cabang yang ditugaskan: Yogyakarta)
  const manager1 = await prisma.user.create({
    data: {
      name: 'Manager 1',
      email: 'manager1@arus.com',
      password_hash: passwordHash,
      role: Role.manager,
      display_currency: 'IDR',
      is_active: true,
    },
  });
  await prisma.userOutlet.create({
    data: { user_id: manager1.id, outlet_id: outletYogyakarta.id },
  });

  // Akun 3: Kasir 1 (Yogyakarta)
  const kasir1 = await prisma.user.create({
    data: {
      name: 'Kasir 1 (Yogyakarta)',
      email: 'kasir1@arus.com',
      password_hash: passwordHash,
      role: Role.staff,
      display_currency: 'IDR',
      is_active: true,
    },
  });
  await prisma.userOutlet.create({
    data: { user_id: kasir1.id, outlet_id: outletYogyakarta.id },
  });

  // Akun 4: Kasir 2 (Denpasar)
  const kasir2 = await prisma.user.create({
    data: {
      name: 'Kasir 2 (Denpasar)',
      email: 'kasir2@arus.com',
      password_hash: passwordHash,
      role: Role.staff,
      display_currency: 'IDR',
      is_active: true,
    },
  });
  await prisma.userOutlet.create({
    data: { user_id: kasir2.id, outlet_id: outletDenpasar.id },
  });

  // Akun 5: Kasir 3 (Jayapura)
  const kasir3 = await prisma.user.create({
    data: {
      name: 'Kasir 3 (Jayapura)',
      email: 'kasir3@arus.com',
      password_hash: passwordHash,
      role: Role.staff,
      display_currency: 'IDR',
      is_active: true,
    },
  });
  await prisma.userOutlet.create({
    data: { user_id: kasir3.id, outlet_id: outletJayapura.id },
  });

  // Akun 6: Kasir 4 (London)
  const kasir4 = await prisma.user.create({
    data: {
      name: 'Kasir 4 (London)',
      email: 'kasir4@arus.com',
      password_hash: passwordHash,
      role: Role.staff,
      display_currency: 'GBP',
      is_active: true,
    },
  });
  await prisma.userOutlet.create({
    data: { user_id: kasir4.id, outlet_id: outletLondon.id },
  });

  console.log('✅ 6 Akun berhasil dibuat:');
  console.log('   - Owner:    owner (owner@arus.com)    -> Semua Cabang');
  console.log('   - Manager:  manager1 (manager1@arus.com) -> Yogyakarta');
  console.log('   - Kasir 1:  kasir1 (kasir1@arus.com)   -> Yogyakarta');
  console.log('   - Kasir 2:  kasir2 (kasir2@arus.com)   -> Denpasar');
  console.log('   - Kasir 3:  kasir3 (kasir3@arus.com)   -> Jayapura');
  console.log('   - Kasir 4:  kasir4 (kasir4@arus.com)   -> London');

  // 4. VERIFIKASI KEBERSIHAN DATABASE
  console.log('\n📊 Ringkasan Jumlah Data Database Setelah Reset:');
  const counts = {
    users: await prisma.user.count(),
    outlets: await prisma.outlet.count(),
    userOutlets: await prisma.userOutlet.count(),
    categories: await prisma.productCategory.count(),
    products: await prisma.product.count(),
    ingredients: await prisma.ingredient.count(),
    recipes: await prisma.productRecipe.count(),
    movements: await prisma.inventoryMovement.count(),
    transactions: await prisma.transaction.count(),
    transactionItems: await prisma.transactionItem.count(),
    blockchainRecords: await prisma.blockchainRecord.count(),
    notifications: await prisma.notification.count(),
    deviceTokens: await prisma.deviceToken.count(),
    refreshTokens: await prisma.refreshToken.count(),
    aiChatLogs: await prisma.aiChatLog.count(),
    gameSessions: await prisma.gameSession.count(),
  };

  console.table(counts);

  if (
    counts.transactions === 0 &&
    counts.transactionItems === 0 &&
    counts.ingredients === 0 &&
    counts.movements === 0 &&
    counts.blockchainRecords === 0 &&
    counts.outlets === 4 &&
    counts.users === 6
  ) {
    console.log('🎉 VERIFIKASI SUKSES: Database bersih, 4 cabang & 6 akun siap digunakan!');
  } else {
    throw new Error('❌ Verifikasi gagal: Kondisi data akhir tidak sesuai target!');
  }
}

main()
  .catch((e) => {
    console.error('❌ Gagal menjalankan database reset & seed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
