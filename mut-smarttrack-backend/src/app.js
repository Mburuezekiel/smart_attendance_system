// src/app.js
import express from 'express';
import authRoutes from './routes/authRoutes.js';
import biometricRoutes from './routes/biometricRoutes.js';
import { errorHandler } from './middleware/errorHandler.js';

const app = express();

// ── Manual CORS (replaces cors package — incompatible with Express 5) ─────────
app.use((req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', req.headers.origin || '*');
  res.setHeader('Access-Control-Allow-Credentials', 'true');
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,PUT,PATCH,DELETE,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type,Authorization,Accept,Origin');
  res.setHeader('Access-Control-Max-Age', '600');
  if (req.method === 'OPTIONS') return res.sendStatus(204);
  next();
});

// ── Body parser ────────────────────────────────────────────────────────────────
app.use(express.json({ limit: '10mb' }));

// ── Health check ───────────────────────────────────────────────────────────────
app.get('/api/health', (_req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// ── Routes ─────────────────────────────────────────────────────────────────────
app.use('/api/auth', authRoutes);
app.use('/api/biometric', biometricRoutes);

// ── Error handler ──────────────────────────────────────────────────────────────
app.use(errorHandler);

export default app;