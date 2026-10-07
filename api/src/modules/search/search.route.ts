import { Router, Request, Response } from 'express';
import { requireAuth } from '../../middleware/auth';
import { catalogService } from '../catalog/catalog.service';
import { outletsService } from '../outlets/outlets.service';

const router = Router();

router.use('/search', requireAuth);

router.get('/search', async (req: Request, res: Response) => {
  const q = String(req.query.q || '').trim().toLowerCase();
  if (!q) {
    res.status(200).json({
      data: {
        products: [],
        outlets: [],
        total: 0,
      },
    });
    return;
  }

  try {
    const [productsResult, outletsResult] = await Promise.all([
      catalogService.listProducts(req.user!.role, { q, page_size: 10 } as any),
      outletsService.listOutlets(req.user!, req.userOutlets || []),
    ]);

    const matchingOutlets = outletsResult.filter(
      (o: any) => o.name.toLowerCase().includes(q) || o.address.toLowerCase().includes(q)
    );

    res.status(200).json({
      data: {
        products: productsResult.products,
        outlets: matchingOutlets,
        total: productsResult.products.length + matchingOutlets.length,
      },
    });
  } catch (_) {
    res.status(200).json({
      data: {
        products: [],
        outlets: [],
        total: 0,
      },
    });
  }
});

export default router;
