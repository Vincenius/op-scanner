import { PrismaClient } from '@prisma/client';

/** Shared Prisma client for the ingestion job. */
export const prisma = new PrismaClient();
