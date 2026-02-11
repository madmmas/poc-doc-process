# PostgreSQL init scripts

Scripts here run once when the Postgres container is created (first start with an empty data volume).

- **Order:** Run in filename order (e.g. `01-schema.sql`, `02-seed.sql`).
- **Formats:** `.sql`, `.sh`, or `.sql.gz` (see [postgres image docs](https://hub.docker.com/_/postgres)).
- **Database:** Scripts run as `POSTGRES_USER` (postgres) and against `POSTGRES_DB` (postgres) unless you change DB inside the script.

Add your schema and seed SQL files in this folder.
