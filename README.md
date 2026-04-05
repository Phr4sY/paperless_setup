# Paperless-Ngx Project with Ftp and OneDrive Automation

This repository contains the configuration for a self-hosted Paperless-ngx instance, an integrated FTP server for document ingestion, and a specialized Bash script for automated cloud backups and snapshots.

---

## Service Architecture

### Paperless-Ngx Stack

- **Image**: ghcr.io/paperless-ngx/paperless-ngx:latest
- **Database**: PostgreSQL 16 (stored in `./pgdata`)
- **Broker**: Redis 7 (stored in `./redisdata`)
- **Environment Configuration**:
  - **OCR Languages**: deu+eng
  - **Timezone**: Europe/Berlin
  - **Polling**: 10-second interval for the consume folder
- **Volumes**:
  - `./data` (Application data)
  - `./media` (Stored documents)
  - `./export` (Temporary export staging)
  - `./consume` (Document ingestion)

### FTP Server

- **Image**: delfer/alpine-ftp-server
- **Port Mapping**: Port 2121 (External) to 21 (Internal)
- **Passive Range**: 21000-21010
- **Integration**: Files uploaded to `/ftp/scanner` are instantly available in the Paperless `./consume` directory.

---

## Backup and Maintenance Script

The backup utility (`backup.sh`) manages the full lifecycle of your data.

### Configuration Defaults

- **Local Export Path**: `/paperless/export`
- **Rclone Binary**: Expected at `/paperless/rclone`
- **Rclone Config**: Expected at `/paperless/rclone.conf`
- **Retention**: 365 days for weekly archives

### Execution Workflow

1. **Container Export**: Executes `document_exporter` via sudo inside the `paperless_webserver_1` container.
2. **Permission Management**: Automatically runs `chown -R admin_nas:users` on the export directory to resolve Podman/Root permissions.
3. **Daily Differential**: Mirrors the export directory to `onedrive:MyNASBackups/Paperless/Daily_Sync`.
4. **Sunday Snapshot Logic**:
   - Detects day of week (7).
   - Creates a compressed tarball using the format: `paperless_weekly_YYYY-WW.tar.gz`.
   - Moves the archive to `onedrive:MyNASBackups/Paperless/Weekly_Snapshots`.
5. **Remote Retention**: Scans the archive folder and deletes files older than 365 days.
6. **Local Cleanup**: Recursively removes all files in the local `/export` folder to prevent storage bloat.

---

## Installation Requirements

### 1. Credentials

Credentials are read from a `.env` file in the project root (kept out of git). Create it and fill in your own values:

- `PAPERLESS_POSTGRES_DATABASE_NAME`, `PAPERLESS_POSTGRES_USER_NAME`, `PAPERLESS_POSTGRES_PASSWORD` — used by both the Postgres container and Paperless.
- `FTP_USERS` — FTP login in the format `user|password`.

### 2. Path Setup

Ensure the following directories exist and have correct permissions:

- `/paperless/export`
- Local directories: `./pgdata`, `./redisdata`, `./data`, `./media`, `./consume`

### 3. Deployment

```bash
docker-compose up -d
```
