// src/app.js
import express from 'express';
import cors from 'cors';
import authRoutes from './routes/authRoutes.js';
import biometricRoutes from './routes/biometricRoutes.js';
import { errorHandler } from './middleware/errorHandler.js';

const app = express();

// ── CORS config ───────────────────────────────────────────────────────────────
const corsOptions = {
  origin: (origin, callback) => {
    // Allow requests with no origin (Postman, mobile apps, curl)
    if (!origin) return callback(null, true);

    const allowed = [
      /^http:\/\/localhost(:\d+)?$/,       // Flutter web / iOS simulator
      /^http:\/\/127\.0\.0\.1(:\d+)?$/,   // alternate localhost
      /^http:\/\/10\.0\.2\.2(:\d+)?$/,    // Android emulator
    ];

    if (allowed.some((re) => re.test(origin))) {
      callback(null, true);
    } else {
      console.warn(`[CORS] Blocked: ${origin}`);
      callback(new Error(`CORS blocked for origin: ${origin}`));
    }
  },
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'Accept', 'Origin'],
  credentials: true,
  maxAge: 600,
};

// Apply CORS to every request (handles preflight automatically)
app.use(cors(corsOptions));

// ── Body parser ───────────────────────────────────────────────────────────────
app.use(express.json({ limit: '10mb' }));

// ── Health check ──────────────────────────────────────────────────────────────
app.get('/api/health', (_req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// ── Routes ────────────────────────────────────────────────────────────────────
app.use('/api/auth', authRoutes);
app.use('/api/biometric', biometricRoutes);

// ── Error handler ─────────────────────────────────────────────────────────────
app.use(errorHandler);

export default app;