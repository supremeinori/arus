import { Request, Response, NextFunction } from 'express';
import { usersService } from './users.service';
import { createUserSchema, updateUserSchema, updateUserSettingsSchema } from './users.schema';
import { Role } from '@prisma/client';

export async function getUserSettings(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const userId = (req as any).user.id;
    const result = await usersService.getUserSettings(userId);
    res.status(200).json({ success: true, data: result });
  } catch (err) {
    next(err);
  }
}

export async function updateUserSettings(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const userId = (req as any).user.id;
    const data = updateUserSettingsSchema.parse(req.body);
    const result = await usersService.updateUserSettings(userId, data);
    res.status(200).json({ success: true, data: result });
  } catch (err) {
    next(err);
  }
}

export async function listUsers(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const role = req.query.role as Role | undefined;
    const is_active = req.query.is_active !== undefined ? req.query.is_active === 'true' : undefined;
    const q = req.query.q as string | undefined;
    const page = req.query.page ? parseInt(req.query.page as string, 10) : 1;
    const page_size = req.query.page_size ? parseInt(req.query.page_size as string, 10) : 20;

    const result = await usersService.listUsers({ role, is_active, q, page, page_size });
    res.status(200).json({ data: result.users, meta: result.meta });
  } catch (err) {
    next(err);
  }
}

export async function createUser(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const data = createUserSchema.parse(req.body);
    const result = await usersService.createUser(data);
    res.status(201).json({ data: result });
  } catch (err) {
    next(err);
  }
}

export async function updateUser(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const data = updateUserSchema.parse(req.body);
    const result = await usersService.updateUser(req.params.id, data);
    res.status(200).json({ data: result });
  } catch (err) {
    next(err);
  }
}
