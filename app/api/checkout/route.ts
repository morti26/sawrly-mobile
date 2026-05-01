import { NextRequest, NextResponse } from 'next/server';
import { pool, query } from '@/lib/db';
import { requireRole } from '@/lib/auth';
import {
    GATEWAY_PAYMENT_METHOD,
    type PaymentGatewayCredentials,
    getCheckoutNextStep,
    getPaymentGatewayCredentials,
    getPaymentRuntimeConfig,
    isSupportedPaymentMethod,
    type PaymentMethod,
} from '@/lib/payment-runtime';
import { createGatewayCheckout, PaymentGatewayError } from '@/lib/payment-gateway';
import { ensurePaymentSchema, hasPaymentGatewayColumns } from '@/lib/payment-schema';
import { logOpsError } from '@/lib/ops-monitoring';

export async function POST(req: NextRequest) {
    const auth = requireRole(req, ['client']);
    if (auth.error || !auth.user) {
        return NextResponse.json({ error: auth.error }, { status: auth.status });
    }

    await ensurePaymentSchema();

    const body = (await req.json().catch(() => null)) as {
        offerIds?: unknown[];
        paymentMethod?: unknown;
    } | null;
    const rawOfferIds: unknown[] = Array.isArray(body?.offerIds) ? body!.offerIds! : [];
    const offerIds = Array.from(
        new Set(
            rawOfferIds
                .map((value: unknown) => String(value).trim())
                .filter((value: string) => value.length > 0)
        )
    );
    const paymentMethod =
        typeof body?.paymentMethod === 'string' ? body.paymentMethod.trim() : '';

    if (offerIds.length === 0) {
        return NextResponse.json({ error: 'Offer IDs are required' }, { status: 400 });
    }

    if (offerIds.length > 20) {
        return NextResponse.json({ error: 'Too many offers in one checkout' }, { status: 400 });
    }

    const runtimeConfig = await getPaymentRuntimeConfig();
    const gatewayColumnsAvailable = await hasPaymentGatewayColumns();
    if (paymentMethod === GATEWAY_PAYMENT_METHOD && !runtimeConfig.gatewayConfigured) {
        return NextResponse.json(
            { error: 'Online payment gateway is not fully configured' },
            { status: 400 }
        );
    }
    if (paymentMethod === GATEWAY_PAYMENT_METHOD && !runtimeConfig.webhookConfigured) {
        return NextResponse.json(
            { error: 'Online payment webhook secret is not configured' },
            { status: 400 }
        );
    }
    if (paymentMethod === GATEWAY_PAYMENT_METHOD && !gatewayColumnsAvailable) {
        return NextResponse.json(
            { error: 'Online payment schema is not available for this database user' },
            { status: 503 }
        );
    }
    if (!isSupportedPaymentMethod(paymentMethod, runtimeConfig)) {
        return NextResponse.json({ error: 'Invalid payment method' }, { status: 400 });
    }
    const nextStep = getCheckoutNextStep(paymentMethod as PaymentMethod);
    const isOnlinePayment = paymentMethod === GATEWAY_PAYMENT_METHOD;

    let gatewayCredentials: PaymentGatewayCredentials | null = null;
    if (isOnlinePayment) {
        gatewayCredentials = await getPaymentGatewayCredentials();
        if (!gatewayCredentials) {
            return NextResponse.json(
                { error: 'Online payment gateway is not fully configured' },
                { status: 400 }
            );
        }
    }

    const client = await pool.connect();
    let transactionOpen = false;
    try {
        await client.query('BEGIN');
        transactionOpen = true;

        const offersRes = await client.query(
            `
                SELECT id, title, creator_id, price_iqd
                FROM offers
                WHERE status = 'active'
                  AND id = ANY($1::uuid[])
            `,
            [offerIds]
        );

        const offersById = new Map<
            string,
            { id: string; title: string; creator_id: string; price_iqd: number | string }
        >();
        for (const row of offersRes.rows as Array<{
            id: string;
            title: string;
            creator_id: string;
            price_iqd: number | string;
        }>) {
            offersById.set(String(row.id), row);
        }
        const missingOfferIds = offerIds.filter((id) => !offersById.has(id));

        if (missingOfferIds.length > 0) {
            await client.query('ROLLBACK');
            transactionOpen = false;
            return NextResponse.json(
                { error: 'Some offers were not found or are inactive', missingOfferIds },
                { status: 404 }
            );
        }

        const items: Array<{
            offerId: string;
            offerTitle: string;
            quoteId: string;
            paymentId: string;
            creatorId: string;
            amount: number;
            checkoutUrl?: string;
            gatewayReference?: string | null;
        }> = [];
        const gatewayQueue: Array<{
            paymentId: string;
            quoteId: string;
            offerId: string;
            creatorId: string;
            amount: number;
        }> = [];
        let totalAmount = 0;

        for (const offerId of offerIds) {
            const offer = offersById.get(offerId);
            if (!offer) {
                throw new Error(`Offer ${offerId} is missing after validation`);
            }
            const amount = Number(offer.price_iqd ?? 0);

            const quoteRes = await client.query(
                `
                    INSERT INTO quotes (offer_id, client_id, creator_id, price_snapshot, status)
                    VALUES ($1, $2, $3, $4, 'accepted')
                    RETURNING id, price_snapshot
                `,
                [offer.id, auth.user.userId, offer.creator_id, offer.price_iqd]
            );

            const quote = quoteRes.rows[0];

            const paymentRes = await client.query(
                `
                    INSERT INTO payments (quote_id, amount, method, status, proof_url, created_by)
                    VALUES ($1, $2, $3, 'pending', NULL, $4)
                    RETURNING id, status
                `,
                [quote.id, offer.price_iqd, paymentMethod, auth.user.userId]
            );

            const payment = paymentRes.rows[0];
            let checkoutUrl: string | undefined;
            let gatewayReference: string | null = null;

            if (isOnlinePayment && gatewayCredentials) {
                await client.query(
                    `
                        UPDATE payments
                        SET gateway_status = $1
                        WHERE id = $2
                    `,
                    ['pending', payment.id]
                );
                gatewayQueue.push({
                    paymentId: String(payment.id),
                    quoteId: String(quote.id),
                    offerId: String(offer.id),
                    creatorId: String(offer.creator_id),
                    amount,
                });
            }

            await client.query(
                `
                    INSERT INTO audit_logs (entity_type, entity_id, event_type, actor_id, metadata)
                    VALUES ($1, $2, $3, $4, $5)
                `,
                [
                    'quote',
                    quote.id,
                    'quote_created',
                    auth.user.userId,
                    JSON.stringify({ offerId: offer.id, price: offer.price_iqd }),
                ]
            );

            await client.query(
                `
                    INSERT INTO audit_logs (entity_type, entity_id, event_type, actor_id, metadata)
                    VALUES ($1, $2, $3, $4, $5)
                `,
                [
                    'payment',
                    payment.id,
                    'payment_submitted',
                    auth.user.userId,
                    JSON.stringify({ quoteId: quote.id, amount: offer.price_iqd, method: paymentMethod }),
                ]
            );

            await client.query(
                `
                    INSERT INTO notifications (user_id, type, title, message, payload, is_read)
                    VALUES ($1, 'booking', $2, $3, $4, false)
                `,
                [
                    offer.creator_id,
                    'طلب جديد',
                    `تم إنشاء طلب جديد للعرض: ${offer.title}`,
                    JSON.stringify({ offerId: offer.id, quoteId: quote.id, paymentId: payment.id }),
                ]
            );

            totalAmount += amount;
            items.push({
                offerId: String(offer.id),
                offerTitle: String(offer.title),
                quoteId: String(quote.id),
                paymentId: String(payment.id),
                creatorId: String(offer.creator_id),
                amount,
                checkoutUrl,
                gatewayReference,
            });
        }

        await client.query(
            `
                INSERT INTO notifications (user_id, type, title, message, payload, is_read)
                VALUES ($1, 'payment', $2, $3, $4, false)
            `,
            [
                auth.user.userId,
                'تم إرسال الطلب',
                `تم إنشاء ${items.length} طلب ودفع معلق بانتظار التأكيد`,
                JSON.stringify({ paymentMethod, itemsCount: items.length, totalAmount }),
            ]
        );

        await client.query('COMMIT');
        transactionOpen = false;

        const onlineCheckoutErrors: Array<{ paymentId: string; message: string }> = [];

        if (isOnlinePayment && gatewayCredentials) {
            for (const pendingItem of gatewayQueue) {
                try {
                    const gatewayCheckout = await createGatewayCheckout(gatewayCredentials, {
                        paymentId: pendingItem.paymentId,
                        quoteId: pendingItem.quoteId,
                        offerId: pendingItem.offerId,
                        creatorId: pendingItem.creatorId,
                        clientId: auth.user.userId,
                        amountIqd: pendingItem.amount,
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
                            pendingItem.paymentId,
                        ]
                    );

                    const item = items.find((entry) => entry.paymentId === pendingItem.paymentId);
                    if (item) {
                        item.checkoutUrl = gatewayCheckout.checkoutUrl;
                        item.gatewayReference = gatewayCheckout.gatewayReference;
                    }
                } catch (gatewayError: unknown) {
                    const message =
                        gatewayError instanceof PaymentGatewayError
                            ? gatewayError.message
                            : 'Unable to create gateway checkout session';
                    onlineCheckoutErrors.push({ paymentId: pendingItem.paymentId, message });

                    try {
                        await query(
                            `
                                UPDATE payments
                                SET gateway_status = $1,
                                    gateway_payload = COALESCE(gateway_payload, $2::jsonb)
                                WHERE id = $3
                            `,
                            [
                                'failed',
                                JSON.stringify({
                                    error: message,
                                    failedAt: new Date().toISOString(),
                                }),
                                pendingItem.paymentId,
                            ]
                        );
                    } catch {
                        // Ignore secondary persistence failure; primary error is already captured below.
                    }

                    await logOpsError({
                        source: 'api.checkout.gateway',
                        message,
                        level: 'error',
                        requestPath: req.nextUrl.pathname,
                        details: {
                            userId: auth.user.userId,
                            paymentMethod,
                            paymentId: pendingItem.paymentId,
                            offerId: pendingItem.offerId,
                        },
                    });
                }
            }
        }

        return NextResponse.json(
            {
                quotesCount: items.length,
                paymentsCount: items.length,
                totalAmount,
                paymentMethod,
                paymentMode: runtimeConfig.mode,
                gatewayConfigured: runtimeConfig.gatewayConfigured,
                webhookConfigured: runtimeConfig.webhookConfigured,
                paymentProviderName: runtimeConfig.paymentProviderName,
                gatewayCheckoutUrl: items.find((item) => item.checkoutUrl)?.checkoutUrl ?? null,
                gatewayCheckoutUrls: items
                    .map((item) => item.checkoutUrl)
                    .filter((url): url is string => Boolean(url)),
                onlineCheckoutErrors,
                nextStep,
                items,
            },
            { status: 201 }
        );
    } catch (e: any) {
        if (transactionOpen) {
            await client.query('ROLLBACK');
            transactionOpen = false;
        }
        if (e instanceof PaymentGatewayError) {
            await logOpsError({
                source: 'api.checkout.gateway',
                message: e.message,
                level: 'error',
                requestPath: req.nextUrl.pathname,
                details: {
                    userId: auth.user.userId,
                    paymentMethod,
                    offerCount: offerIds.length,
                },
            });
            return NextResponse.json({ error: e.message }, { status: 502 });
        }
        await logOpsError({
            source: 'api.checkout',
            message: e?.message || 'Internal Server Error',
            level: 'error',
            requestPath: req.nextUrl.pathname,
            details: {
                userId: auth.user.userId,
                paymentMethod,
                offerCount: offerIds.length,
            },
        });
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    } finally {
        client.release();
    }
}
