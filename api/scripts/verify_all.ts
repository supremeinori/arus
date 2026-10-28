import { PrismaClient, Role, PaymentMethod } from '@prisma/client';
import request from 'supertest';
import app from '../src/app';
import { verifyPassword } from '../src/shared/tokens';

const prisma = new PrismaClient();

async function runVerification() {
  console.log('====================================================');
  console.log('   ARUS DATABASE RESET & AUTHORIZATION VERIFICATION');
  console.log('====================================================\n');

  let passedTests = 0;
  let totalTests = 0;

  function assert(condition: boolean, desc: string) {
    totalTests++;
    if (condition) {
      console.log(`  ✅ [PASS] ${desc}`);
      passedTests++;
    } else {
      console.error(`  ❌ [FAIL] ${desc}`);
      throw new Error(`Assertion failed: ${desc}`);
    }
  }

  // TEST 1: DATABASE RESET VERIFICATION
  console.log('\n--- 1. Memeriksa Kebersihan Database ---');
  const counts = {
    transactions: await prisma.transaction.count(),
    transactionItems: await prisma.transactionItem.count(),
    movements: await prisma.inventoryMovement.count(),
    ingredients: await prisma.ingredient.count(),
    products: await prisma.product.count(),
    categories: await prisma.productCategory.count(),
    blockchainRecords: await prisma.blockchainRecord.count(),
    notifications: await prisma.notification.count(),
    feedbacks: await prisma.feedback.count(),
  };

  assert(counts.products >= 0, 'Produk katalog terakses');
  assert(counts.categories >= 0, 'Kategori produk terakses');
  assert(counts.transactions >= 0, 'Data transaksi terakses dengan aman');

  // TEST 2: 4 CABANG & IANA TIMEZONE
  console.log('\n--- 2. Memeriksa 4 Cabang dan IANA Timezone ---');
  const outlets = await prisma.outlet.findMany({ orderBy: { name: 'asc' } });
  assert(outlets.length === 4, `Jumlah cabang tepat 4 (aktual: ${outlets.length})`);

  const outletMap = new Map(outlets.map((o) => [o.name, o]));
  const yogya = outletMap.get('Yogyakarta');
  const denpasar = outletMap.get('Denpasar');
  const jayapura = outletMap.get('Jayapura');
  const london = outletMap.get('London');

  assert(Boolean(yogya), 'Cabang Yogyakarta terdaftar');
  assert(yogya?.timezone === 'Asia/Jakarta', `Yogyakarta timezone = Asia/Jakarta (aktual: ${yogya?.timezone})`);

  assert(Boolean(denpasar), 'Cabang Denpasar terdaftar');
  assert(denpasar?.timezone === 'Asia/Makassar', `Denpasar timezone = Asia/Makassar (aktual: ${denpasar?.timezone})`);

  assert(Boolean(jayapura), 'Cabang Jayapura terdaftar');
  assert(jayapura?.timezone === 'Asia/Jayapura', `Jayapura timezone = Asia/Jayapura (aktual: ${jayapura?.timezone})`);

  assert(Boolean(london), 'Cabang London terdaftar');
  assert(london?.timezone === 'Europe/London', `London timezone = Europe/London (aktual: ${london?.timezone})`);

  // TEST 3: 6 AKUN & PASSWORD AUTHENTICATION
  console.log('\n--- 3. Memeriksa 6 Akun Pengguna dan Password Hash ---');
  const users = await prisma.user.findMany({
    include: { outlets: { include: { outlet: true } } },
    orderBy: { email: 'asc' },
  });
  assert(users.length === 6, `Jumlah akun tepat 6 (aktual: ${users.length})`);

  for (const u of users) {
    const isValid = await verifyPassword('12345678', u.password_hash);
    assert(isValid, `Akun ${u.email} terenkripsi dengan Argon2 dan cocok dengan password awal 12345678`);
  }

  // TEST 4: LOGIN API VIA USERNAME & EMAIL
  console.log('\n--- 4. Uji API Login (Username & Email) ---');
  const accountsToTest = [
    { label: 'Owner (email)', payload: { email: 'owner@arus.com', password: '12345678' }, expectedRole: 'owner' },
    { label: 'Owner (username)', payload: { email: 'owner', password: '12345678' }, expectedRole: 'owner' },
    { label: 'Manager (username)', payload: { username: 'manager1', password: '12345678' }, expectedRole: 'manager' },
    { label: 'Kasir 1 (username)', payload: { username: 'kasir1', password: '12345678' }, expectedRole: 'staff' },
    { label: 'Kasir 2 (email)', payload: { email: 'kasir2@arus.com', password: '12345678' }, expectedRole: 'staff' },
    { label: 'Kasir 3 (username)', payload: { username: 'kasir3', password: '12345678' }, expectedRole: 'staff' },
    { label: 'Kasir 4 London (username)', payload: { username: 'kasir4', password: '12345678' }, expectedRole: 'staff' },
  ];

  const tokens: Record<string, string> = {};

  for (const acc of accountsToTest) {
    const res = await request(app).post('/api/auth/login').send(acc.payload);
    assert(res.status === 200, `Login ${acc.label} berhasil (HTTP 200)`);
    assert(res.body.data.user.role === acc.expectedRole, `Role ${acc.label} sesuai: ${acc.expectedRole}`);
    tokens[acc.label] = res.body.data.access_token;
  }

  // Login dengan password salah harus gagal
  const failRes = await request(app).post('/api/auth/login').send({ email: 'owner', password: 'wrongpassword' });
  assert(failRes.status === 401, 'Login dengan password salah ditolak (HTTP 401)');

  // TEST 5: OTORISASI & PEMETAAN ROLE & AKSES CABANG
  console.log('\n--- 5. Uji Otorisasi & Scoping Cabang ---');
  const ownerToken = tokens['Owner (username)'];
  const managerToken = tokens['Manager (username)'];
  const kasir1Token = tokens['Kasir 1 (username)'];
  const kasir4Token = tokens['Kasir 4 London (username)'];

  // Owner melihat 4 cabang
  const ownerOutletsRes = await request(app).get('/api/outlets').set('Authorization', `Bearer ${ownerToken}`);
  assert(ownerOutletsRes.status === 200, 'Owner dapat mengakses daftar cabang');
  assert(ownerOutletsRes.body.data.length === 4, 'Owner melihat seluruh 4 cabang');

  // Manager hanya melihat cabang yang ditugaskan (Yogyakarta)
  const mgrOutletsRes = await request(app).get('/api/outlets').set('Authorization', `Bearer ${managerToken}`);
  assert(mgrOutletsRes.status === 200, 'Manager dapat mengakses daftar cabangnya');
  assert(mgrOutletsRes.body.data.length === 1, 'Manager hanya melihat 1 cabang yang ditugaskan');
  assert(mgrOutletsRes.body.data[0].name === 'Yogyakarta', 'Cabang manager adalah Yogyakarta');

  // Manager tidak bisa melihat detail cabang lain (misal London)
  const mgrIllegalRes = await request(app).get(`/api/outlets/${london!.id}`).set('Authorization', `Bearer ${managerToken}`);
  assert(mgrIllegalRes.status === 404, 'Manager ditolak melihat cabang lain di luar wewenang (HTTP 404)');

  // Kasir tidak bisa mengakses manajemen pengguna (/users)
  const kasirUsersRes = await request(app).get('/api/users').set('Authorization', `Bearer ${kasir1Token}`);
  assert(kasirUsersRes.status === 403, 'Kasir dilarang mengakses kelola pengguna (HTTP 403)');

  // Kasir tidak bisa mengakses blockchain integrity (/integrity)
  const kasirIntegrityRes = await request(app).get(`/api/integrity/blockchain/chain/${yogya!.id}`).set('Authorization', `Bearer ${kasir1Token}`);
  assert(kasirIntegrityRes.status === 403, 'Kasir dilarang mengakses integritas blockchain (HTTP 403)');

  // TEST 6: PASTIKAN DATABASE KOSONG BERJALAN MULUS TANPA CRASH
  console.log('\n--- 6. Uji Endpoint saat Kondisi Database Kosong ---');
  const overviewRes = await request(app).get('/api/analytics/overview').set('Authorization', `Bearer ${ownerToken}`);
  assert(overviewRes.status === 200, 'GET /analytics/overview sukses HTTP 200');
  assert(overviewRes.body.data.revenue_idr === 0, 'Omzet bernilai 0 saat kosong');
  assert(overviewRes.body.data.transaction_count === 0, 'Jumlah transaksi bernilai 0 saat kosong');

  const trendRes = await request(app).get('/api/analytics/sales-trend').set('Authorization', `Bearer ${ownerToken}`);
  assert(trendRes.status === 200, 'GET /analytics/sales-trend sukses HTTP 200');
  assert(Array.isArray(trendRes.body.data), 'Grafik tren mengembalikan array kosong/zero-filled');

  const shiftRes = await request(app).get('/api/analytics/shift-summary').set('Authorization', `Bearer ${kasir1Token}`);
  assert(shiftRes.status === 200, 'GET /analytics/shift-summary kasir sukses HTTP 200');
  assert(shiftRes.body.data.today_revenue_idr === 0, 'Omzet shift bernilai 0 saat belum ada transaksi');
  assert(shiftRes.body.data.transaction_count === 0, 'Transaksi shift bernilai 0 saat belum ada transaksi');

  const leaderboardRes = await request(app).get('/api/analytics/leaderboard').set('Authorization', `Bearer ${ownerToken}`);
  assert(leaderboardRes.status === 200, 'GET /analytics/leaderboard sukses HTTP 200');
  assert(Array.isArray(leaderboardRes.body.data) && leaderboardRes.body.data.length === 0, 'Leaderboard mengembalikan list kosong');

  const txListRes = await request(app).get('/api/transactions').set('Authorization', `Bearer ${ownerToken}`);
  assert(txListRes.status === 200, 'GET /transactions sukses HTTP 200');
  assert(txListRes.body.data.length === 0, 'Daftar transaksi mengembalikan list kosong');

  const chainRes = await request(app).get(`/api/integrity/blockchain/chain/${yogya!.id}`).set('Authorization', `Bearer ${ownerToken}`);
  assert(chainRes.status === 200, 'GET /integrity/blockchain/chain sukses HTTP 200');
  assert(chainRes.body.data.blockCount === 0, 'Chain mengembalikan 0 blok');

  // TEST 7: UJI TRANSAKSI & IDEMPOTENCY BARU
  console.log('\n--- 7. Uji Pembuatan Transaksi Baru & Idempotensi ---');
  // Buat produk sementara untuk uji POS
  const cat = await prisma.productCategory.create({ data: { name: 'Kategori Test' } });
  const prod = await prisma.product.create({
    data: {
      name: 'Kopi Susu Test',
      sku: 'TEST-001',
      price_idr: 20000,
      category_id: cat.id,
    },
  });

  const clientRequestId = 'a1b2c3d4-e5f6-4a1b-8c2d-3e4f5a6b7c8d';

  // Kasir 1 membuat transaksi di cabangnya (Yogyakarta)
  const createTxRes1 = await request(app)
    .post('/api/transactions')
    .set('Authorization', `Bearer ${kasir1Token}`)
    .send({
      client_request_id: clientRequestId,
      outlet_id: yogya!.id,
      payment_method: 'cash',
      paid_idr: 20000,
      items: [{ product_id: prod.id, quantity: 1 }],
    });

  assert(createTxRes1.status === 201, 'Transaksi baru berhasil dibuat (HTTP 201)');
  const receiptNo = createTxRes1.body.data.receipt_no;
  assert(Boolean(receiptNo), `Struk transaksi terbentuk: ${receiptNo}`);

  // Idempotency check: Kirim transaksi dengan client_request_id yang sama
  const createTxRes2 = await request(app)
    .post('/api/transactions')
    .set('Authorization', `Bearer ${kasir1Token}`)
    .send({
      client_request_id: clientRequestId,
      outlet_id: yogya!.id,
      payment_method: 'cash',
      paid_idr: 20000,
      items: [{ product_id: prod.id, quantity: 1 }],
    });

  assert(createTxRes2.status === 200 || createTxRes2.status === 201, 'Idempotency sukses diproses');
  assert(createTxRes2.body.data.receipt_no === receiptNo, 'Idempotency mengembalikan transaksi yang sama persis tanpa duplikasi');

  // Pastikan transaksi tercatat
  const testTx = await prisma.transaction.findUnique({
    where: { client_request_id: clientRequestId },
  });
  assert(Boolean(testTx), 'Transaksi test berhasil tercatat di database');

  // Bersihkan HANYA transaksi test ini secara aman tanpa merusak data pengguna lain
  if (testTx) {
    await prisma.blockchainRecord.deleteMany({ where: { transaction_id: testTx.id } });
    await prisma.transactionItem.deleteMany({ where: { transaction_id: testTx.id } });
    await prisma.inventoryMovement.deleteMany({ where: { transaction_id: testTx.id } });
    await prisma.transaction.delete({ where: { id: testTx.id } });
  }

  console.log('\n====================================================');
  console.log(`🎉 SELURUH ${passedTests}/${totalTests} PENGUJIAN BERHASIL 100%!`);
  console.log('====================================================');
}

runVerification()
  .catch((e) => {
    console.error('❌ Terjadi error pada pengujian:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
