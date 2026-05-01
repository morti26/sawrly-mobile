import { NextRequest, NextResponse } from 'next/server';
import { query } from '@/lib/db';
import { requireRole } from '@/lib/auth';
import {
    GATEWAY_PAYMENT_METHOD,
    getPaymentGatewayCredentials,
    getPaymentRuntimeConfig,
} from '@/lib/payment-runtime';
import { createGatewayCheckout, PaymentGatewayError } from '@/lib/payment-gateway';
import { ensurePaymentSchema, hasPaymentGatewayColumns } from '@/lib/payment-schema';
import { logOpsError } from '@/lib/ops-monitoring';

type PaymentRow = {
    id: string;
    quote_id: string | null;
    offer_id: string | null;
    creator_id: string | null;
    client_id: string | null;
    amount: number;
    method: string;
    status: string;
};

export async function POST(
    req: NextRequest,
    { params }: { params: Promise<{ id: string }> }
) {
    const auth = requireRole(req, ['client', 'admin', 'moderator']);
    if (auth.error || !auth.user) {
        return NextResponse.json({ error: auth.error }, { status: auth.status });
    }

    await ensurePaymentSchema();
    const gatewayColumnsAvailable = await hasPaymentGatewayColumns();
    if (!gatewayColumnsAvailable) {
        return NextResponse.json(
            { error: 'Online payment schema is not available for this database user' },
            { status: 503 }
        );
    }

    const runtimeConfig = await getPaymentRuntimeConfig();
    if (!runtimeConfig.gatewayConfigured || !runtimeConfig.webhookConfigured) {
        return NextResponse.json(
            { error: 'Online payment gateway is not fully configured' },
            { status: 400 }
        );
    }

    const gatewayCredentials = await getPaymentGatewayCredentials();
    if (!gatewayCredentials) {
        return NextResponse.json(
            { error: 'Online payment gateway is not fully configured' },
            { status: 400 }
        );
    }

    const { id } = await params;
    const paymentId = id?.trim();
    if (!paymentId) {
        return NextResponse.json({ error: 'Payment ID is required' }, { status: 400 });
    }

    try {
        const paymentRes = await query(
            `
                SELECT
                    p.id,
                    p.quote_id,
                    p.amount::float8 AS amount,
                    p.method,
                    p.status,
                    q.offer_id,
                    q.creator_id,
                    q.client_id
                FROM payments p
                LEFT JOIN quotes q ON q.id = p.quote_id
                WHERE p.id = $1
                LIMIT 1
            `,
            [paymentId]
        );

        if ((paymentRes.rowCount ?? 0) === 0) {
            return NextResponse.json({ error: 'Payment not found' }, { status: 404 });
        }

        const payment = paymentRes.rows[0] as PaymentRow;
        if (auth.user.role === 'client' && payment.client_id !== auth.user.userId) {
            return NextResponse.json({ error: 'Forbidden' }, { status: 403 });
        }

        if (payment.method !== GATEWAY_PAYMENT_METHOD) {
            return NextResponse.json(
                { error: 'Payment is not configured for online checkout' },
                { status: 400 }
            );
        }

        if (payment.status !== 'pending') {
            return NextResponse.json(
                { error: 'Only pending payments can generate checkout links' },
                { status: 400 }
            );
        }

        const gatewayCheckout = await createGatewayCheckout(gatewayCredentials, {
            paymentId: payment.id,
            quoteId: payment.quote_id || '',
            offerId: payment.offer_id || '',
            creatorId: payment.creator_id || '',
            clientId: payment.client_id || auth.user.userId,
            amountIqd: Number(payment.amount || 0),
        });

        await query(
            `
                UPDATE payments
                SET gateway_reference = $1,
                    gateway_checkout_url = $2,
                    gateway_status = $3,
                    gateway_payload = $4::jsonb
                WHERE id = $5
            `,
            [
                gatewayCheckout.gatewayReference,
                gatewayCheckout.checkoutUrl,
                'pending',
                JSON.stringify(gatewayCheckout.gatewayPayload),
                payment.id,
            ]
        );

        return NextResponse.json({
            paymentId: payment.id,
            gatewayReference: gatewayCheckout.gatewayReference,
            gatewayCheckoutUrl: gatewayCheckout.checkoutUrl,
        });
    } catch (e: unknown) {
        const isGatewayError = e instanceof PaymentGatewayError;
        await logOpsError({
            source: 'api.payments.online-checkout',
            message: isGatewayError ? e.message : 'Internal Server Error',
            level: 'error',
            requestPath: req.nextUrl.pathname,
            details: {
                paymentId,
                userId: auth.user.userId,
                role: auth.user.role,
            },
        });
        if (isGatewayError) {
            return NextResponse.json({ error: e.message }, { status: 502 });
        }
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}
