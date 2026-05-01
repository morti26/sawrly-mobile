import fs from 'node:fs/promises';
import path from 'node:path';
import { query } from '@/lib/db';
import { APP_SETTING_KEYS, getAppSetting } from '@/lib/app_settings';
import { isPaymentApiKeyConfigured } from '@/lib/payment-key-crypto';
import { getPaymentRuntimeConfig } from '@/lib/payment-runtime';
import { getOpsErrorStatsSnapshot } from '@/lib/ops-monitoring';
import { getLoginRateLimitBackend } from '@/lib/login-rate-limit';

export type ReadinessStatus = 'ok' | 'warn' | 'fail';

export interface ReadinessCheck {
    id: string;
    title: string;
    status: ReadinessStatus;
    details: string;
    action?: string;
}

export interface ReadinessReport {
    generatedAt: string;
    readyForManualPayments: boolean;
    readyForOnlinePayments: boolean;
    checks: ReadinessCheck[];
}

const REQUIRED_ENV_KEYS = [
    'DATABASE_URL',
    'JWT_SECRET',
    'APP_SETTINGS_ENCRYPTION_KEY',
    'NEXT_PUBLIC_APP_URL',
] as const;

type BackupMeta = {
    fileName: string;
    mtime: Date;
    ageHours: number;
} | null;

function trimEnv(name: string): string {
    return (process.env[name] || '').trim();
}

async function getLatestBackupMeta(): Promise<BackupMeta> {
    const backupDir = path.join(process.cwd(), 'backups');
    let entries: Array<{ name: string; mtime: Date }> = [];
    try {
        const dirEntries = await fs.readdir(backupDir, { withFileTypes: true });
        for (const entry of dirEntries) {
            if (!entry.isFile()) continue;
            const fullPath = path.join(backupDir, entry.name);
            const stat = await fs.stat(fullPath);
            entries.push({ name: entry.name, mtime: stat.mtime });
        }
    } catch {
        return null;
    }

    if (entries.length === 0) {
        return null;
    }

    entries = entries.sort((a, b) => b.mtime.getTime() - a.mtime.getTime());
    const latest = entries[0];
    const ageMs = Date.now() - latest.mtime.getTime();
    return {
        fileName: latest.name,
        mtime: latest.mtime,
        ageHours: ageMs / (1000 * 60 * 60),
    };
}

function isUrlLike(value: string): boolean {
    return /^https?:\/\//i.test(value);
}

function pushCheck(target: ReadinessCheck[], check: ReadinessCheck): void {
    target.push(check);
}

export async function buildReadinessReport(): Promise<ReadinessReport> {
    const checks: ReadinessCheck[] = [];

    const missingEnv = REQUIRED_ENV_KEYS.filter((key) => trimEnv(key).length === 0);
    pushCheck(checks, {
        id: 'env_required',
        title: 'Required environment variables',
        status: missingEnv.length > 0 ? 'fail' : 'ok',
        details:
            missingEnv.length > 0
                ? `Missing: ${missingEnv.join(', ')}`
                : 'All required env keys are present.',
        action:
            missingEnv.length > 0
                ? 'Set missing keys in production environment before deploy.'
                : undefined,
    });

    const appUrl = trimEnv('NEXT_PUBLIC_APP_URL');
    let appUrlStatus: ReadinessStatus = 'ok';
    let appUrlDetails = `NEXT_PUBLIC_APP_URL=${appUrl}`;
    let appUrlAction: string | undefined;
    if (!appUrl) {
        appUrlStatus = 'fail';
        appUrlDetails = 'NEXT_PUBLIC_APP_URL is empty.';
        appUrlAction = 'Set public app URL for links, callbacks, and metadata.';
    } else if (!isUrlLike(appUrl)) {
        appUrlStatus = 'fail';
        appUrlDetails = 'NEXT_PUBLIC_APP_URL is not a valid http(s) URL.';
        appUrlAction = 'Use a full URL like https://ph.sitely24.com.';
    } else if (appUrl.startsWith('http://')) {
        appUrlStatus = 'warn';
        appUrlDetails = 'Public app URL uses http://';
        appUrlAction = 'Use https:// in production.';
    }
    pushCheck(checks, {
        id: 'public_app_url',
        title: 'Public app URL',
        status: appUrlStatus,
        details: appUrlDetails,
        action: appUrlAction,
    });

    try {
        await query('SELECT 1');
        pushCheck(checks, {
            id: 'db_connectivity',
            title: 'Database connectivity',
            status: 'ok',
            details: 'Database connection is healthy.',
        });
    } catch (error: unknown) {
        pushCheck(checks, {
            id: 'db_connectivity',
            title: 'Database connectivity',
            status: 'fail',
            details: error instanceof Error ? error.message : 'Unable to connect to database.',
            action: 'Check DATABASE_URL, database availability, and firewall rules.',
        });
    }

    try {
        const [runtimeConfig, providerName, baseUrl, apiKey] = await Promise.all([
            getPaymentRuntimeConfig(),
            getAppSetting(APP_SETTING_KEYS.paymentProviderName),
            getAppSetting(APP_SETTING_KEYS.paymentApiBaseUrl),
            getAppSetting(APP_SETTING_KEYS.paymentApiKey),
        ]);

        const missingPaymentParts: string[] = [];
        if (!(providerName || '').trim()) missingPaymentParts.push('payment provider name');
        if (!(baseUrl || '').trim()) missingPaymentParts.push('payment API base URL');
        if (!isPaymentApiKeyConfigured(apiKey)) missingPaymentParts.push('payment API key');
        if (!runtimeConfig.webhookConfigured) missingPaymentParts.push('payment webhook secret');

        const onlineReady = runtimeConfig.gatewayConfigured && runtimeConfig.webhookConfigured;
        pushCheck(checks, {
            id: 'payment_online',
            title: 'Online payment readiness',
            status: onlineReady ? 'ok' : 'warn',
            details: onlineReady
                ? 'Online payment is configured and ready.'
                : `Online payment is disabled. Missing: ${missingPaymentParts.join(', ') || 'unknown values'}`,
            action: onlineReady
                ? undefined
                : 'Complete payment settings and configure gateway webhook callback.',
        });
    } catch (error: unknown) {
        pushCheck(checks, {
            id: 'payment_online',
            title: 'Online payment readiness',
            status: 'fail',
            details:
                error instanceof Error ? error.message : 'Unable to verify payment configuration.',
            action: 'Open admin settings and verify payment credentials and encryption key.',
        });
    }

    const latestBackup = await getLatestBackupMeta();
    if (!latestBackup) {
        pushCheck(checks, {
            id: 'db_backup',
            title: 'Database backup',
            status: 'fail',
            details: 'No backup file found in web/backups.',
            action: 'Run `npm run backup:db` and schedule it daily.',
        });
    } else if (latestBackup.ageHours > 72) {
        pushCheck(checks, {
            id: 'db_backup',
            title: 'Database backup',
            status: 'fail',
            details: `Latest backup is ${latestBackup.ageHours.toFixed(1)}h old (${latestBackup.fileName}).`,
            action: 'Backup is stale. Re-run backup and schedule automation.',
        });
    } else if (latestBackup.ageHours > 26) {
        pushCheck(checks, {
            id: 'db_backup',
            title: 'Database backup',
            status: 'warn',
            details: `Latest backup is ${latestBackup.ageHours.toFixed(1)}h old (${latestBackup.fileName}).`,
            action: 'Recommended: keep backup age under 24h.',
        });
    } else {
        pushCheck(checks, {
            id: 'db_backup',
            title: 'Database backup',
            status: 'ok',
            details: `Latest backup: ${latestBackup.fileName} (${latestBackup.ageHours.toFixed(1)}h ago).`,
        });
    }

    try {
        const snapshot = await getOpsErrorStatsSnapshot();
        if (snapshot.backend === 'none') {
            pushCheck(checks, {
                id: 'ops_errors',
                title: 'Operations error log (last 24h)',
                status: 'warn',
                details: 'Ops error storage is unavailable in current environment.',
                action: 'Enable app_settings table write access or ops_error_logs table access.',
            });
        } else {
            pushCheck(checks, {
                id: 'ops_errors',
                title: 'Operations error log (last 24h)',
                status: snapshot.errors24h > 0 ? 'warn' : 'ok',
                details: `Errors: ${snapshot.errors24h}, warnings: ${snapshot.warnings24h}. Backend: ${snapshot.backend}.`,
                action: snapshot.errors24h > 0 ? 'Review /admin/ops-errors before go-live.' : undefined,
            });
        }
    } catch (error: unknown) {
        pushCheck(checks, {
            id: 'ops_errors',
            title: 'Operations error log (last 24h)',
            status: 'warn',
            details:
                error instanceof Error ? error.message : 'Unable to evaluate operation logs.',
            action: 'Check ops logging configuration.',
        });
    }

    try {
        const loginRateLimitBackend = await getLoginRateLimitBackend();
        pushCheck(checks, {
            id: 'login_rate_limit',
            title: 'Login rate-limit storage',
            status: loginRateLimitBackend === 'database' ? 'ok' : 'warn',
            details:
                loginRateLimitBackend === 'database'
                    ? 'Login rate limit is persisted in database (shared across app instances).'
                    : 'Current login rate limit is in-memory per server instance.',
            action:
                loginRateLimitBackend === 'database'
                    ? undefined
                    : 'For multi-instance production, move rate limit state to Redis or database.',
        });
    } catch (error: unknown) {
        pushCheck(checks, {
            id: 'login_rate_limit',
            title: 'Login rate-limit storage',
            status: 'warn',
            details: error instanceof Error ? error.message : 'Unable to evaluate login rate-limit storage.',
            action: 'Check app_settings/database access for rate-limit state.',
        });
    }

    const requiredForManual = ['env_required', 'public_app_url', 'db_connectivity', 'db_backup'];
    const requiredForOnline = [...requiredForManual, 'payment_online'];

    const findStatus = (id: string): ReadinessStatus =>
        checks.find((check) => check.id === id)?.status || 'warn';

    const readyForManualPayments = requiredForManual.every((id) => findStatus(id) !== 'fail');
    const readyForOnlinePayments = requiredForOnline.every((id) => findStatus(id) === 'ok');

    return {
        generatedAt: new Date().toISOString(),
        readyForManualPayments,
        readyForOnlinePayments,
        checks,
    };
}
