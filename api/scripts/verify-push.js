/**
 * Verifikasi konfigurasi push notifikasi FCM tanpa perlu device.
 *
 * Jalankan dari folder api/:
 *   npm run verify:push
 *
 * Fungsi:
 *  1. Mengecek 3 env var service account (FIREBASE_*).
 *  2. Kalau terisi, mencoba mengirim pesan ke token dummy.
 *     - FCM membalas "invalid/unregistered token"  -> kredensial VALID.
 *     - FCM membalas error auth / service account   -> kredensial SALAH.
 *  3. Menampilkan daftar device token yang sudah terdaftar di database,
 *     sehingga bisa dicek apakah token HP sudah masuk.
 *
 * Script ini tidak mengirim push apa pun ke user mana pun.
 */
require('dotenv').config();

const admin = require('firebase-admin');

const DUMMY_TOKEN = 'dummy-token-for-credential-check-only';

function mask(value) {
  if (!value) return 'KOSONG';
  const s = String(value);
  if (s.length <= 12) return 'TERISI';
  return `${s.slice(0, 6)}…${s.slice(-4)} (${s.length} karakter)`;
}

/**
 * Sama dengan normalizePrivateKey() di src/modules/push/push.service.ts.
 * Script ini berdiri sendiri (CJS) sehingga normalisasinya diduplikasi di sini.
 */
function normalizePrivateKey(raw) {
  if (!raw) return '';
  return raw
    .replace(/\\n/g, '\n')
    .replace(/\r\n/g, '\n')
    .trim()
    .replace(/^["']/, '')
    .replace(/["'],?$/, '')
    .trim();
}

async function listDeviceTokens() {
  try {
    const { PrismaClient } = require('@prisma/client');
    const prisma = new PrismaClient();
    const rows = await prisma.deviceToken.findMany({
      include: { user: { select: { name: true, email: true, role: true } } },
      orderBy: { created_at: 'desc' },
      take: 10,
    });
    await prisma.$disconnect();

    console.log('\n== Device token terdaftar di database ==');
    if (rows.length === 0) {
      console.log('  (belum ada token — buka app di HP dan login)');
      return;
    }
    for (const r of rows) {
      console.log(
        `  - ${r.user?.name ?? r.user_id} (${r.user?.role ?? '?'}) | ${r.platform} | ${mask(r.token)} | ${r.created_at.toISOString()}`
      );
    }
    console.log(`  total: ${rows.length} token ditampilkan (maks 10)`);
  } catch (err) {
    console.log('  gagal membaca database:', err.message);
  }
}

async function main() {
  const projectId = process.env.FIREBASE_PROJECT_ID;
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
  const privateKey = normalizePrivateKey(process.env.FIREBASE_PRIVATE_KEY);

  console.log('== Konfigurasi Firebase Cloud Messaging ==');
  console.log('  FIREBASE_PROJECT_ID   :', projectId ? `TERISI (${projectId})` : 'KOSONG');
  console.log('  FIREBASE_CLIENT_EMAIL :', clientEmail ? `TERISI (${clientEmail})` : 'KOSONG');
  console.log('  FIREBASE_PRIVATE_KEY  :', privateKey ? mask(privateKey) : 'KOSONG');

  if (!projectId || !clientEmail || !privateKey) {
    console.log('\nHASIL: Kredensial belum lengkap -> push di backend NON-AKTIF (tidak error).');
    console.log(
      'Isi api/.env: FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL, FIREBASE_PRIVATE_KEY'
    );
    console.log(
      'Sumber: Firebase Console > Project Settings > Service Accounts > Generate new private key'
    );
    await listDeviceTokens();
    process.exitCode = 1;
    return;
  }

  try {
    admin.initializeApp({
      credential: admin.credential.cert({ projectId, clientEmail, privateKey }),
    });
  } catch (err) {
    console.log('\nHASIL: GAGAL inisialisasi firebase-admin ->', err.message);
    await listDeviceTokens();
    process.exitCode = 1;
    return;
  }

  try {
    await admin.messaging().send({
      token: DUMMY_TOKEN,
      notification: { title: 'credential check', body: 'credential check' },
    });
    console.log('\nHASIL: Kredensial VALID (FCM menerima token dummy tanpa error).');
  } catch (err) {
    const code = err?.code || err?.errorInfo?.code || '(tidak ada code)';
    const message = err?.message || String(err);
    if (/invalid-registration-token|registration-token-not-registered|invalid-argument/i.test(code + ' ' + message)) {
      console.log('\nHASIL: KREDENSIAL VALID (FCM menolak token dummy -> auth service account OK).');
    } else {
      console.log(`\nHASIL: KREDENSIAL MASALAH -> code=${code}`);
      console.log('  detail:', message.slice(0, 400));
      process.exitCode = 1;
    }
  }

  await listDeviceTokens();
}

main().catch((err) => {
  console.error('error tidak terduga:', err);
  process.exitCode = 1;
});
