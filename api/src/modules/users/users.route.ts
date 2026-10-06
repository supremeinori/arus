import { Router } from 'express';
import { listUsers, createUser, updateUser } from './users.controller';
import { requireAuth, requireRole } from '../../middleware/auth';
import { Role } from '@prisma/client';

const router = Router();

router.get('/users', requireAuth, requireRole([Role.owner]), listUsers);
router.post('/users', requireAuth, requireRole([Role.owner]), createUser);
router.patch('/users/:id', requireAuth, requireRole([Role.owner]), updateUser);

export default router;
