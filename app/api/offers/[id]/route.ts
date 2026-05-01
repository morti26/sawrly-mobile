import { NextRequest, NextResponse } from 'next/server';
import { query } from '@/lib/db';

// GET /api/offers/[id]
export async function GET(req: NextRequest, { params }: { params: Promise<{ id: string }> }) {
    try {
        const { id } = await params;
        const res = await query(`
            SELECT
                o.*,
                u.name as creator_name,
                COALESCE(mi.media_items, jsonb_build_array()) AS media_items
            FROM offers o
            JOIN users u ON o.creator_id = u.id
            LEFT JOIN LATERAL (
                SELECT jsonb_agg(
                    jsonb_build_object('url', omi.url, 'type', omi.type)
                    ORDER BY omi.sort_order
                ) AS media_items
                FROM offer_media_items omi
                WHERE omi.offer_id = o.id
            ) mi ON TRUE
            WHERE o.id = $1
        `, [id]);

        if ((res.rowCount ?? 0) === 0) {
            return NextResponse.json({ error: 'Offer not found' }, { status: 404 });
        }

        return NextResponse.json(res.rows[0]);
    } catch (e: any) {
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}
