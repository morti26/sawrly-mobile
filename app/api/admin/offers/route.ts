import { NextRequest, NextResponse } from 'next/server';
import { query } from '@/lib/db';
import { ADMIN_PANEL_ROLES, requireRole } from '@/lib/auth';
import { ensureOfferSchema } from '@/lib/feature-schema';

const ALLOWED_STATUSES = ['active', 'inactive', 'archived'] as const;
type OfferStatus = (typeof ALLOWED_STATUSES)[number];

export async function GET(req: NextRequest) {
    const auth = requireRole(req, ADMIN_PANEL_ROLES);
    if (auth.error || !auth.user) {
        return NextResponse.json({ error: auth.error }, { status: auth.status });
    }

    try {
        await ensureOfferSchema();

        const status = req.nextUrl.searchParams.get('status')?.trim() as OfferStatus | undefined;
        const search = req.nextUrl.searchParams.get('q')?.trim() || '';

        const params: any[] = [];
        const filters: string[] = [];

        if (status && ALLOWED_STATUSES.includes(status)) {
            params.push(status);
            filters.push(`o.status = $${params.length}`);
        }

        if (search) {
            params.push(`%${search}%`);
            filters.push(`(o.title ILIKE $${params.length} OR o.description ILIKE $${params.length} OR u.name ILIKE $${params.length})`);
        }

        const where = filters.length ? `WHERE ${filters.join(' AND ')}` : '';

        const res = await query(
            `
                SELECT
                    o.id,
                    o.creator_id,
                    o.title,
                    o.description,
                    o.price_iqd::float8 AS price_iqd,
                    o.status,
                    o.image_url,
                    o.created_at,
                    o.updated_at,
                    COALESCE(o.view_count, 0)::int AS view_count,
                    COALESCE(o.discount_percent, 0)::int AS discount_percent,
                    o.original_price_iqd::float8 AS original_price_iqd,
                    u.name AS creator_name,
                    COALESCE(lk.like_count, 0)::int AS like_count,
                    COALESCE(qc.order_count, 0)::int AS order_count
                FROM offers o
                JOIN users u ON u.id = o.creator_id
                LEFT JOIN (
                    SELECT offer_id, COUNT(*) AS like_count
                    FROM offer_likes
                    GROUP BY offer_id
                ) lk ON lk.offer_id = o.id
                LEFT JOIN (
                    SELECT offer_id, COUNT(*) AS order_count
                    FROM quotes
                    GROUP BY offer_id
                ) qc ON qc.offer_id = o.id
                ${where}
                ORDER BY
                    CASE
                        WHEN o.status = 'active' THEN 1
                        WHEN o.status = 'inactive' THEN 2
                        WHEN o.status = 'archived' THEN 3
                        ELSE 4
                    END,
                    o.created_at DESC
            `,
            params
        );

        return NextResponse.json(res.rows);
    } catch (e) {
        console.error('Admin Offers GET Error:', e);
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}
