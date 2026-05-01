import { NextRequest, NextResponse } from 'next/server';
import { query } from '@/lib/db';
import { requireRole } from '@/lib/auth';
import { ensureOfferSchema } from '@/lib/feature-schema';

// POST /api/offers/[id]/like — Toggle like on offer
export async function POST(
    req: NextRequest,
    { params }: { params: Promise<{ id: string }> }
) {
    await ensureOfferSchema();

    const auth = requireRole(req, ['creator', 'client', 'admin']);
    if (auth.error) return NextResponse.json({ error: auth.error }, { status: auth.status });

    const { id: offerId } = await params;
    const userId = auth.user!.userId;

    try {
        // Check if already liked
        const existing = await query(
            'SELECT id FROM offer_likes WHERE offer_id = $1 AND user_id = $2',
            [offerId, userId]
        );

        if (existing.rows.length > 0) {
            // Unlike
            await query('DELETE FROM offer_likes WHERE offer_id = $1 AND user_id = $2', [offerId, userId]);
            const countRes = await query('SELECT COUNT(*) as count FROM offer_likes WHERE offer_id = $1', [offerId]);
            return NextResponse.json({ liked: false, like_count: parseInt(countRes.rows[0].count) });
        } else {
            // Like
            await query(
                'INSERT INTO offer_likes (offer_id, user_id) VALUES ($1, $2)',
                [offerId, userId]
            );
            const countRes = await query('SELECT COUNT(*) as count FROM offer_likes WHERE offer_id = $1', [offerId]);
            return NextResponse.json({ liked: true, like_count: parseInt(countRes.rows[0].count) });
        }
    } catch (e: any) {
        console.error('Like toggle error:', e);
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}
