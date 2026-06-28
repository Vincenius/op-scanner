import fp from 'fastify-plugin';
import { PrismaClient } from '@prisma/client';
import type { FastifyInstance } from 'fastify';

declare module 'fastify' {
  interface FastifyInstance {
    prisma: PrismaClient;
  }
}

/**
 * Decorates the Fastify instance with a connected PrismaClient and disconnects
 * it cleanly on shutdown.
 */
export default fp(
  async (app: FastifyInstance) => {
    const prisma = new PrismaClient();
    await prisma.$connect();
    app.decorate('prisma', prisma);
    app.addHook('onClose', async (instance) => {
      await instance.prisma.$disconnect();
    });
  },
  { name: 'prisma' },
);
