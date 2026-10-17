import { MsEdgeTTS, OUTPUT_FORMAT } from 'msedge-tts';

export class TtsService {
  private static instance: TtsService;
  private voice = 'id-ID-GadisNeural';

  public static getInstance(): TtsService {
    if (!TtsService.instance) {
      TtsService.instance = new TtsService();
    }
    return TtsService.instance;
  }

  /**
   * Mengubah teks menjadi audio MP3 Base64 menggunakan Microsoft Edge TTS (id-ID-GadisNeural)
   */
  async textToSpeechBase64(text: string): Promise<string> {
    const cleanText = text.trim();
    if (!cleanText) {
      return '';
    }

    try {
      const tts = new MsEdgeTTS();
      await tts.setMetadata(this.voice, OUTPUT_FORMAT.AUDIO_24KHZ_48KBITRATE_MONO_MP3);
      const { audioStream } = tts.toStream(cleanText);

      return new Promise<string>((resolve, reject) => {
        const chunks: Buffer[] = [];
        const timer = setTimeout(() => {
          reject(new Error('TTS Generation timeout (8000ms)'));
        }, 8000);

        audioStream.on('data', (chunk: Buffer) => {
          chunks.push(chunk);
        });

        audioStream.on('end', () => {
          clearTimeout(timer);
          const buffer = Buffer.concat(chunks);
          resolve(buffer.toString('base64'));
        });

        audioStream.on('error', (err: any) => {
          clearTimeout(timer);
          reject(err);
        });
      });
    } catch (err: any) {
      console.warn('[TTS Service Warning] Gagal generate audio:', err?.message || err);
      return '';
    }
  }
}

export const ttsService = TtsService.getInstance();
