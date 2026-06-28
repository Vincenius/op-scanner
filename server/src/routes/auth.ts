import type { FastifyInstance } from 'fastify';
import type { AuthResponse } from '@op-scanner/shared';
import { hashPassword, verifyPassword } from '../lib/password.js';
import {
  issueRefreshToken,
  revokeRefreshToken,
  rotateRefreshToken,
} from '../lib/tokens.js';
import { env } from '../env.js';

const credentialsSchema = {
  type: 'object',
  required: ['email', 'password'],
  properties: {
    email: { type: 'string', format: 'email' },
    password: { type: 'string', minLength: 8, maxLength: 200 },
  },
} as const;

const refreshSchema = {
  type: 'object',
  required: ['refreshToken'],
  properties: { refreshToken: { type: 'string' } },
} as const;

/** Parse "15m"/"3600"/"1h" to seconds for the client's expiry hint. */
function ttlSeconds(ttl: string): number {
  const m = /^(\d+)([smhd])?$/.exec(ttl.trim());
  if (!m) return 900;
  const n = Number(m[1]);
  switch (m[2]) {
    case 's': return n;
    case 'm': return n * 60;
    case 'h': return n * 3600;
    case 'd': return n * 86400;
    default: return n;
  }
}

export default async function authRoutes(app: FastifyInstance): Promise<void> {
  const accessTtl = ttlSeconds(env.ACCESS_TOKEN_TTL);
  // Used to equalize login timing when the email doesn't exist (no user-enumeration oracle).
  const dummyHash = await hashPassword('not-a-real-password');

  const authResponse = (
    userId: string,
    email: string,
    refreshToken: string,
  ): AuthResponse => ({
    accessToken: app.jwt.sign({ sub: userId }, { expiresIn: env.ACCESS_TOKEN_TTL }),
    refreshToken,
    accessTokenExpiresIn: accessTtl,
    user: { id: userId, email },
  });

  // POST /auth/register
  app.post<{ Body: { email: string; password: string } }>(
    '/auth/register',
    { schema: { tags: ['auth'], summary: 'Register', body: credentialsSchema } },
    async (request, reply) => {
      const email = request.body.email.trim().toLowerCase();
      if (await app.prisma.user.findUnique({ where: { email } })) {
        return reply.code(409).send({ error: 'email already registered' });
      }
      const user = await app.prisma.user.create({
        data: { email, passwordHash: await hashPassword(request.body.password) },
      });
      const refresh = await issueRefreshToken(app.prisma, user.id);
      return reply.code(201).send(authResponse(user.id, user.email, refresh.token));
    },
  );

  // POST /auth/login
  app.post<{ Body: { email: string; password: string } }>(
    '/auth/login',
    { schema: { tags: ['auth'], summary: 'Login', body: credentialsSchema } },
    async (request, reply) => {
      const email = request.body.email.trim().toLowerCase();
      const user = await app.prisma.user.findUnique({ where: { email } });
      if (!user) {
        await verifyPassword(dummyHash, request.body.password); // equalize timing
        return reply.code(401).send({ error: 'invalid credentials' });
      }
      const ok = await verifyPassword(user.passwordHash, request.body.password);
      if (!ok) {
        return reply.code(401).send({ error: 'invalid credentials' });
      }
      const refresh = await issueRefreshToken(app.prisma, user.id);
      return authResponse(user.id, user.email, refresh.token);
    },
  );

  // POST /auth/refresh  (rotation)
  app.post<{ Body: { refreshToken: string } }>(
    '/auth/refresh',
    { schema: { tags: ['auth'], summary: 'Rotate refresh token', body: refreshSchema } },
    async (request, reply) => {
      const rotated = await rotateRefreshToken(app.prisma, request.body.refreshToken);
      const user = rotated
        ? await app.prisma.user.findUnique({ where: { id: rotated.userId } })
        : null;
      if (!rotated || !user) {
        return reply.code(401).send({ error: 'invalid refresh token' });
      }
      return authResponse(user.id, user.email, rotated.token);
    },
  );

  // POST /auth/logout
  app.post<{ Body: { refreshToken: string } }>(
    '/auth/logout',
    { schema: { tags: ['auth'], summary: 'Revoke refresh token', body: refreshSchema } },
    async (request, reply) => {
      await revokeRefreshToken(app.prisma, request.body.refreshToken);
      return reply.code(204).send();
    },
  );
}
