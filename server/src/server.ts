import { buildApp } from './app.js';
import { env } from './env.js';

async function main(): Promise<void> {
  const app = await buildApp();

  const close = async (signal: string): Promise<void> => {
    app.log.info(`received ${signal}, shutting down`);
    await app.close();
    process.exit(0);
  };
  process.on('SIGINT', () => void close('SIGINT'));
  process.on('SIGTERM', () => void close('SIGTERM'));

  try {
    await app.listen({ host: env.HOST, port: env.PORT });
  } catch (err) {
    app.log.error(err);
    process.exit(1);
  }
}

void main();
