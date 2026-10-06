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
import transactionsRoute from './modules/transactions/transactions.route';
import analyticsRoute from './modules/analytics/analytics.route';
import insightsRoute from './modules/insights/insights.route';
import aiRoute from './modules/ai/ai.route';
import reportsRoute from './modules/reports/reports.route';
import outletsRoute from './modules/outlets/outlets.route';
import notificationsRoute from './modules/notifications/notifications.route';

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
app.use('/api', outletsRoute);
app.use('/api', catalogRoute);
app.use('/api', inventoryRoute);
app.use('/api', transactionsRoute);
app.use('/api', analyticsRoute);
app.use('/api', insightsRoute);
app.use('/api', aiRoute);
app.use('/api', reportsRoute);
app.use('/api', notificationsRoute);
app.use('/', healthRoute); // Direct /health fallback

// 404 Handler
app.use((req, _res, next) => {
  next(new AppError(ErrorCodes.NOT_FOUND, 404, `Endpoint ${req.method} ${req.originalUrl} tidak ditemukan.`));
});

// Central Error Handler
app.use(errorHandler);

export default app;
