import { query } from '@/lib/db';
import { randomUUID } from 'node:crypto';
import { ensureAppSettingsTable, getAppSetting, setAppSetting } from '@/lib/app_settings';

type OpsErrorLevel = 'error' | 'warn';

export interface OpsErrorLogInput {
    source: string;
    message: string;
    level?: OpsErrorLevel;
    requestPath?: string | null;
    details?: unknown;
}

export interface OpsErrorRow {
    id: string;
    source: string;
    level: OpsErrorLevel;
    message: string;
    request_path: string | null;
    details: unknown;
    created_at: string;
}

export interface OpsErrorStatsSnapshot {
    errors24h: number;
    warnings24h: number;
    backend: 'table' | 'settings' | 'none';
}

let opsLogsEnsured = false;
let ensurePromise: Promise<void> | null = null;
let opsLogsAvailable: boolean | null = null;
let settingsAvailable: boolean | null = null;

const OPS_ERROR_FALLBACK_KEY = 'ops_error_logs_fallback_v1';
const OPS_ERROR_FALLBACK_MAX = 500;

function isMissingRelation(error: any): boolean {
    return error?.code === '42P01';
}

function isInsufficientPrivilege(error: any): boolean {
    return error?.code === '42501';
}

async function canUseSettingsStore(): Promise<boolean> {
    if (settingsAvailable !== null) {
        return settingsAvailable;
    }
    try {
        await ensureAppSettingsTable();
        await query('SELECT 1 FROM app_settings LIMIT 1');
        settingsAvailable = true;
    } catch {
        settingsAvailable = false;
    }
    return settingsAvailable;
}

function parseFallbackRows(raw: string | null): OpsErrorRow[] {
    if (!raw) return [];
    try {
        const parsed = JSON.parse(raw);
        if (!Array.isArray(parsed)) return [];
        return parsed
            .filter((item) => item && typeof item === 'object')
            .map((item: any) => ({
                id: String(item.id || randomUUID()),
                source: String(item.source || 'unknown'),
                level: item.level === 'warn' ? 'warn' : 'error',
                message: String(item.message || ''),
                request_path: item.request_path ? String(item.request_path) : null,
                details: item.details ?? null,
                created_at: item.created_at ? String(item.created_at) : new Date().toISOString(),
            }));
    } catch {
        return [];
    }
}

async function readFallbackRows(): Promise<OpsErrorRow[]> {
    if (!(await canUseSettingsStore())) {
        return [];
    }
    const raw = await getAppSetting(OPS_ERROR_FALLBACK_KEY);
    return parseFallbackRows(raw);
}

async function writeFallbackRows(rows: OpsErrorRow[]): Promise<void> {
    if (!(await canUseSettingsStore())) {
        return;
    }
    await setAppSetting(OPS_ERROR_FALLBACK_KEY, JSON.stringify(rows.slice(0, OPS_ERROR_FALLBACK_MAX)));
}

async function appendFallbackRow(input: OpsErrorLogInput): Promise<void> {
    if (!(await canUseSettingsStore())) {
        return;
    }
    const rows = await readFallbackRows();
    rows.unshift({
        id: randomUUID(),
        source: input.source,
        level: input.level ?? 'error',
        message: input.message,
        request_path: input.requestPath ?? null,
        details: input.details ?? null,
        created_at: new Date().toISOString(),
    });
    await writeFallbackRows(rows);
}

async function ensureOpsLogsTableInternal(): Promise<void> {
    await query(`
        CREATE TABLE IF NOT EXISTS ops_error_logs (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            source VARCHAR(120) NOT NULL,
            level VARCHAR(16) NOT NULL DEFAULT 'error'
                CHECK (level IN ('error', 'warn')),
            message TEXT NOT NULL,
            request_path TEXT,
            details JSONB,
            created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
        )
    `);
    await query(`
        CREATE INDEX IF NOT EXISTS idx_ops_error_logs_created_at
        ON ops_error_logs(created_at DESC)
    `);
    await query(`
        CREATE INDEX IF NOT EXISTS idx_ops_error_logs_source
        ON ops_error_logs(source, created_at DESC)
    `);
}

export async function ensureOpsLogsTable(): Promise<void> {
    if (opsLogsEnsured) {
        return;
    }

    if (!ensurePromise) {
        ensurePromise = (async () => {
            try {
                await query('SELECT 1 FROM ops_error_logs LIMIT 1');
                opsLogsAvailable = true;
                opsLogsEnsured = true;
                return;
            } catch (error: any) {
                if (!isMissingRelation(error)) {
                    throw error;
                }
            }

            try {
                await ensureOpsLogsTableInternal();
                opsLogsAvailable = true;
            } catch (error: any) {
                if (!isInsufficientPrivilege(error)) {
                    throw error;
                }
                // Hosted production may not allow CREATE in public schema.
                opsLogsAvailable = false;
            }

            opsLogsEnsured = true;
        })()
            .finally(() => {
                ensurePromise = null;
            });
    }

    await ensurePromise;
}

export async function hasOpsLogsTable(): Promise<boolean> {
    if (!opsLogsEnsured) {
        await ensureOpsLogsTable();
    }
    return Boolean(opsLogsAvailable);
}

export async function logOpsError(input: OpsErrorLogInput): Promise<void> {
    try {
        await ensureOpsLogsTable();
        if (!(await hasOpsLogsTable())) {
            await appendFallbackRow(input);
            return;
        }
        await query(
            `
                INSERT INTO ops_error_logs (source, level, message, request_path, details)
                VALUES ($1, $2, $3, $4, $5::jsonb)
            `,
            [
                input.source,
                input.level ?? 'error',
                input.message,
                input.requestPath ?? null,
                JSON.stringify(input.details ?? null),
            ]
        );
    } catch (e) {
        console.error('Failed to persist ops error log', e);
    }
}

export async function getOpsErrorRows(options?: {
    source?: string | null;
    limit?: number;
}): Promise<OpsErrorRow[]> {
    const source = options?.source?.trim() || '';
    const limit = Number.isFinite(options?.limit)
        ? Math.min(Math.max(Math.trunc(options!.limit as number), 1), 500)
        : 100;

    await ensureOpsLogsTable();
    if (await hasOpsLogsTable()) {
        const params: unknown[] = [];
        let where = '';
        if (source) {
            params.push(source);
            where = `WHERE source = $${params.length}`;
        }
        params.push(limit);
        const res = await query(
            `
                SELECT
                    id,
                    source,
                    level,
                    message,
                    request_path,
                    details,
                    created_at
                FROM ops_error_logs
                ${where}
                ORDER BY created_at DESC
                LIMIT $${params.length}
            `,
            params as any[]
        );
        return res.rows as OpsErrorRow[];
    }

    const fallback = await readFallbackRows();
    return fallback
        .filter((item) => !source || item.source === source)
        .sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime())
        .slice(0, limit);
}

export async function getOpsErrorStatsSnapshot(): Promise<OpsErrorStatsSnapshot> {
    await ensureOpsLogsTable();
    if (await hasOpsLogsTable()) {
        const res = await query(
            `
                SELECT
                    COUNT(*) FILTER (WHERE level = 'error')::int AS errors_24h,
                    COUNT(*) FILTER (WHERE level = 'warn')::int AS warnings_24h
                FROM ops_error_logs
                WHERE created_at >= NOW() - INTERVAL '24 hours'
            `
        );
        return {
            errors24h: Number(res.rows[0]?.errors_24h || 0),
            warnings24h: Number(res.rows[0]?.warnings_24h || 0),
            backend: 'table',
        };
    }

    if (await canUseSettingsStore()) {
        const now = Date.now();
        const fallback = await readFallbackRows();
        const in24h = fallback.filter(
            (item) => now - new Date(item.created_at).getTime() <= 24 * 60 * 60 * 1000
        );
        return {
            errors24h: in24h.filter((item) => item.level === 'error').length,
            warnings24h: in24h.filter((item) => item.level === 'warn').length,
            backend: 'settings',
        };
    }

    return {
        errors24h: 0,
        warnings24h: 0,
        backend: 'none',
    };
}
