// src/app.js
import express from 'express';
import cors from 'cors';
import authRoutes from './routes/authRoutes.js';
import biometricRoutes from './routes/biometricRoutes.js';
import { errorHandler } from './middleware/errorHandler.js';

const app = express();

// ── CORS ───────────────────────────────────────────────────────────────────────
// origin: true  reflects the incoming Origin back — allows all origins while
// still honouring credentials: true.
// DO NOT use the callback form of `origin` — it breaks in Express 5 / router v2
// because the callback executes outside the middleware chain and `next` is lost.
app.use(cors({
  origin: true,                  // ← KEY FIX: no callback, just true
  methods: ['GET','POST','PUT','PATCH','DELETE','OPTIONS'],
  allowedHeaders: ['Content-Type','Authorization','Accept','Origin'],
  credentials: true,
  maxAge: 600,
}));

// ── Body parser ────────────────────────────────────────────────────────────────
app.use(express.json({ limit: '10mb' }));

// ── Health check ───────────────────────────────────────────────────────────────
app.get('/api/health', (_req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// ── Routes ─────────────────────────────────────────────────────────────────────
app.use('/api/auth', authRoutes);
app.use('/api/biometric', biometricRoutes);

// ── Error handler (4 params — must be last) ────────────────────────────────────
app.use(errorHandler);

export default app;