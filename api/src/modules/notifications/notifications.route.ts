import { Router } from 'express';
import { NotificationsController } from './notifications.controller';
import { requireAuth } from '../../middleware/auth';

const router = Router();
const controller = new NotificationsController();

router.use('/notifications', requireAuth);

// 1. GET /api/notifications - Ambil daftar notifikasi & hitung unread count
router.get('/notifications', (req, res, next) => controller.list(req, res, next));

// 2. PATCH /api/notifications/:id/read - Tandai notifikasi spesifik sudah dibaca
router.patch('/notifications/:id/read', (req, res, next) =>
  controller.markRead(req, res, next)
);

// 3. POST /api/notifications/read-all - Tandai seluruh notifikasi sudah dibaca
router.post('/notifications/read-all', (req, res, next) =>
  controller.markAllRead(req, res, next)
);

// 4. POST /api/notifications/evaluate - Evaluasi pemicu notifikasi stok kritis otomatis
router.post('/notifications/evaluate', (req, res, next) =>
  controller.evaluate(req, res, next)
);

// 5. POST /api/notifications/device-token - Registrasi FCM Device Token
router.post('/notifications/device-token', (req, res, next) =>
  controller.registerToken(req, res, next)
);

export default router;
