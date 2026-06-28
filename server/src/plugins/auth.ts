import fp from 'fastify-plugin';
import jwt from '@fastify/jwt';
import type { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';
import { env } from '../env.js';

declare module '@fastify/jwt' {
  interface FastifyJWT {
    payload: { sub: string };
    user: { sub: string };
  }
}

declare module 'fastify' {
  interface FastifyInstance {
    /** preHandler that requires a valid access token; sets request.user. */
    authenticate: (req: FastifyRequest, reply: FastifyReply) => Promise<void>;
  }
}

/** Registers @fastify/jwt (access tokens) and an `authenticate` preHandler. */
export default fp(
  async (app: FastifyInstance) => {
    await app.register(jwt, { secret: env.JWT_ACCESS_SECRET });

    app.decorate('authenticate', async (req: FastifyRequest, reply: FastifyReply) => {
      try {
        await req.jwtVerify();
      } catch {
        await reply.code(401).send({ error: 'unauthorized' });
      }
    });
  },
  { name: 'auth' },
);
