import { loadConfig } from './config.js';
import { createDatabase } from './database.js';
import { installShutdownHandlers, startApplication } from './lifecycle.js';

async function main(): Promise<void> {
  const config = loadConfig(process.env);
  const database = createDatabase(config, () => console.error('Idle database connection failed.'));
  const app = await startApplication(config, database);
  installShutdownHandlers(app);
}

main().catch(() => {
  // Never print raw database URLs, SQL exceptions or session material.
  console.error('Startup failed. Check environment configuration and PostgreSQL connectivity.');
  process.exitCode = 1;
});
