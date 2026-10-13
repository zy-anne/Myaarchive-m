import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { Env } from './types';
import { authRouter } from './routes/auth';
import { assetsRouter } from './routes/assets';
import { dataRouter } from './routes/data';
import { rpcRouter } from './routes/rpc';

const app = new Hono<{ Bindings: Env }>();

// Enable CORS for all incoming client requests
app.use(
  '*',
  cors({
    origin: '*',
    allowHeaders: ['Authorization', 'Content-Type', 'If-None-Match', 'X-Requested-With'],
    allowMethods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    exposeHeaders: ['ETag', 'Content-Length', 'Content-Type'],
    maxAge: 86400,
  })
);

// Health check endpoint
app.get('/api/ping', (c) => {
  return c.json({
    status: 'ok',
    service: 'myaarchive-api',
    timestamp: new Date().toISOString(),
  });
});

// Mount modular sub-routers (the arbitrary-SQL proxy was removed: it could not enforce row ownership)
app.route('/api/auth', authRouter);
app.route('/api/assets', assetsRouter);
app.route('/api/data', dataRouter);
app.route('/api/rpc', rpcRouter);

// Global 404 handler
app.notFound((c) => {
  return c.json({ error: 'Endpoint not found' }, 404);
});

// Global error handler
app.onError((err, c) => {
  console.error('Unhandled Worker error:', err);
  return c.json(
    {
      error: err.message || 'Internal Server Error',
    },
    500
  );
});

export default app;
