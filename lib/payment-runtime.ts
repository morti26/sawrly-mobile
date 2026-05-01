import { APP_SETTING_KEYS, getAppSetting } from '@/lib/app_settings';
import { decryptPaymentApiKey, isPaymentApiKeyConfigured } from '@/lib/payment-key-crypto';

export const MANUAL_PAYMENT_METHODS = ['cash', 'bank_transfer', 'wallet'] as const;
export type ManualPaymentMethod = (typeof MANUAL_PAYMENT_METHODS)[number];
export const GATEWAY_PAYMENT_METHOD = 'online' as const;
export type PaymentMethod = ManualPaymentMethod | typeof GATEWAY_PAYMENT_METHOD;

export interface PaymentRuntimeConfig {
    mode: 'manual' | 'gateway';
    gatewayConfigured: boolean;
    webhookConfigured: boolean;
    paymentProviderName: string | null;
    paymentApiBaseUrl: string | null;
}

export interface PaymentGatewayCredentials {
    paymentProviderName: string;
    paymentApiBaseUrl: string;
    paymentApiKey: string;
}

export function isManualPaymentMethod(value: string): value is ManualPaymentMethod {
    return (MANUAL_PAYMENT_METHODS as readonly string[]).includes(value);
}

export function getAvailablePaymentMethods(runtimeConfig: PaymentRuntimeConfig): PaymentMethod[] {
    if (!runtimeConfig.gatewayConfigured || !runtimeConfig.webhookConfigured) {
        return [...MANUAL_PAYMENT_METHODS];
    }
    return [...MANUAL_PAYMENT_METHODS, GATEWAY_PAYMENT_METHOD];
}

export function isSupportedPaymentMethod(
    value: string,
    runtimeConfig: PaymentRuntimeConfig
): value is PaymentMethod {
    return getAvailablePaymentMethods(runtimeConfig).includes(value as PaymentMethod);
}

export function getPaymentMethodLabelAr(method: PaymentMethod): string {
    switch (method) {
        case 'bank_transfer':
            return 'تحويل بنكي';
        case 'wallet':
            return 'محفظة';
        case 'online':
            return 'دفع إلكتروني';
        case 'cash':
        default:
            return 'نقدي';
    }
}

export function getManualCheckoutNextStep(method: ManualPaymentMethod): string {
    switch (method) {
        case 'bank_transfer':
            return 'تم إنشاء الطلب. ارفع إثبات التحويل من صفحة المدفوعات ليتم تأكيده.';
        case 'wallet':
            return 'تم إنشاء الطلب. ارفع إثبات الدفع من المحفظة من صفحة المدفوعات ليتم تأكيده.';
        case 'cash':
        default:
            return 'تم إنشاء الطلب والدفع المعلق. يمكن للمبدع أو الأدمن تأكيد الدفع لبدء المشروع.';
    }
}

export function getCheckoutNextStep(method: PaymentMethod): string {
    if (method === GATEWAY_PAYMENT_METHOD) {
        return 'تم إنشاء الطلب. أكمل الدفع الإلكتروني من بوابة الدفع.';
    }
    return getManualCheckoutNextStep(method);
}

export async function getPaymentGatewayCredentials(): Promise<PaymentGatewayCredentials | null> {
    const [paymentProviderNameRaw, paymentApiBaseUrlRaw, paymentApiKeyRaw] = await Promise.all([
        getAppSetting(APP_SETTING_KEYS.paymentProviderName),
        getAppSetting(APP_SETTING_KEYS.paymentApiBaseUrl),
        getAppSetting(APP_SETTING_KEYS.paymentApiKey),
    ]);

    const paymentProviderName = paymentProviderNameRaw?.trim() || '';
    const paymentApiBaseUrl = paymentApiBaseUrlRaw?.trim() || '';

    if (!paymentProviderName || !paymentApiBaseUrl || !paymentApiKeyRaw) {
        return null;
    }

    const paymentApiKey = decryptPaymentApiKey(paymentApiKeyRaw).trim();
    if (!paymentApiKey) {
        return null;
    }

    return {
        paymentProviderName,
        paymentApiBaseUrl,
        paymentApiKey,
    };
}

export async function getPaymentWebhookSecret(): Promise<string | null> {
    const storedSecret = await getAppSetting(APP_SETTING_KEYS.paymentWebhookSecret);
    if (storedSecret && storedSecret.trim().length > 0) {
        try {
            const decrypted = decryptPaymentApiKey(storedSecret).trim();
            if (decrypted.length > 0) {
                return decrypted;
            }
        } catch {
            return null;
        }
    }

    const envSecret = (process.env.PAYMENT_WEBHOOK_SECRET || '').trim();
    return envSecret.length > 0 ? envSecret : null;
}

export async function getPaymentRuntimeConfig(): Promise<PaymentRuntimeConfig> {
    const [paymentProviderNameRaw, paymentApiBaseUrlRaw, paymentApiKeyRaw, webhookSecret] = await Promise.all([
        getAppSetting(APP_SETTING_KEYS.paymentProviderName),
        getAppSetting(APP_SETTING_KEYS.paymentApiBaseUrl),
        getAppSetting(APP_SETTING_KEYS.paymentApiKey),
        getPaymentWebhookSecret(),
    ]);

    const paymentProviderName = paymentProviderNameRaw?.trim() || null;
    const paymentApiBaseUrl = paymentApiBaseUrlRaw?.trim() || null;

    let gatewayConfigured = false;
    if (paymentApiBaseUrl && isPaymentApiKeyConfigured(paymentApiKeyRaw)) {
        try {
            const decrypted = paymentApiKeyRaw ? decryptPaymentApiKey(paymentApiKeyRaw) : '';
            gatewayConfigured = decrypted.trim().length > 0;
        } catch {
            gatewayConfigured = false;
        }
    }

    return {
        mode: gatewayConfigured ? 'gateway' : 'manual',
        gatewayConfigured,
        webhookConfigured: Boolean(webhookSecret),
        paymentProviderName,
        paymentApiBaseUrl,
    };
}
