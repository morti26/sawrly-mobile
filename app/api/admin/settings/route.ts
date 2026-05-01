import { NextRequest, NextResponse } from 'next/server';
import { ADMIN_PANEL_ROLES, requireRole } from '@/lib/auth';
import { APP_SETTING_KEYS, getAppSetting, setAppSetting } from '@/lib/app_settings';
import {
    encryptPaymentApiKey,
    isPaymentApiKeyConfigured,
    maybeEncryptStoredPaymentApiKey,
} from '@/lib/payment-key-crypto';

interface AdminSettingsResponse {
    homeLogoUrl: string | null;
    paymentProviderName: string | null;
    paymentApiBaseUrl: string | null;
    paymentApiKeyConfigured: boolean;
    paymentWebhookSecretConfigured: boolean;
}

function normalizeLogoUrl(value: unknown): string | null {
    if (typeof value !== 'string') return null;
    const trimmed = value.trim();
    if (!trimmed) return null;
    return trimmed;
}

function normalizeTextSetting(value: unknown): string | null {
    if (typeof value !== 'string') return null;
    const trimmed = value.trim();
    if (!trimmed) return null;
    return trimmed;
}

function isAllowedLogoUrl(url: string): boolean {
    return url.startsWith('/') || /^https?:\/\//i.test(url);
}

export async function GET(req: NextRequest) {
    const authCheck = requireRole(req, ADMIN_PANEL_ROLES);
    if (authCheck.error || !authCheck.user) {
        return NextResponse.json({ error: authCheck.error }, { status: authCheck.status });
    }

    try {
        const homeLogoUrl = await getAppSetting(APP_SETTING_KEYS.homeLogoUrl);
        const paymentProviderName = await getAppSetting(APP_SETTING_KEYS.paymentProviderName);
        const paymentApiBaseUrl = await getAppSetting(APP_SETTING_KEYS.paymentApiBaseUrl);
        const paymentApiKey = await getAppSetting(APP_SETTING_KEYS.paymentApiKey);
        const paymentWebhookSecret = await getAppSetting(APP_SETTING_KEYS.paymentWebhookSecret);
        const storedPaymentApiKey = maybeEncryptStoredPaymentApiKey(paymentApiKey);
        const storedPaymentWebhookSecret = maybeEncryptStoredPaymentApiKey(paymentWebhookSecret);
        if (storedPaymentApiKey !== paymentApiKey) {
            await setAppSetting(APP_SETTING_KEYS.paymentApiKey, storedPaymentApiKey);
        }
        if (storedPaymentWebhookSecret !== paymentWebhookSecret) {
            await setAppSetting(APP_SETTING_KEYS.paymentWebhookSecret, storedPaymentWebhookSecret);
        }
        const response: AdminSettingsResponse = {
            homeLogoUrl,
            paymentProviderName,
            paymentApiBaseUrl,
            paymentApiKeyConfigured: isPaymentApiKeyConfigured(storedPaymentApiKey),
            paymentWebhookSecretConfigured: isPaymentApiKeyConfigured(storedPaymentWebhookSecret),
        };
        return NextResponse.json(response);
    } catch (e) {
        console.error('Admin Settings GET Error:', e);
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}

export async function PUT(req: NextRequest) {
    const authCheck = requireRole(req, ADMIN_PANEL_ROLES);
    if (authCheck.error || !authCheck.user) {
        return NextResponse.json({ error: authCheck.error }, { status: authCheck.status });
    }

    try {
        const body = (await req.json()) as {
            homeLogoUrl?: unknown;
            paymentProviderName?: unknown;
            paymentApiBaseUrl?: unknown;
            paymentApiKey?: unknown;
            paymentWebhookSecret?: unknown;
        };

        const currentHomeLogoUrl = await getAppSetting(APP_SETTING_KEYS.homeLogoUrl);
        const currentPaymentProviderName = await getAppSetting(APP_SETTING_KEYS.paymentProviderName);
        const currentPaymentApiBaseUrl = await getAppSetting(APP_SETTING_KEYS.paymentApiBaseUrl);
        const currentPaymentApiKey = await getAppSetting(APP_SETTING_KEYS.paymentApiKey);
        const currentPaymentWebhookSecret = await getAppSetting(APP_SETTING_KEYS.paymentWebhookSecret);

        const normalizedHomeLogoUrl =
            'homeLogoUrl' in body ? normalizeLogoUrl(body.homeLogoUrl) : currentHomeLogoUrl;
        const normalizedPaymentProviderName =
            'paymentProviderName' in body
                ? normalizeTextSetting(body.paymentProviderName)
                : currentPaymentProviderName;
        const normalizedPaymentApiBaseUrl =
            'paymentApiBaseUrl' in body
                ? normalizeTextSetting(body.paymentApiBaseUrl)
                : currentPaymentApiBaseUrl;
        const normalizedPaymentApiKeyInput =
            'paymentApiKey' in body ? normalizeTextSetting(body.paymentApiKey) : undefined;
        const normalizedPaymentWebhookSecretInput =
            'paymentWebhookSecret' in body ? normalizeTextSetting(body.paymentWebhookSecret) : undefined;

        if (normalizedHomeLogoUrl && normalizedHomeLogoUrl.length > 2048) {
            return NextResponse.json({ error: 'Logo URL is too long' }, { status: 400 });
        }

        if (normalizedHomeLogoUrl && !isAllowedLogoUrl(normalizedHomeLogoUrl)) {
            return NextResponse.json({ error: 'Logo URL must start with / or http(s)://' }, { status: 400 });
        }

        if (normalizedPaymentProviderName && normalizedPaymentProviderName.length > 120) {
            return NextResponse.json({ error: 'Payment provider name is too long' }, { status: 400 });
        }

        if (normalizedPaymentApiBaseUrl && normalizedPaymentApiBaseUrl.length > 2048) {
            return NextResponse.json({ error: 'Payment API base URL is too long' }, { status: 400 });
        }

        if (normalizedPaymentApiBaseUrl && !/^https?:\/\//i.test(normalizedPaymentApiBaseUrl)) {
            return NextResponse.json({ error: 'Payment API base URL must start with http(s)://' }, { status: 400 });
        }

        if (normalizedPaymentApiKeyInput && normalizedPaymentApiKeyInput.length > 2048) {
            return NextResponse.json({ error: 'Payment API key is too long' }, { status: 400 });
        }
        if (normalizedPaymentWebhookSecretInput && normalizedPaymentWebhookSecretInput.length > 2048) {
            return NextResponse.json({ error: 'Payment webhook secret is too long' }, { status: 400 });
        }

        let storedPaymentApiKey = maybeEncryptStoredPaymentApiKey(currentPaymentApiKey);
        let storedPaymentWebhookSecret = maybeEncryptStoredPaymentApiKey(currentPaymentWebhookSecret);
        if (normalizedPaymentApiKeyInput !== undefined) {
            if (!normalizedPaymentApiKeyInput) {
                storedPaymentApiKey = null;
            } else {
                try {
                    storedPaymentApiKey = encryptPaymentApiKey(normalizedPaymentApiKeyInput);
                } catch {
                    return NextResponse.json(
                        { error: 'APP_SETTINGS_ENCRYPTION_KEY is required to store payment API key' },
                        { status: 500 }
                    );
                }
            }
        }
        if (normalizedPaymentWebhookSecretInput !== undefined) {
            if (!normalizedPaymentWebhookSecretInput) {
                storedPaymentWebhookSecret = null;
            } else {
                try {
                    storedPaymentWebhookSecret = encryptPaymentApiKey(normalizedPaymentWebhookSecretInput);
                } catch {
                    return NextResponse.json(
                        { error: 'APP_SETTINGS_ENCRYPTION_KEY is required to store payment webhook secret' },
                        { status: 500 }
                    );
                }
            }
        }

        await setAppSetting(APP_SETTING_KEYS.homeLogoUrl, normalizedHomeLogoUrl);
        await setAppSetting(APP_SETTING_KEYS.paymentProviderName, normalizedPaymentProviderName);
        await setAppSetting(APP_SETTING_KEYS.paymentApiBaseUrl, normalizedPaymentApiBaseUrl);
        await setAppSetting(APP_SETTING_KEYS.paymentApiKey, storedPaymentApiKey);
        await setAppSetting(APP_SETTING_KEYS.paymentWebhookSecret, storedPaymentWebhookSecret);

        const response: AdminSettingsResponse = {
            homeLogoUrl: normalizedHomeLogoUrl,
            paymentProviderName: normalizedPaymentProviderName,
            paymentApiBaseUrl: normalizedPaymentApiBaseUrl,
            paymentApiKeyConfigured: isPaymentApiKeyConfigured(storedPaymentApiKey),
            paymentWebhookSecretConfigured: isPaymentApiKeyConfigured(storedPaymentWebhookSecret),
        };
        return NextResponse.json(response);
    } catch (e) {
        console.error('Admin Settings PUT Error:', e);
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}
