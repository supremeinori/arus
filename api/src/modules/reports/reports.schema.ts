import { z } from 'zod';

export const ReportTypeEnum = z.enum(['sales_summary', 'inventory_status', 'outlet_comparison']);
export type ReportType = z.infer<typeof ReportTypeEnum>;

export const generateReportSchema = z.object({
  type: ReportTypeEnum,
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
