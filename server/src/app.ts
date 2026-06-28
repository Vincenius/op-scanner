import Fastify, { type FastifyError, type FastifyInstance } from 'fastify';
import cors from '@fastify/cors';
import rateLimit from '@fastify/rate-limit';
import swagger from '@fastify/swagger';
import swaggerUi from '@fastify/swagger-ui';
import { env } from './env.js';
import prismaPlugin from './plugins/prisma.js';
import authPlugin from './plugins/auth.js';
import healthRoutes from './routes/health.js';
import catalogRoutes from './routes/catalog.js';
import imageRoutes from './routes/images.js';
import authRoutes from './routes/auth.js';
import collectionRoutes from './routes/collection.js';
import shareRoutes from './routes/share.js';

/**
 * Builds and configures the Fastify application (without starting it), so it
 * can be reused from tests as well as the server entrypoint.
 */
export async function buildApp(): Promise<FastifyInstance> {
  const app = Fastify({
    logger: {
      level: env.NODE_ENV === 'production' ? 'info' : 'debug',
      transport:
        env.NODE_ENV === 'development' ? { target: 'pino-pretty' } : undefined,
    },
  });

  await app.register(cors, {
    origin: env.CORS_ORIGIN === '*' ? true : env.CORS_ORIGIN.split(','),
  });

  // Basic per-IP rate limiting (protects /auth and the public /share endpoint).
  await app.register(rateLimit, { max: env.RATE_LIMIT_MAX, timeWindow: '1 minute' });

  // Don't leak internals on unexpected errors; keep 4xx (validation) messages.
  app.setErrorHandler((error: FastifyError, request, reply) => {
    const status = error.statusCode ?? 500;
    if (status >= 500) {
      request.log.error(error);
      return reply.code(500).send({ error: 'internal server error' });
    }
    return reply.code(status).send({ error: error.message });
  });

  await app.register(swagger, {
    openapi: {
      info: {
        title: 'OP Scanner API',
        description: 'One Piece TCG collection manager API.',
        version: '0.0.0',
      },
      tags: [
        { name: 'system', description: 'Health & diagnostics' },
        { name: 'catalog', description: 'Sets, cards, variants, prices, sync' },
        { name: 'images', description: 'Proxied card images' },
        { name: 'auth', description: 'Registration, login, token rotation' },
        { name: 'collection', description: 'User collection + offline sync' },
        { name: 'share', description: 'Public read-only collection sharing' },
      ],
      components: {
        securitySchemes: {
          bearerAuth: { type: 'http', scheme: 'bearer', bearerFormat: 'JWT' },
        },
      },
    },
  });
  await app.register(swaggerUi, { routePrefix: '/docs' });

  await app.register(prismaPlugin);
  await app.register(authPlugin);

  // Routes
  await app.register(healthRoutes);
  await app.register(catalogRoutes);
  await app.register(imageRoutes);
  await app.register(authRoutes);
  await app.register(collectionRoutes);
  await app.register(shareRoutes);

  return app;
}
