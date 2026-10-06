import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import { requestIdMiddleware } from './middleware/request-id';
import { errorHandler } from './middleware/error';
import { AppError, ErrorCodes } from './shared/errors';
import healthRoute from './modules/health/health.route';
import authRoute from './modules/auth/auth.route';
import usersRoute from './modules/users/users.route';
import catalogRoute from './modules/catalog/catalog.route';
import inventoryRoute from './modules/inventory/inventory.route';

const app = express();

// Security and utility middlewares
app.use(helmet());
app.use(cors());
app.use(express.json());
app.use(requestIdMiddleware);

// Mount routes
app.use('/api', healthRoute);
app.use('/api', authRoute);
app.use('/api', usersRoute);
app.use('/api', catalogRoute);
app.use('/api', inventoryRoute);
app.use('/', healthRoute); // Direct /health fallback

// 404 Handler
app.use((req, _res, next) => {
  next(new AppError(ErrorCodes.NOT_FOUND, 404, `Endpoint ${req.method} ${req.originalUrl} tidak ditemukan.`));
});

// Central Error Handler
app.use(errorHandler);

export default app;
