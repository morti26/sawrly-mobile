import { NextRequest, NextResponse } from 'next/server';
import { query } from '@/lib/db';
import { ADMIN_PANEL_ROLES, requireRole } from '@/lib/auth';
import { ensurePaymentSchema, hasPaymentGatewayColumns } from '@/lib/payment-schema';

const ALLOWED_STATUSES = ['pending', 'confirmed', 'rejected'] as const;
type PaymentStatus = (typeof ALLOWED_STATUSES)[number];

export async function GET(req: NextRequest) {
    const auth = requireRole(req, ADMIN_PANEL_ROLES);
    if (auth.error || !auth.user) {
        return NextResponse.json({ error: auth.error }, { status: auth.status });
    }

    try {
        await ensurePaymentSchema();
        const gatewayColumnsAvailable = await hasPaymentGatewayColumns();

        const status = req.nextUrl.searchParams.get('status')?.trim() as PaymentStatus | undefined;
        const params: any[] = [];
        const filters: string[] = [];

        if (status && ALLOWED_STATUSES.includes(status)) {
            params.push(status);
            filters.push(`p.status = $${params.length}`);
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
                    creator.name AS creator_name,
                    client.name AS client_name,
                    created_by_user.name AS created_by_name,
                    confirmer.name AS confirmed_by_name,
                    linked_project.id AS linked_project_id,
                    linked_project.status AS project_status
                FROM payments p
                LEFT JOIN quotes q ON q.id = p.quote_id
                LEFT JOIN offers offer ON offer.id = q.offer_id
                LEFT JOIN users creator ON creator.id = q.creator_id
                LEFT JOIN users client ON client.id = q.client_id
                LEFT JOIN users created_by_user ON created_by_user.id = p.created_by
                LEFT JOIN users confirmer ON confirmer.id = p.confirmed_by
                LEFT JOIN LATERAL (
                    SELECT pr.id, pr.status
                    FROM projects pr
                    WHERE pr.id = p.project_id OR (p.project_id IS NULL AND pr.quote_id = p.quote_id)
                    ORDER BY CASE WHEN pr.id = p.project_id THEN 0 ELSE 1 END, pr.created_at DESC
                    LIMIT 1
                ) linked_project ON TRUE
                ${where}
                ORDER BY
                    CASE
                        WHEN p.status = 'pending' THEN 1
                        WHEN p.status = 'confirmed' THEN 2
                        WHEN p.status = 'rejected' THEN 3
                        ELSE 4
                    END,
                    p.created_at DESC
            `,
            params
        );

        return NextResponse.json(res.rows);
    } catch (e) {
        console.error('Admin Payments GET Error:', e);
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}
