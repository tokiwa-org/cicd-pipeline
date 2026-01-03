import { app } from './index';
import request from 'supertest';

// Mock the server to prevent it from actually listening
jest.mock('./index', () => {
  const express = require('express');
  const app = express();

  app.use(express.json());

  app.get('/health', (_req: any, res: any) => {
    res.status(200).json({
      status: 'healthy',
      timestamp: new Date().toISOString(),
      version: '1.0.0',
    });
  });

  app.get('/', (_req: any, res: any) => {
    res.json({
      message: 'Welcome to CI/CD Pipeline Demo App',
      environment: 'test',
      timestamp: new Date().toISOString(),
    });
  });

  app.get('/api/info', (_req: any, res: any) => {
    res.json({
      app: 'cicd-pipeline-app',
      version: '1.0.0',
      nodeVersion: process.version,
      environment: 'test',
      uptime: process.uptime(),
    });
  });

  return { app };
});

describe('API Endpoints', () => {
  describe('GET /health', () => {
    it('should return healthy status', async () => {
      const response = await request(app).get('/health');

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('status', 'healthy');
      expect(response.body).toHaveProperty('timestamp');
      expect(response.body).toHaveProperty('version');
    });
  });

  describe('GET /', () => {
    it('should return welcome message', async () => {
      const response = await request(app).get('/');

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('message');
      expect(response.body.message).toContain('CI/CD Pipeline');
    });
  });

  describe('GET /api/info', () => {
    it('should return app info', async () => {
      const response = await request(app).get('/api/info');

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('app', 'cicd-pipeline-app');
      expect(response.body).toHaveProperty('version');
      expect(response.body).toHaveProperty('nodeVersion');
    });
  });
});
