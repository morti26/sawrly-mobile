import { NextRequest, NextResponse } from 'next/server';
import { query } from '@/lib/db';
import { ADMIN_PANEL_ROLES, requireRole } from '@/lib/auth';

const ALLOWED_STATUSES = ['in_progress', 'completed', 'cancelled'] as const;
type ProjectStatus = (typeof ALLOWED_STATUSES)[number];

export async function GET(req: NextRequest) {
    const auth = requireRole(req, ADMIN_PANEL_ROLES);
    if (auth.error || !auth.user) {
        return NextResponse.json({ error: auth.error }, { status: auth.status });
    }

    try {
        const status = req.nextUrl.searchParams.get('status')?.trim() as ProjectStatus | undefined;
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
                    p.status,
                    p.started_at,
                    p.completed_at,
                    p.created_at,
                    offer.title AS offer_title,
                    creator.name AS creator_name,
                    client.name AS client_name,
                    latest_delivery.status AS latest_delivery_status,
                    latest_delivery.delivery_url AS latest_delivery_url,
                    COALESCE(confirmed_payments.confirmed_count, 0)::int AS confirmed_payment_count
                FROM projects p
                LEFT JOIN quotes q ON q.id = p.quote_id
                LEFT JOIN offers offer ON offer.id = q.offer_id
                LEFT JOIN users creator ON creator.id = p.creator_id
                LEFT JOIN users client ON client.id = p.client_id
                LEFT JOIN LATERAL (
                    SELECT d.status, d.delivery_url
                    FROM deliveries d
                    WHERE d.project_id = p.id
                    ORDER BY d.submitted_at DESC
                    LIMIT 1
                ) latest_delivery ON TRUE
                LEFT JOIN LATERAL (
                    SELECT COUNT(*) AS confirmed_count
                    FROM payments pay
                    WHERE (pay.project_id = p.id OR pay.quote_id = p.quote_id)
                      AND pay.status = 'confirmed'
                ) confirmed_payments ON TRUE
                ${where}
                ORDER BY
                    CASE
                        WHEN p.status = 'in_progress' THEN 1
                        WHEN p.status = 'completed' THEN 2
                        WHEN p.status = 'cancelled' THEN 3
                        ELSE 4
                    END,
                    p.created_at DESC
            `,
            params
        );

        return NextResponse.json(res.rows);
    } catch (e) {
        console.error('Admin Projects GET Error:', e);
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}
