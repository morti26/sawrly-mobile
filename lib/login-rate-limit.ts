import { NextRequest } from 'next/server';
import { getClient, query } from '@/lib/db';
import { ensureAppSettingsTable } from '@/lib/app_settings';

const LOGIN_WINDOW_MS = 15 * 60 * 1000;
const LOGIN_BLOCK_MS = 15 * 60 * 1000;
const LOGIN_MAX_ATTEMPTS = 8;
const MAX_ENTRIES = 10_000;
const RATE_LIMIT_SETTING_KEY = 'login_rate_limit_state_v1';

type LoginRateLimitBackend = 'database' | 'memory';

interface LoginAttemptState {
    attempts: number;
    firstAttemptAt: number;
    blockedUntil: number;
}

const attemptsByKey = new Map<string, LoginAttemptState>();
let backendPromise: Promise<LoginRateLimitBackend> | null = null;

function getClientIp(req: NextRequest): string {
    const forwardedFor = req.headers.get('x-forwarded-for');
    if (forwardedFor) {
        return forwardedFor.split(',')[0].trim();
    }

    const realIp = req.headers.get('x-real-ip');
    if (realIp) {
        return realIp.trim();
    }

    return 'unknown';
}

function pruneAttempts(now: number): void {
    attemptsByKey.forEach((entry, key) => {
        const windowExpired = now - entry.firstAttemptAt > LOGIN_WINDOW_MS;
        const blockExpired = entry.blockedUntil > 0 && now >= entry.blockedUntil;
        if (windowExpired || blockExpired) {
            attemptsByKey.delete(key);
        }
    });
}

function parseDbState(raw: string | null): Record<string, LoginAttemptState> {
    if (!raw) return {};

    try {
        const parsed = JSON.parse(raw) as Record<string, any>;
        if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
            return {};
        }

        const safe: Record<string, LoginAttemptState> = {};
        for (const [key, value] of Object.entries(parsed)) {
            const attempts = Number((value as any)?.attempts);
            const firstAttemptAt = Number((value as any)?.firstAttemptAt);
            const blockedUntil = Number((value as any)?.blockedUntil);
            if (!Number.isFinite(attempts) || !Number.isFinite(firstAttemptAt) || !Number.isFinite(blockedUntil)) {
                continue;
            }
            safe[key] = {
                attempts: Math.max(0, Math.trunc(attempts)),
                firstAttemptAt: Math.max(0, Math.trunc(firstAttemptAt)),
                blockedUntil: Math.max(0, Math.trunc(blockedUntil)),
            };
        }
        return safe;
    } catch {
        return {};
    }
}

function pruneDbState(state: Record<string, LoginAttemptState>, now: number): boolean {
    let dirty = false;
    for (const [key, entry] of Object.entries(state)) {
        const windowExpired = now - entry.firstAttemptAt > LOGIN_WINDOW_MS;
        const blockExpired = entry.blockedUntil > 0 && now >= entry.blockedUntil;
        if (windowExpired || blockExpired) {
            delete state[key];
            dirty = true;
        }
    }
    return dirty;
}

function enforceMaxEntries(state: Record<string, LoginAttemptState>): boolean {
    const keys = Object.keys(state);
    if (keys.length <= MAX_ENTRIES) {
        return false;
    }

    keys
        .sort((a, b) => state[a].firstAttemptAt - state[b].firstAttemptAt)
        .slice(0, keys.length - MAX_ENTRIES)
        .forEach((key) => {
            delete state[key];
        });
    return true;
}

async function resolveBackend(): Promise<LoginRateLimitBackend> {
    if (!backendPromise) {
        backendPromise = (async () => {
            try {
                await ensureAppSettingsTable();
                await query('SELECT 1 FROM app_settings LIMIT 1');
                return 'database' as const;
            } catch {
                return 'memory' as const;
            }
        })();
    }
    return backendPromise;
}

export async function getLoginRateLimitBackend(): Promise<LoginRateLimitBackend> {
    return resolveBackend();
}

async function loadDbStateForUpdate(client: Awaited<ReturnType<typeof getClient>>): Promise<{
    state: Record<string, LoginAttemptState>;
    hadRow: boolean;
}> {
    const res = await client.query(
        'SELECT setting_value FROM app_settings WHERE setting_key = $1 FOR UPDATE',
        [RATE_LIMIT_SETTING_KEY]
    );

    return {
        state: parseDbState(res.rows[0]?.setting_value ?? null),
        hadRow: (res.rowCount ?? 0) > 0,
    };
}

async function persistDbState(
    client: Awaited<ReturnType<typeof getClient>>,
    state: Record<string, LoginAttemptState>
): Promise<void> {
    await client.query(
        `
            INSERT INTO app_settings (setting_key, setting_value, updated_at)
            VALUES ($1, $2, CURRENT_TIMESTAMP)
            ON CONFLICT (setting_key)
            DO UPDATE SET
                setting_value = EXCLUDED.setting_value,
                updated_at = CURRENT_TIMESTAMP
        `,
        [RATE_LIMIT_SETTING_KEY, JSON.stringify(state)]
    );
}

export function buildLoginRateLimitKey(req: NextRequest, normalizedEmail: string): string {
    return `${getClientIp(req)}:${normalizedEmail || 'unknown'}`;
}

function checkLoginRateLimitMemory(rateLimitKey: string): { blocked: boolean; retryAfterSeconds: number } {
    const now = Date.now();
    pruneAttempts(now);

    const entry = attemptsByKey.get(rateLimitKey);
    if (!entry || entry.blockedUntil <= now) {
        return { blocked: false, retryAfterSeconds: 0 };
    }

    return {
        blocked: true,
        retryAfterSeconds: Math.max(1, Math.ceil((entry.blockedUntil - now) / 1000)),
    };
}

async function checkLoginRateLimitDb(rateLimitKey: string): Promise<{ blocked: boolean; retryAfterSeconds: number }> {
    const client = await getClient();
    try {
        await client.query('BEGIN');

        const now = Date.now();
        const { state, hadRow } = await loadDbStateForUpdate(client);
        let dirty = pruneDbState(state, now);

        const entry = state[rateLimitKey];
        let result: { blocked: boolean; retryAfterSeconds: number };
        if (!entry || entry.blockedUntil <= now) {
            if (entry && entry.blockedUntil <= now) {
                delete state[rateLimitKey];
                dirty = true;
            }
            result = { blocked: false, retryAfterSeconds: 0 };
        } else {
            result = {
                blocked: true,
                retryAfterSeconds: Math.max(1, Math.ceil((entry.blockedUntil - now) / 1000)),
            };
        }

        dirty = enforceMaxEntries(state) || dirty;
        if (dirty || !hadRow) {
            await persistDbState(client, state);
        }

        await client.query('COMMIT');
        return result;
    } catch {
        await client.query('ROLLBACK').catch(() => undefined);
        throw new Error('DB_RATE_LIMIT_FAILED');
    } finally {
        client.release();
    }
}

export async function checkLoginRateLimit(rateLimitKey: string): Promise<{ blocked: boolean; retryAfterSeconds: number }> {
    if ((await resolveBackend()) === 'memory') {
        return checkLoginRateLimitMemory(rateLimitKey);
    }

    try {
        return await checkLoginRateLimitDb(rateLimitKey);
    } catch {
        return checkLoginRateLimitMemory(rateLimitKey);
    }
}

function recordLoginFailureMemory(rateLimitKey: string): void {
    const now = Date.now();
    if (attemptsByKey.size > MAX_ENTRIES) {
        pruneAttempts(now);
    }

    const entry = attemptsByKey.get(rateLimitKey);
    if (!entry || now - entry.firstAttemptAt > LOGIN_WINDOW_MS) {
        attemptsByKey.set(rateLimitKey, {
            attempts: 1,
            firstAttemptAt: now,
            blockedUntil: 0,
        });
        return;
    }

    entry.attempts += 1;
    if (entry.attempts >= LOGIN_MAX_ATTEMPTS) {
        entry.attempts = 0;
        entry.firstAttemptAt = now;
        entry.blockedUntil = now + LOGIN_BLOCK_MS;
    }

    attemptsByKey.set(rateLimitKey, entry);
}

async function recordLoginFailureDb(rateLimitKey: string): Promise<void> {
    const client = await getClient();
    try {
        await client.query('BEGIN');

        const now = Date.now();
        const { state } = await loadDbStateForUpdate(client);
        pruneDbState(state, now);

        const entry = state[rateLimitKey];
        if (!entry || now - entry.firstAttemptAt > LOGIN_WINDOW_MS) {
            state[rateLimitKey] = {
                attempts: 1,
                firstAttemptAt: now,
                blockedUntil: 0,
            };
        } else {
            entry.attempts += 1;
            if (entry.attempts >= LOGIN_MAX_ATTEMPTS) {
                entry.attempts = 0;
                entry.firstAttemptAt = now;
                entry.blockedUntil = now + LOGIN_BLOCK_MS;
            }
            state[rateLimitKey] = entry;
        }

        enforceMaxEntries(state);
        await persistDbState(client, state);
        await client.query('COMMIT');
    } catch {
        await client.query('ROLLBACK').catch(() => undefined);
        throw new Error('DB_RATE_LIMIT_FAILED');
    } finally {
        client.release();
    }
}

export async function recordLoginFailure(rateLimitKey: string): Promise<void> {
    if ((await resolveBackend()) === 'memory') {
        recordLoginFailureMemory(rateLimitKey);
        return;
    }

    try {
        await recordLoginFailureDb(rateLimitKey);
    } catch {
        recordLoginFailureMemory(rateLimitKey);
    }
}

function clearLoginFailuresMemory(rateLimitKey: string): void {
    attemptsByKey.delete(rateLimitKey);
}

async function clearLoginFailuresDb(rateLimitKey: string): Promise<void> {
    const client = await getClient();
    try {
        await client.query('BEGIN');
        const { state } = await loadDbStateForUpdate(client);
        if (state[rateLimitKey]) {
            delete state[rateLimitKey];
            await persistDbState(client, state);
        }
        await client.query('COMMIT');
    } catch {
        await client.query('ROLLBACK').catch(() => undefined);
        throw new Error('DB_RATE_LIMIT_FAILED');
    } finally {
        client.release();
    }
}

export async function clearLoginFailures(rateLimitKey: string): Promise<void> {
    if ((await resolveBackend()) === 'memory') {
        clearLoginFailuresMemory(rateLimitKey);
        return;
    }

    try {
        await clearLoginFailuresDb(rateLimitKey);
    } catch {
        clearLoginFailuresMemory(rateLimitKey);
    }
}
