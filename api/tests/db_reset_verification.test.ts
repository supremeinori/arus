import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import request from 'supertest';
import app from '../src/app';
import { prisma } from '../src/config/db';
import { verifyPassword } from '../src/shared/tokens';

describe('ARUS — Database Reset & Authorization Verification', { timeout: 35000 }, () => {
  beforeAll(async () => {
    await prisma.blockchainRecord.deleteMany();
    await prisma.transactionItem.deleteMany();
    await prisma.transaction.deleteMany();
  });

  afterAll(async () => {
    await prisma.blockchainRecord.deleteMany();
    await prisma.transactionItem.deleteMany();
    await prisma.transaction.deleteMany();
  });

  it('1. Verifikasi data seeder: 10 produk menu, 52 bahan baku, 0 transaksi bisnis', async () => {
    const counts = {
      transactions: await prisma.transaction.count(),
      transactionItems: await prisma.transactionItem.count(),
      products: await prisma.product.count(),
      categories: await prisma.productCategory.count(),
      ingredients: await prisma.ingredient.count(),
      recipes: await prisma.productRecipe.count(),
      blockchainRecords: await prisma.blockchainRecord.count(),
      notifications: await prisma.notification.count(),
    };

    expect(counts.transactions).toBe(0);
    expect(counts.transactionItems).toBe(0);
    expect(counts.blockchainRecords).toBe(0);
    expect(counts.products).toBe(10);
    expect(counts.categories).toBe(3);
    expect(counts.ingredients).toBe(52);
    expect(counts.recipes).toBeGreaterThan(0);
  });

  it('2. Verifikasi 4 cabang dan IANA Timezone', async () => {
    const outlets = await prisma.outlet.findMany({ orderBy: { name: 'asc' } });
    expect(outlets.length).toBe(4);

    const map = new Map(outlets.map((o) => [o.name, o]));
    expect(map.has('Yogyakarta')).toBe(true);
    expect(map.get('Yogyakarta')?.timezone).toBe('Asia/Jakarta');

    expect(map.has('Denpasar')).toBe(true);
    expect(map.get('Denpasar')?.timezone).toBe('Asia/Makassar');

    expect(map.has('Jayapura')).toBe(true);
    expect(map.get('Jayapura')?.timezone).toBe('Asia/Jayapura');

    expect(map.has('London')).toBe(true);
    expect(map.get('London')?.timezone).toBe('Europe/London');
  });

  it('3. Verifikasi 6 akun terdaftar dengan password Argon2 12345678', async () => {
    const users = await prisma.user.findMany({
      include: { outlets: { include: { outlet: true } } },
      orderBy: { email: 'asc' },
    });
    expect(users.length).toBe(6);

    for (const u of users) {
      const isValid = await verifyPassword('12345678', u.password_hash);
      expect(isValid).toBe(true);
    }
  });

  it('4. Uji login wajib email format @arus.com dan penolakan username biasa', async () => {
    // 1. Penolakan jika mengirim format username biasa (bukan email)
    const resRejectUsername = await request(app)
      .post('/api/auth/login')
      .send({ email: 'owner', password: '12345678' });
    expect(resRejectUsername.status).toBe(400);

    // 2. Penolakan jika domain email bukan @arus.com
    const resRejectDomain = await request(app)
      .post('/api/auth/login')
      .send({ email: 'owner@gmail.com', password: '12345678' });
    expect(resRejectDomain.status).toBe(400);

    // 3. Login sukses Owner via owner@arus.com
    const resOwnerEmail = await request(app)
      .post('/api/auth/login')
      .send({ email: 'owner@arus.com', password: '12345678' });
    expect(resOwnerEmail.status).toBe(200);
    expect(resOwnerEmail.body.data.user.role).toBe('owner');
    expect(resOwnerEmail.body.data.user.outlets.length).toBe(4);

    // 4. Login sukses Manager via manager1@arus.com
    const resMgr = await request(app)
      .post('/api/auth/login')
      .send({ email: 'manager1@arus.com', password: '12345678' });
    expect(resMgr.status).toBe(200);
    expect(resMgr.body.data.user.role).toBe('manager');
    expect(resMgr.body.data.user.outlets.length).toBe(1);
    expect(resMgr.body.data.user.outlets[0].name).toBe('Yogyakarta');

    // 5. Login sukses Kasir 1 via kasir1@arus.com (Yogyakarta)
    const resK1 = await request(app)
      .post('/api/auth/login')
      .send({ email: 'kasir1@arus.com', password: '12345678' });
    expect(resK1.status).toBe(200);
    expect(resK1.body.data.user.role).toBe('staff');
    expect(resK1.body.data.user.outlets[0].name).toBe('Yogyakarta');

    // 6. Login sukses Kasir 2 via kasir2@arus.com (Denpasar)
    const resK2 = await request(app)
      .post('/api/auth/login')
      .send({ email: 'kasir2@arus.com', password: '12345678' });
    expect(resK2.status).toBe(200);
    expect(resK2.body.data.user.outlets[0].name).toBe('Denpasar');

    // 7. Login sukses Kasir 3 via kasir3@arus.com (Jayapura)
    const resK3 = await request(app)
      .post('/api/auth/login')
      .send({ email: 'kasir3@arus.com', password: '12345678' });
    expect(resK3.status).toBe(200);
    expect(resK3.body.data.user.outlets[0].name).toBe('Jayapura');

    // 8. Login sukses Kasir 4 via kasir4@arus.com (London)
    const resK4 = await request(app)
      .post('/api/auth/login')
      .send({ email: 'kasir4@arus.com', password: '12345678' });
    expect(resK4.status).toBe(200);
    expect(resK4.body.data.user.outlets[0].name).toBe('London');

    // 9. Login salah password ditolak 401
    const resFail = await request(app)
      .post('/api/auth/login')
      .send({ email: 'owner@arus.com', password: 'wrongpassword' });
    expect(resFail.status).toBe(401);
  });

  it('5. Uji RBAC dan penegakan otorisasi cabang', async () => {
    const resOwner = await request(app)
      .post('/api/auth/login')
      .send({ email: 'owner@arus.com', password: '12345678' });
    const ownerToken = resOwner.body.data.access_token;

    const resMgr = await request(app)
      .post('/api/auth/login')
      .send({ email: 'manager1@arus.com', password: '12345678' });
    const mgrToken = resMgr.body.data.access_token;

    const resK1 = await request(app)
      .post('/api/auth/login')
      .send({ email: 'kasir1@arus.com', password: '12345678' });
    const k1Token = resK1.body.data.access_token;

    // Owner melihat 4 cabang
    const ownerOutlets = await request(app)
      .get('/api/outlets')
      .set('Authorization', `Bearer ${ownerToken}`);
    expect(ownerOutlets.status).toBe(200);
    expect(ownerOutlets.body.data.length).toBe(4);

    // Manager hanya melihat 1 cabang (Yogyakarta)
    const mgrOutlets = await request(app)
      .get('/api/outlets')
      .set('Authorization', `Bearer ${mgrToken}`);
    expect(mgrOutlets.status).toBe(200);
    expect(mgrOutlets.body.data.length).toBe(1);
    expect(mgrOutlets.body.data[0].name).toBe('Yogyakarta');

    // Manager ditolak melihat cabang lain (London)
    const london = (await prisma.outlet.findUnique({ where: { name: 'London' } }))!;
    const mgrIllegal = await request(app)
      .get(`/api/outlets/${london.id}`)
      .set('Authorization', `Bearer ${mgrToken}`);
    expect(mgrIllegal.status).toBe(404);

    // Kasir dilarang mengakses kelola pengguna
    const kasirUsers = await request(app)
      .get('/api/users')
      .set('Authorization', `Bearer ${k1Token}`);
    expect(kasirUsers.status).toBe(403);

    // Kasir dilarang mengakses blockchain integrity
    const yogya = (await prisma.outlet.findUnique({ where: { name: 'Yogyakarta' } }))!;
    const kasirIntegrity = await request(app)
      .get(`/api/integrity/blockchain/chain/${yogya.id}`)
      .set('Authorization', `Bearer ${k1Token}`);
    expect(kasirIntegrity.status).toBe(403);
  });

  it('6. Uji perilaku endpoint analitik & transaksi saat database kosong (tidak crash)', async () => {
    const resOwner = await request(app)
      .post('/api/auth/login')
      .send({ email: 'owner@arus.com', password: '12345678' });
    const ownerToken = resOwner.body.data.access_token;

    const resK1 = await request(app)
      .post('/api/auth/login')
      .send({ email: 'kasir1@arus.com', password: '12345678' });
    const k1Token = resK1.body.data.access_token;

    // Overview
    const overview = await request(app)
      .get('/api/analytics/overview')
      .set('Authorization', `Bearer ${ownerToken}`);
    expect(overview.status).toBe(200);
    expect(overview.body.data.revenue_idr).toBe(0);
    expect(overview.body.data.transaction_count).toBe(0);

    // Sales Trend
    const trend = await request(app)
      .get('/api/analytics/sales-trend')
      .set('Authorization', `Bearer ${ownerToken}`);
    expect(trend.status).toBe(200);
    expect(Array.isArray(trend.body.data)).toBe(true);

    // Shift summary kasir
    const shift = await request(app)
      .get('/api/analytics/shift-summary')
      .set('Authorization', `Bearer ${k1Token}`);
    expect(shift.status).toBe(200);
    expect(shift.body.data.today_revenue_idr).toBe(0);
    expect(shift.body.data.transaction_count).toBe(0);

    // Leaderboard
    const leaderboard = await request(app)
      .get('/api/analytics/leaderboard')
      .set('Authorization', `Bearer ${ownerToken}`);
    expect(leaderboard.status).toBe(200);
    expect(leaderboard.body.data).toEqual([]);

    // Transactions list
    const txs = await request(app)
      .get('/api/transactions')
      .set('Authorization', `Bearer ${ownerToken}`);
    expect(txs.status).toBe(200);
    expect(txs.body.data).toEqual([]);
  });

  it('7. Uji pembuatan transaksi baru & Idempotency sinkronisasi', async () => {
    const resK1 = await request(app)
      .post('/api/auth/login')
      .send({ email: 'kasir1@arus.com', password: '12345678' });
    const k1Token = resK1.body.data.access_token;

    const yogya = (await prisma.outlet.findUnique({ where: { name: 'Yogyakarta' } }))!;
    const prod = (await prisma.product.findFirst({ where: { is_active: true } }))!;

    const ts = Date.now();
    const clientRequestId = `b2c3d4e5-f6a1-4b2c-9d3e-${ts.toString().slice(-12).padStart(12, '0')}`;

    // 1. Transaksi pertama
    const resTx1 = await request(app)
      .post('/api/transactions')
      .set('Authorization', `Bearer ${k1Token}`)
      .send({
        client_request_id: clientRequestId,
        outlet_id: yogya.id,
        payment_method: 'cash',
        paid_idr: prod.price_idr,
        items: [{ product_id: prod.id, quantity: 1 }],
      });
    expect(resTx1.status).toBe(201);
    const receiptNo = resTx1.body.data.receipt_no;
    expect(receiptNo).toBeDefined();

    // 2. Idempotency replay (simulasi sinkronisasi ulang antrean pending yang sama)
    const resTx2 = await request(app)
      .post('/api/transactions')
      .set('Authorization', `Bearer ${k1Token}`)
      .send({
        client_request_id: clientRequestId,
        outlet_id: yogya.id,
        payment_method: 'cash',
        paid_idr: prod.price_idr,
        items: [{ product_id: prod.id, quantity: 1 }],
      });
    expect([200, 201]).toContain(resTx2.status);
    expect(resTx2.body.data.receipt_no).toBe(receiptNo);

    // Pastikan tidak ada transaksi duplikat di database
    const count = await prisma.transaction.count();
    expect(count).toBe(1);

    // Cleanup: Bersihkan transaksi test
    await prisma.blockchainRecord.deleteMany();
    await prisma.transactionItem.deleteMany();
    await prisma.transaction.deleteMany();

    const finalCount = await prisma.transaction.count();
    expect(finalCount).toBe(0);
  });
});
