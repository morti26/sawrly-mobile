import { NextRequest, NextResponse } from 'next/server';
import { pool } from '@/lib/db';
import { ensurePaymentSchema, hasPaymentGatewayColumns } from '@/lib/payment-schema';
import { logOpsError } from '@/lib/ops-monitoring';
import { getPaymentWebhookSecret } from '@/lib/payment-runtime';

export const runtime = 'nodejs';

type NormalizedPaymentStatus = 'pending' | 'confirmed' | 'rejected' | null;

function getString(value: unknown): string | null {
    if (typeof value !== 'string') return null;
    const trimmed = value.trim();
    return trimmed.length > 0 ? trimmed : null;
}

function readStringPath(payload: unknown, path: string[]): string | null {
    let cursor: unknown = payload;
    for (const segment of path) {
        if (!cursor || typeof cursor !== 'object' || !(segment in (cursor as Record<string, unknown>))) {
            return null;
        }
        cursor = (cursor as Record<string, unknown>)[segment];
    }
    return getString(cursor);
}

function pickFirst(payload: unknown, paths: string[][]): string | null {
    for (const path of paths) {
        const value = readStringPath(payload, path);
        if (value) return value;
    }
    return null;
}

function normalizePaymentStatus(rawStatus: string | null): NormalizedPaymentStatus {
    if (!rawStatus) return null;
    const status = rawStatus.toLowerCase();

    if (['confirmed', 'success', 'succeeded', 'paid', 'approved', 'captured'].includes(status)) {
        return 'confirmed';
    }

    if (['rejected', 'failed', 'fail', 'cancelled', 'canceled', 'declined', 'expired'].includes(status)) {
        return 'rejected';
    }

    if (['pending', 'processing', 'authorized', 'authorised'].includes(status)) {
        return 'pending';
    }

    return null;
}

export async function POST(req: NextRequest) {
    await ensurePaymentSchema();
    const gatewayColumnsAvailable = await hasPaymentGatewayColumns();
    if (!gatewayColumnsAvailable) {
        await logOpsError({
            source: 'api.payments.webhook',
            level: 'error',
            message: 'Online payment schema is not available for this database user',
            requestPath: req.nextUrl.pathname,
        });
        return NextResponse.json(
            { error: 'Online payment schema is not available for this database user' },
            { status: 503 }
        );
    }

    const expectedSecret = (await getPaymentWebhookSecret())?.trim() || '';
    if (!expectedSecret) {
        await logOpsError({
            source: 'api.payments.webhook',
            level: 'error',
            message: 'PAYMENT_WEBHOOK_SECRET is not configured',
            requestPath: req.nextUrl.pathname,
        });
        return NextResponse.json({ error: 'Webhook secret is not configured' }, { status: 503 });
    }

    const providedSecret =
        req.headers.get('x-webhook-secret')?.trim() ||
        req.nextUrl.searchParams.get('secret')?.trim() ||
        '';

    if (!providedSecret || providedSecret !== expectedSecret) {
        await logOpsError({
            source: 'api.payments.webhook',
            level: 'warn',
            message: 'Unauthorized webhook attempt',
            requestPath: req.nextUrl.pathname,
        });
        return NextResponse.json({ error: 'Unauthorized webhook' }, { status: 401 });
    }

    const payload = (await req.json().catch(() => null)) as Record<string, unknown> | null;
    if (!payload || typeof payload !== 'object') {
        await logOpsError({
            source: 'api.payments.webhook',
            level: 'warn',
            message: 'Invalid webhook payload',
            requestPath: req.nextUrl.pathname,
        });
        return NextResponse.json({ error: 'Invalid webhook payload' }, { status: 400 });
    }

    const reference = pickFirst(payload, [
        ['gatewayReference'],
        ['gateway_reference'],
        ['transactionId'],
        ['transaction_id'],
        ['paymentId'],
        ['payment_id'],
        ['reference'],
        ['id'],
        ['data', 'gatewayReference'],
        ['data', 'gateway_reference'],
        ['data', 'transactionId'],
        ['data', 'transaction_id'],
        ['data', 'paymentId'],
        ['data', 'payment_id'],
        ['data', 'reference'],
        ['data', 'id'],
        ['result', 'transactionId'],
        ['result', 'transaction_id'],
        ['result', 'paymentId'],
        ['result', 'payment_id'],
        ['result', 'reference'],
        ['result', 'id'],
    ]);

    if (!reference) {
        await logOpsError({
            source: 'api.payments.webhook',
            level: 'warn',
            message: 'Webhook payload missing payment reference',
            requestPath: req.nextUrl.pathname,
            details: payload,
        });
        return NextResponse.json({ error: 'Payment reference is required' }, { status: 400 });
    }

    const gatewayStatusRaw = pickFirst(payload, [
        ['status'],
        ['paymentStatus'],
        ['payment_status'],
        ['data', 'status'],
        ['data', 'paymentStatus'],
        ['data', 'payment_status'],
        ['result', 'status'],
        ['result', 'paymentStatus'],
        ['result', 'payment_status'],
    ]);

    const nextPaymentStatus = normalizePaymentStatus(gatewayStatusRaw);
    const gatewayStatus = gatewayStatusRaw || 'unknown';

    const client = await pool.connect();
    try {
        await client.query('BEGIN');

        const paymentRes = await client.query(
            `
                SELECT
                    p.id,
                    p.quote_id,
                    p.project_id,
                    p.status,
                    q.creator_id AS quote_creator_id,
                    q.client_id AS quote_client_id
                FROM payments p
                LEFT JOIN quotes q ON q.id = p.quote_id
                WHERE p.gateway_reference = $1 OR p.id::text = $1
                ORDER BY CASE WHEN p.gateway_reference = $1 THEN 0 ELSE 1 END
                LIMIT 1
                FOR UPDATE
            `,
            [reference]
        );

        if (paymentRes.rowCount === 0) {
            await client.query('ROLLBACK');
            await logOpsError({
                source: 'api.payments.webhook',
                level: 'warn',
                message: 'Payment not found for webhook reference',
                requestPath: req.nextUrl.pathname,
                details: { reference },
            });
            return NextResponse.json({ error: 'Payment not found for reference' }, { status: 404 });
        }

        const payment = paymentRes.rows[0] as {
            id: string;
            quote_id: string | null;
            project_id: string | null;
            status: string;
            quote_creator_id: string | null;
            quote_client_id: string | null;
        };

        await client.query(
            `
                UPDATE payments
                SET gateway_reference = COALESCE(gateway_reference, $1),
                    gateway_status = $2,
                    gateway_payload = $3::jsonb
                WHERE id = $4
            `,
            [reference, gatewayStatus, JSON.stringify(payload), payment.id]
        );

        let projectId = payment.project_id;
        let projectStatus: string | null = null;
        let paymentStatus = payment.status;

        if (nextPaymentStatus === 'confirmed') {
            if (payment.status !== 'confirmed') {
                const updatedPaymentRes = await client.query(
                    `
                        UPDATE payments
                        SET status = 'confirmed',
                            confirmed_at = NOW()
                        WHERE id = $1
                        RETURNING status
                    `,
                    [payment.id]
                );
                paymentStatus = updatedPaymentRes.rows[0]?.status || 'confirmed';
            }

            if (payment.quote_id && payment.quote_creator_id && payment.quote_client_id) {
                const existingProjectRes = await client.query(
                    `
                        SELECT id, status
                        FROM projects
                        WHERE id = $1 OR quote_id = $2
                        ORDER BY CASE WHEN id = $1 THEN 0 ELSE 1 END, created_at DESC
                        LIMIT 1
                    `,
                    [payment.project_id, payment.quote_id]
                );

                if (existingProjectRes.rowCount && existingProjectRes.rowCount > 0) {
                    projectId = existingProjectRes.rows[0].id;
                    projectStatus = existingProjectRes.rows[0].status;
                } else {
                    const createdProjectRes = await client.query(
                        `
                            INSERT INTO projects (quote_id, creator_id, client_id, status)
                            VALUES ($1, $2, $3, 'in_progress')
                            RETURNING id, status
                        `,
                        [payment.quote_id, payment.quote_creator_id, payment.quote_client_id]
                    );
                    projectId = createdProjectRes.rows[0].id;
                    projectStatus = createdProjectRes.rows[0].status;
                }

                await client.query(
                    `
                        UPDATE payments
                        SET project_id = $1
                        WHERE id = $2
                    `,
                    [projectId, payment.id]
                );
            }
        } else if (nextPaymentStatus === 'rejected' && payment.status !== 'rejected') {
            const rejectedRes = await client.query(
                `
                    UPDATE payments
                    SET status = 'rejected'
                    WHERE id = $1
                    RETURNING status
                `,
                [payment.id]
            );
            paymentStatus = rejectedRes.rows[0]?.status || 'rejected';
        }

        await client.query('COMMIT');

        return NextResponse.json({
            success: true,
            paymentId: payment.id,
            gatewayReference: reference,
            gatewayStatus,
            paymentStatus,
            project: projectId
                ? {
                    id: projectId,
                    status: projectStatus,
                }
                : null,
        });
    } catch (error) {
        await client.query('ROLLBACK');
        await logOpsError({
            source: 'api.payments.webhook',
            level: 'error',
            message: error instanceof Error ? error.message : 'Internal Server Error',
            requestPath: req.nextUrl.pathname,
            details: { reference },
        });
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    } finally {
        client.release();
    }
}
