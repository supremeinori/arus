import { describe, it, expect } from 'vitest';
import request from 'supertest';
import app from '../src/app';

describe('GET /api/health', () => {
  it('harus mengembalikan status 200 dan data health check', async () => {
    const response = await request(app).get('/api/health');

    expect(response.status).toBe(200);
    expect(response.body).toHaveProperty('data');
    expect(response.body.data.status).toBe('ok');
    expect(response.body.data).toHaveProperty('time');
  });

  it('harus mengembalikan 404 dengan format standard untuk rute tidak dikenal', async () => {
    const response = await request(app).get('/api/unknown-endpoint');

    expect(response.status).toBe(404);
    expect(response.body).toHaveProperty('error');
    expect(response.body.error.code).toBe('NOT_FOUND');
  });
});
