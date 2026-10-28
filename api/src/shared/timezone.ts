/**
 * Helper zona waktu IANA untuk mendukung multi-cabang ARUS:
 * - Yogyakarta: Asia/Jakarta (WIB, UTC+7)
 * - Denpasar: Asia/Makassar (WITA, UTC+8)
 * - Jayapura: Asia/Jayapura (WIT, UTC+9)
 * - London: Europe/London (GMT/BST, UTC+0 / UTC+1)
 */

export function getTimezoneOffsetHours(tz: string, targetDate: Date = new Date()): number {
  try {
    const formatter = new Intl.DateTimeFormat('en-CA', {
      timeZone: tz,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    });
    const dateStr = formatter.format(targetDate);
    const probe = new Date(`${dateStr}T12:00:00Z`);

    const dtf = new Intl.DateTimeFormat('en-US', {
      timeZone: tz,
      hourCycle: 'h23',
      year: 'numeric',
      month: 'numeric',
      day: 'numeric',
      hour: 'numeric',
      minute: 'numeric',
    });
    const parts = dtf.formatToParts(probe);
    const hourPart = parts.find((p) => p.type === 'hour');
    if (hourPart) {
      const hour = parseInt(hourPart.value, 10);
      return hour - 12;
    }
  } catch {
    // Fallback WIB jika format tz tidak valid
  }
  return 7;
}

export function getTodayDateStrInTimezone(tz: string, targetDate: Date = new Date()): string {
  try {
    return new Intl.DateTimeFormat('en-CA', {
      timeZone: tz,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    }).format(targetDate);
  } catch {
    return targetDate.toISOString().slice(0, 10);
  }
}

export function getStartOfDayInTimezone(tz: string, targetDate: Date = new Date()): Date {
  const dateStr = getTodayDateStrInTimezone(tz, targetDate);
  const offset = getTimezoneOffsetHours(tz, targetDate);
  const startOfDayUtc = new Date(`${dateStr}T00:00:00.000Z`);
  startOfDayUtc.setUTCHours(startOfDayUtc.getUTCHours() - offset);
  return startOfDayUtc;
}

export function getEndOfDayInTimezone(tz: string, targetDate: Date = new Date()): Date {
  const dateStr = getTodayDateStrInTimezone(tz, targetDate);
  const offset = getTimezoneOffsetHours(tz, targetDate);
  const endOfDayUtc = new Date(`${dateStr}T23:59:59.999Z`);
  endOfDayUtc.setUTCHours(endOfDayUtc.getUTCHours() - offset);
  return endOfDayUtc;
}
