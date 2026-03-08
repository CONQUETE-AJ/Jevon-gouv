# OpenMetadata Enterprise (minimal)

This folder contains a minimal deployment set for enterprise-like environments:
- Postgres (metastore)
- OpenSearch or Elasticsearch (search)
- OpenMetadata server + migration
- Optional ingestion runtime (`--with-ingestion`)

Start from repo root:

```bash
./start.sh                      # Elasticsearch + server + migrations
./start.sh --search opensearch   # switch search backend
./start.sh --with-ingestion      # add ingestion runtime
./start.sh down                  # stop and remove containers
./start.sh logs                  # follow logs
```

UI is served by `openmetadata-server` on port 8585 by default.

Default access:
- UI: `http://localhost:8585`
- Health: `http://localhost:8586/healthcheck`
- Email: `admin@open-metadata.org`
- Password: `admin`

If you change credentials or database names in `.env`, run `./start.sh --clean up` once to recreate
volumes so Postgres bootstrap scripts re-apply cleanly.
