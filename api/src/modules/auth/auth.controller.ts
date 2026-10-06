import { Request, Response, NextFunction } from 'express';
import { authService } from './auth.service';
import {
  loginSchema,
  refreshSchema,
  logoutSchema,
  updateProfileSchema,
  changePasswordSchema,
} from './auth.schema';

export async function login(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const data = loginSchema.parse(req.body);
    const result = await authService.login(data.email, data.password, req.headers['user-agent']);
    res.status(200).json({ data: result });
  } catch (err) {
    next(err);
  }
}

export async function refresh(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const data = refreshSchema.parse(req.body);
    const result = await authService.refresh(data.refresh_token);
    res.status(200).json({ data: result });
  } catch (err) {
    next(err);
  }
}

export async function logout(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const data = logoutSchema.parse(req.body);
    await authService.logout(data.refresh_token);
    res.status(204).send();
  } catch (err) {
    next(err);
  }
}

export async function getMe(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const result = await authService.getMe(req.user!.id);
    res.status(200).json({ data: result });
  } catch (err) {
    next(err);
  }
}

export async function patchMe(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const data = updateProfileSchema.parse(req.body);
    const result = await authService.updateProfile(req.user!.id, data);
    res.status(200).json({ data: result });
  } catch (err) {
    next(err);
  }
}

export async function changePassword(
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    const data = changePasswordSchema.parse(req.body);
    await authService.changePassword(req.user!.id, data.current_password, data.new_password);
    res.status(204).send();
  } catch (err) {
    next(err);
  }
}
