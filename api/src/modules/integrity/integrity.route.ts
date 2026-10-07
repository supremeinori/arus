import { Router } from 'express';
import { integrityController } from './integrity.controller';
import { requireAuth } from '../../middleware/auth';

const router = Router();

router.use('/integrity', requireAuth);

router.get('/integrity/chain/:outletId', (req, res, next) => integrityController.getChainForOutlet(req, res, next));
router.get('/integrity/verify/transaction/:id', (req, res, next) => integrityController.verifyTransaction(req, res, next));
router.get('/integrity/verify/report/:id', (req, res, next) => integrityController.verifyReport(req, res, next));

export default router;
