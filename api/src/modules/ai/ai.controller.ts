import { Request, Response, NextFunction } from 'express';
import { aiAssistantService } from './ai.service';

export class AiAssistantController {
  async chat(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const user = req.user!;
      const allowedOutletIds = req.userOutlets || [];
      const { conversation_id, message, outlet_id } = req.body;

      const result = await aiAssistantService.handleChat(
        user.id,
        { conversation_id, message, outlet_id },
        { role: user.role, allowedOutletIds }
      );

      res.status(200).json({ data: result });
    } catch (err) {
      next(err);
    }
  }

  async listConversations(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const user = req.user!;
      const data = await aiAssistantService.listConversations(user.id);
      res.status(200).json({ data });
    } catch (err) {
      next(err);
    }
  }

  async getMessages(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const user = req.user!;
      const { id } = req.params;
      const data = await aiAssistantService.getConversationMessages(id, user.id);
      res.status(200).json({ data });
    } catch (err) {
      next(err);
    }
  }
}

export const aiAssistantController = new AiAssistantController();
