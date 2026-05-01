# Operations Runbook

## 1) Database Backup

Prerequisites:
- PostgreSQL client tools installed (`pg_dump` in PATH)
- `DATABASE_URL` set in environment

Run manually:

```powershell
cd web
npm run backup:db
```

Schedule daily backup on Windows server:

```powershell
cd web
npm run backup:db:schedule
```

Optional arguments:

```powershell
powershell -ExecutionPolicy Bypass -File ./scripts/backup_postgres.ps1 -OutputDir "./backups" -KeepDays 14
```

Output:
- Creates zipped SQL backup in `web/backups`
- Prunes backups older than `KeepDays`

## 2) API/Webhook Error Monitoring

The backend now persists operational errors in `ops_error_logs`.

Admin API:
- `GET /api/admin/ops-errors?limit=200`

Admin dashboard page:
- `/admin/ops-errors`

Suggested daily check:
1. Open `/admin/ops-errors`
2. Investigate repeated `api.payments.webhook` or `api.checkout` errors
3. Resolve gateway credentials/webhook secret/network issues

## 3) Go-Live Readiness Check

Admin API:
- `GET /api/admin/readiness`

Admin dashboard page:
- `/admin/readiness`

Use this page before release to verify:
1. Required environment keys
2. Database connectivity
3. Online payment readiness (provider/base URL/API key/webhook)
4. Backup freshness
5. Recent operational errors
