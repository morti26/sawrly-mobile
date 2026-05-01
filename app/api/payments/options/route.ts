import { NextRequest, NextResponse } from 'next/server';
import { requireRole } from '@/lib/auth';
import {
    getAvailablePaymentMethods,
    getManualCheckoutNextStep,
    getPaymentMethodLabelAr,
    getPaymentRuntimeConfig,
    GATEWAY_PAYMENT_METHOD,
} from '@/lib/payment-runtime';

export async function GET(req: NextRequest) {
    const auth = requireRole(req, ['client', 'creator', 'admin', 'moderator']);
    if (auth.error || !auth.user) {
        return NextResponse.json({ error: auth.error }, { status: auth.status });
    }

    try {
        const runtimeConfig = await getPaymentRuntimeConfig();
        const methods = getAvailablePaymentMethods(runtimeConfig).map((method) => ({
            value: method,
            label: getPaymentMethodLabelAr(method),
            requiresProof: method !== 'cash' && method !== GATEWAY_PAYMENT_METHOD,
            hint: method === GATEWAY_PAYMENT_METHOD
                ? 'أكمل الدفع من بوابة الدفع الإلكترونية.'
                : getManualCheckoutNextStep(method),
        }));

        return NextResponse.json({
            mode: runtimeConfig.mode,
            gatewayConfigured: runtimeConfig.gatewayConfigured,
            webhookConfigured: runtimeConfig.webhookConfigured,
            onlineEnabled: runtimeConfig.gatewayConfigured && runtimeConfig.webhookConfigured,
            paymentProviderName: runtimeConfig.paymentProviderName,
            paymentApiBaseUrl: runtimeConfig.paymentApiBaseUrl,
            methods,
        });
    } catch (e) {
        console.error('Payment options GET Error:', e);
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}
