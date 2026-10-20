import admin from 'firebase-admin';
import { prisma } from '../../config/db';

let initAttempted = false;

function isFirebaseConfigured(): boolean {
  const projectId = process.env.FIREBASE_PROJECT_ID;
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
  const privateKey = process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n');
  return Boolean(projectId && clientEmail && privateKey);
}

function initFirebase(): boolean {
  if (!isFirebaseConfigured()) return false;
  if (admin.apps.length > 0) return true;
  if (initAttempted) return false;

  initAttempted = true;
  try {
    const privateKey = process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n');
    admin.initializeApp({
      credential: admin.credential.cert({
        projectId: process.env.FIREBASE_PROJECT_ID as string,
        clientEmail: process.env.FIREBASE_CLIENT_EMAIL as string,
        privateKey: privateKey as string,
      }),
    });
    return true;
  } catch (err) {
    console.warn('[PushService] Firebase gagal diinisialisasi:', err);
    return false;
  }
}

export const pushService = {
  isEnabled(): boolean {
    return isFirebaseConfigured();
  },

  async sendToTokens(tokens: string[], notification: { title: string; body: string; data?: Record<string, string> }, invalidTokenCallback?: (badToken: string) => void) {
    if (!tokens || tokens.length === 0) return;
    if (!initFirebase()) return;

    try {
      const message = {
        notification: {
          title: notification.title,
          body: notification.body,
        },
        data: notification.data || {},
        tokens,
      };

      const response = await admin.messaging().sendEachForMulticast(message);
      if (response.failureCount > 0 && invalidTokenCallback) {
        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            const errCode = resp.error?.code;
            if (
              errCode === 'messaging/invalid-registration-token' ||
              errCode === 'messaging/registration-token-not-registered'
            ) {
              Promise.resolve(invalidTokenCallback(tokens[idx])).catch(() => {});
            }
          }
        });
      }
    } catch (err) {
      console.warn('[PushService] Multicast send error (dilewati):', err);
    }
  },

  async sendToUser(userId: string, notification: { title: string; body: string; data?: Record<string, string> }, prismaClient: any = prisma) {
    try {
      const deviceTokens = await prismaClient.deviceToken.findMany({
        where: { user_id: userId },
        select: { token: true },
      });
      const tokens = (deviceTokens || []).map((d: any) => d.token);
      if (tokens.length === 0) return;

      await this.sendToTokens(tokens, notification, async (badToken) => {
        try {
          await prismaClient.deviceToken.deleteMany({
            where: { token: badToken },
          });
        } catch (_) {}
      });
    } catch (err) {
      console.warn('[PushService] sendToUser error (dilewati):', err);
    }
  },

  async sendToUsers(userIds: string[], notification: { title: string; body: string; data?: Record<string, string> }, prismaClient: any = prisma) {
    if (!userIds || userIds.length === 0) return;
    for (const uid of userIds) {
      await this.sendToUser(uid, notification, prismaClient);
    }
  },
};
