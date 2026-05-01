import { NextRequest, NextResponse } from 'next/server';
import { query } from '@/lib/db';
import { ensureCreatorNotFrozen, requireRole } from '@/lib/auth';
import { logAudit } from '@/lib/logic';
import { getPaymentRuntimeConfig, isSupportedPaymentMethod } from '@/lib/payment-runtime';
import { ensurePaymentSchema, hasPaymentGatewayColumns } from '@/lib/payment-schema';

export async function GET(req: NextRequest) {
    const auth = requireRole(req, ['client', 'creator', 'admin', 'moderator']);
    if (auth.error || !auth.user) {
        return NextResponse.json({ error: auth.error }, { status: auth.status });
    }

    try {
        await ensurePaymentSchema();
        const gatewayColumnsAvailable = await hasPaymentGatewayColumns();

        const filters: string[] = [];
        const params: any[] = [];

        if (auth.user.role === 'client') {
            params.push(auth.user.userId);
            filters.push(`q.client_id = $${params.length}`);
        } else if (auth.user.role === 'creator') {
            params.push(auth.user.userId);
            filters.push(`q.creator_id = $${params.length}`);
        }

        const where = filters.length ? `WHERE ${filters.join(' AND ')}` : '';

        const res = await query(
            `
                SELECT
                    p.id,
                    p.quote_id,
                    p.project_id,
                    p.amount::float8 AS amount,
                    p.method,
                    p.status,
                    p.proof_url,
                    ${gatewayColumnsAvailable ? 'p.gateway_reference' : 'NULL::text AS gateway_reference'},
                    ${gatewayColumnsAvailable ? 'p.gateway_checkout_url' : 'NULL::text AS gateway_checkout_url'},
                    ${gatewayColumnsAvailable ? 'p.gateway_status' : 'NULL::text AS gateway_status'},
                    p.created_at,
                    p.confirmed_at,
                    q.offer_id,
                    offer.title AS offer_title,
                    offer.image_url AS offer_image_url,
                    creator.name AS creator_name,
                    client.name AS client_name,
                    linked_project.id AS linked_project_id,
                    linked_project.status AS project_status
                FROM payments p
                LEFT JOIN quotes q ON q.id = p.quote_id
                LEFT JOIN offers offer ON offer.id = q.offer_id
                LEFT JOIN users creator ON creator.id = q.creator_id
                LEFT JOIN users client ON client.id = q.client_id
                LEFT JOIN LATERAL (
                    SELECT pr.id, pr.status
                    FROM projects pr
                    WHERE pr.id = p.project_id OR (p.project_id IS NULL AND pr.quote_id = p.quote_id)
                    ORDER BY CASE WHEN pr.id = p.project_id THEN 0 ELSE 1 END, pr.created_at DESC
                    LIMIT 1
                ) linked_project ON TRUE
                ${where}
                ORDER BY p.created_at DESC
            `,
            params
        );

        return NextResponse.json({ payments: res.rows });
    } catch (e: any) {
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}

// POST /api/payments - Submit Proof
export async function POST(req: NextRequest) {
    // Client OR Creator can submit
    const auth = requireRole(req, ['client', 'creator']);
    if (auth.error) return NextResponse.json({ error: auth.error }, { status: auth.status });

    const frozen = await ensureCreatorNotFrozen(auth.user);
    if (frozen) {
        return NextResponse.json({
            error: frozen.error,
            frozenUntil: frozen.frozenUntil,
        }, { status: frozen.status });
    }

    const body = (await req.json().catch(() => null)) as {
        quoteId?: unknown;
        amount?: unknown;
        method?: unknown;
        proofUrl?: unknown;
    } | null;
    const quoteId = typeof body?.quoteId === 'string' ? body.quoteId.trim() : '';
    const amount = body?.amount;
    const methodInput = typeof body?.method === 'string' ? body.method.trim() : '';
    const proofUrl =
        typeof body?.proofUrl === 'string' && body.proofUrl.trim().length > 0
            ? body.proofUrl.trim()
            : null;

    if (!quoteId) {
        return NextResponse.json({ error: 'Quote ID is required' }, { status: 400 });
    }

    const runtimeConfig = await getPaymentRuntimeConfig();
    if (methodInput && !isSupportedPaymentMethod(methodInput, runtimeConfig)) {
        return NextResponse.json({ error: 'Invalid payment method' }, { status: 400 });
    }

    try {
        const quoteRes = await query(
            `SELECT id, client_id, creator_id FROM quotes WHERE id = $1`,
            [quoteId]
        );
        if (quoteRes.rowCount === 0) {
            return NextResponse.json({ error: 'Quote not found' }, { status: 404 });
        }

        const quote = quoteRes.rows[0];
        const isParticipant =
            quote.client_id === auth.user!.userId ||
            quote.creator_id === auth.user!.userId;
        if (!isParticipant) {
            return NextResponse.json({ error: 'Forbidden' }, { status: 403 });
        }

        const existingPendingRes = await query(
            `
                SELECT id, amount::float8 AS amount, method
                FROM payments
                WHERE quote_id = $1 AND status = 'pending'
                ORDER BY created_at DESC
                LIMIT 1
            `,
            [quoteId]
        );

        const normalizedAmount =
            typeof amount === 'number' && Number.isFinite(amount)
                ? amount
                : null;
        const normalizedMethod = methodInput || null;

        let payment;
        if (existingPendingRes.rowCount && existingPendingRes.rowCount > 0) {
            const existingPayment = existingPendingRes.rows[0];
            const updatedRes = await query(
                `
                    UPDATE payments
                    SET amount = COALESCE($1, amount),
                        method = COALESCE($2, method),
                        proof_url = COALESCE($3, proof_url)
                    WHERE id = $4
                    RETURNING id, status
                `,
                [normalizedAmount, normalizedMethod, proofUrl, existingPayment.id]
            );
            payment = updatedRes.rows[0];
        } else {
            const quotePriceRes = await query(
                `SELECT price_snapshot::float8 AS price_snapshot FROM quotes WHERE id = $1`,
                [quoteId]
            );
            const quotePrice =
                quotePriceRes.rowCount && quotePriceRes.rows[0]?.price_snapshot != null
                    ? Number(quotePriceRes.rows[0].price_snapshot)
                    : 0;

            const res = await query(
                `
                    INSERT INTO payments (quote_id, amount, method, status, proof_url, created_by)
                    VALUES ($1, $2, $3, 'pending', $4, $5)
                    RETURNING id, status
                `,
                [
                    quoteId,
                    normalizedAmount ?? quotePrice,
                    normalizedMethod ?? 'cash',
                    proofUrl,
                    auth.user!.userId,
                ]
            );
            payment = res.rows[0];
        }

        await logAudit('payment', payment.id, 'payment_submitted', auth.user!.userId, {
            quoteId,
            amount: normalizedAmount,
            method: normalizedMethod,
            proofUrl,
        });

        return NextResponse.json(payment, { status: 201 });
    } catch (e: any) {
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}
