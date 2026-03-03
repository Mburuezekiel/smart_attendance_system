
export const errorHandler = (err, req, res, next) => { // ← all 4 are required
  console.error(`[ERROR] ${req.method} ${req.path} →`, err.message);

  // CORS errors (thrown by our cors origin callback)
  if (err.message?.startsWith('CORS blocked')) {
    return res.status(403).json({ message: err.message });
  }

  const statusCode = res.statusCode && res.statusCode !== 200
    ? res.statusCode
    : 500;

  res.status(statusCode).json({
    message: err.message || 'Internal Server Error',
    ...(process.env.NODE_ENV === 'development' && { stack: err.stack }),
  });
};