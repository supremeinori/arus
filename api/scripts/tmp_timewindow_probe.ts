import { AiBusinessEngine } from '../src/modules/ai/ai_business_engine';

const e = new AiBusinessEngine();
const cases = [
  'gimana omset kemarin',
  'omset tanggal 1 kemarin',
  'omset tanggal 1',
  'omset 1 november',
  'omset 1 nov 2026',
  'omset 2026-10-28',
  'omset 28/10/2026',
  'omset 28/10',
  'omset tanggal 1 sampai 5',
  'omset 1-5 november',
  'omset 1 november sampai 5 november',
  'omset bulan ini',
  'omset bulan lalu',
  'omset minggu ini',
  'omset minggu lalu',
  'omset 7 hari terakhir',
  'omset 30 hari terakhir',
  'omset hari ini',
  'omset kemarin lusa',
  'omset tahun ini',
  'omset semua periode',
];

for (const c of cases) {
  const w = e.resolveTimeWindow(c, 'Asia/Jakarta');
  console.log(
    `${c.padEnd(42)} => ${w.label.padEnd(38)} ${w.from ? w.from.toISOString() : '-'} .. ${w.to ? w.to.toISOString() : '-'}`
  );
}
