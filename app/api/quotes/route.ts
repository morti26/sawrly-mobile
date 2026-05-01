import { NextRequest, NextResponse } from 'next/server';
import { query } from '@/lib/db';
import { requireRole } from '@/lib/auth';
import { logAudit } from '@/lib/logic';

export async function GET(req: NextRequest) {
    const auth = requireRole(req, ['client', 'creator', 'admin', 'moderator']);
    if (auth.error || !auth.user) {
        return NextResponse.json({ error: auth.error }, { status: auth.status });
    }

    try {
        const filters: string[] = [];
        const params: any[] = [];

        if (auth.user.role === 'client') {
            params.push(auth.user.userId);
            filters.push(`q.client_id = $${params.length}`);
        } else if (auth.user.role === 'creator') {
            params.push(auth.user.userId);
            filters.push(`q.creator_id = $${params.length}`);
        }

        const where = filters.length > 0 ? `WHERE ${filters.join(' AND ')}` : '';

        const res = await query(
            `
                SELECT
                    q.id,
                    q.offer_id,
                    q.client_id,
                    q.creator_id,
                    q.price_snapshot::float8 AS price_snapshot,
                    q.status,
                    q.created_at,
                    offer.title AS offer_title,
                    offer.image_url AS offer_image_url,
                    creator.name AS creator_name,
                    client.name AS client_name,
                    latest_payment.id AS latest_payment_id,
                    latest_payment.status AS latest_payment_status,
                    latest_payment.method AS latest_payment_method,
                    linked_project.id AS project_id,
                    linked_project.status AS project_status
                FROM quotes q
                LEFT JOIN offers offer ON offer.id = q.offer_id
                LEFT JOIN users creator ON creator.id = q.creator_id
                LEFT JOIN users client ON client.id = q.client_id
                LEFT JOIN LATERAL (
                    SELECT p.id, p.status, p.method
                    FROM payments p
                    WHERE p.quote_id = q.id
                    ORDER BY p.created_at DESC
                    LIMIT 1
                ) latest_payment ON TRUE
                LEFT JOIN LATERAL (
                    SELECT pr.id, pr.status
                    FROM projects pr
                    WHERE pr.quote_id = q.id
                    ORDER BY pr.created_at DESC
                    LIMIT 1
                ) linked_project ON TRUE
                ${where}
                ORDER BY q.created_at DESC
            `,
            params
        );

        return NextResponse.json({ quotes: res.rows });
    } catch (e: any) {
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}

// POST /api/quotes - Client creates Quote from Offer
export async function POST(req: NextRequest) {
    const auth = requireRole(req, ['client']);
    if (auth.error) return NextResponse.json({ error: auth.error }, { status: auth.status });

    const { offerId } = await req.json();

    try {
        // 1. Fetch Offer to lock price
        const offerRes = await query('SELECT * FROM offers WHERE id = $1 AND status = \'active\'', [offerId]);
        if (offerRes.rowCount === 0) {
            return NextResponse.json({ error: 'Offer not found or inactive' }, { status: 404 });
        }
        const offer = offerRes.rows[0];

        // 2. Create Quote
        const res = await query(`
      INSERT INTO quotes (offer_id, client_id, creator_id, price_snapshot, status)
      VALUES ($1, $2, $3, $4, 'accepted')
      RETURNING id, price_snapshot, status, created_at
    `, [offerId, auth.user!.userId, offer.creator_id, offer.price_iqd]);

        const quote = res.rows[0];

        // 3. Audit
        await logAudit('quote', quote.id, 'quote_created', auth.user!.userId, { offerId, price: offer.price_iqd });

        return NextResponse.json(quote, { status: 201 });
    } catch (e: any) {
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}
