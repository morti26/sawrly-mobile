import { query } from '@/lib/db';

const SETTINGS_TABLE_SQL = `
    CREATE TABLE IF NOT EXISTS app_settings (
        setting_key TEXT PRIMARY KEY,
        setting_value TEXT,
        updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
    )
`;

let appSettingsTableEnsured = false;

export const APP_SETTING_KEYS = {
    homeLogoUrl: 'home_logo_url',
    paymentProviderName: 'payment_provider_name',
    paymentApiBaseUrl: 'payment_api_base_url',
    paymentApiKey: 'payment_api_key',
    paymentWebhookSecret: 'payment_webhook_secret',
} as const;

export async function ensureAppSettingsTable(): Promise<void> {
    if (appSettingsTableEnsured) {
        return;
    }

    try {
        await query('SELECT 1 FROM app_settings LIMIT 1');
        appSettingsTableEnsured = true;
        return;
    } catch (error: any) {
        if (error?.code !== '42P01') {
            throw error;
        }
    }

    await query(SETTINGS_TABLE_SQL);
    appSettingsTableEnsured = true;
}

export async function getAppSetting(settingKey: string): Promise<string | null> {
    await ensureAppSettingsTable();
    const res = await query(
        'SELECT setting_value FROM app_settings WHERE setting_key = $1 LIMIT 1',
        [settingKey]
    );
    return res.rows[0]?.setting_value ?? null;
}

export async function setAppSetting(settingKey: string, value: string | null): Promise<void> {
    await ensureAppSettingsTable();
    await query(
        `
        INSERT INTO app_settings (setting_key, setting_value, updated_at)
        VALUES ($1, $2, CURRENT_TIMESTAMP)
        ON CONFLICT (setting_key)
        DO UPDATE SET
            setting_value = EXCLUDED.setting_value,
            updated_at = CURRENT_TIMESTAMP
        `,
        [settingKey, value]
    );
}
