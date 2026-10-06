import { Router } from 'express';
import { aiAssistantController } from './ai.controller';
import { requireAuth } from '../../middleware/auth';

const router = Router();

// Proteksi auth untuk seluruh endpoint AI
router.use('/ai', requireAuth);

// 1. POST /api/ai/chat - Kirim pesan & dapatkan jawaban grounded fakta
router.post('/ai/chat', (req, res, next) => aiAssistantController.chat(req, res, next));

// 2. GET /api/ai/conversations - Daftar percakapan
router.get('/ai/conversations', (req, res, next) => aiAssistantController.listConversations(req, res, next));

// 3. GET /api/ai/conversations/:id/messages - Riwayat percakapan spesifik
router.get('/ai/conversations/:id/messages', (req, res, next) => aiAssistantController.getMessages(req, res, next));

export default router;
