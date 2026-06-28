import type { FastifyInstance } from 'fastify';

/**
 * Liveness and readiness probes.
 *   GET /health        — process is up (no dependencies checked).
 *   GET /health/ready  — verifies database connectivity.
 */
export default async function healthRoutes(app: FastifyInstance): Promise<void> {
  app.get(
    '/health',
    {
      schema: {
        tags: ['system'],
        summary: 'Liveness check',
        response: {
          200: {
            type: 'object',
            properties: {
              status: { type: 'string' },
              uptime: { type: 'number' },
            },
          },
        },
      },
    },
    async () => ({ status: 'ok', uptime: process.uptime() }),
  );

  app.get(
    '/health/ready',
    {
      schema: {
        tags: ['system'],
        summary: 'Readiness check (verifies DB connectivity)',
      },
    },
    async (request, reply) => {
      try {
        await app.prisma.$queryRaw`SELECT 1`;
        return { status: 'ready', db: 'up' };
      } catch (err) {
        request.log.error({ err }, 'readiness check failed');
        reply.code(503);
        return { status: 'unavailable', db: 'down' };
      }
    },
  );
}
