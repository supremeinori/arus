import { Router } from 'express';
import { aiAssistantController } from './ai.controller';
import { requireAuth, requireRole } from '../../middleware/auth';
import { Role } from '@prisma/client';

const router = Router();

// Proteksi auth & role untuk seluruh endpoint AI (Owner & Manager only per SRS 2.2)
router.use('/ai', requireAuth, requireRole([Role.owner, Role.manager]));

// 1. POST /api/ai/chat - Kirim pesan & dapatkan jawaban grounded fakta
router.post('/ai/chat', (req, res, next) => aiAssistantController.chat(req, res, next));

// 1b. POST /api/ai/tts - Sintesis Teks ke Suara (Edge TTS id-ID-GadisNeural)
router.post('/ai/tts', (req, res, next) => aiAssistantController.tts(req, res, next));

// 1c. POST /api/ai/recommend-price - Rekomendasi Harga Jual AI untuk Menu Baru
router.post('/ai/recommend-price', (req, res, next) => aiAssistantController.recommendPrice(req, res, next));

// 2. GET /api/ai/conversations - Daftar percakapan
router.get('/ai/conversations', (req, res, next) => aiAssistantController.listConversations(req, res, next));

// 3. GET /api/ai/conversations/:id/messages - Riwayat percakapan spesifik
router.get('/api/ai/conversations/:id/messages', (req, res, next) => aiAssistantController.getMessages(req, res, next));

export default router;
