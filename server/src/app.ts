import Fastify, { type FastifyInstance } from 'fastify';
import cors from '@fastify/cors';
import swagger from '@fastify/swagger';
import swaggerUi from '@fastify/swagger-ui';
import { env } from './env.js';
import prismaPlugin from './plugins/prisma.js';
import healthRoutes from './routes/health.js';
import catalogRoutes from './routes/catalog.js';
import imageRoutes from './routes/images.js';

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
      ],
    },
  });
  await app.register(swaggerUi, { routePrefix: '/docs' });

  await app.register(prismaPlugin);

  // Routes
  await app.register(healthRoutes);
  await app.register(catalogRoutes);
  await app.register(imageRoutes);

  return app;
}
