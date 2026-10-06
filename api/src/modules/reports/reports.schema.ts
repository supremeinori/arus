import { z } from 'zod';
import { ReportType } from '@prisma/client';

export const generateReportSchema = z.object({
  type: z.nativeEnum(ReportType, {
    errorMap: () => ({ message: 'Tipe laporan harus sales_summary, inventory_status, atau outlet_comparison.' }),
  }),
  title: z.string().min(1, 'Judul laporan tidak boleh kosong').optional(),
  period_from: z.string().refine((val) => !isNaN(Date.parse(val)), {
    message: 'period_from harus berupa format tanggal valid (YYYY-MM-DD atau ISO).',
  }),
  period_to: z.string().refine((val) => !isNaN(Date.parse(val)), {
    message: 'period_to harus berupa format tanggal valid (YYYY-MM-DD atau ISO).',
  }),
  outlet_ids: z.array(z.string().uuid('ID outlet harus UUID valid')).optional(),
});

export type GenerateReportInput = z.infer<typeof generateReportSchema>;
