import { loadConfig } from './config.js';
import { createDatabase } from './database.js';
import { readMigrations, runMigrations } from './migrations.js';

async function main(): Promise<void> {
  const config = loadConfig(process.env);
  const database = createDatabase(config, () => console.error('Idle database connection failed.'), 'migration');
  try {
    const count = await runMigrations(database, await readMigrations());
    console.info(`Applied ${count} migration(s).`);
  } finally {
    await database.close();
  }
}

main().catch(() => {
  console.error('Migration failed. Check configuration, connectivity and migration history.');
  process.exitCode = 1;
});
