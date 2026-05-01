import { NextRequest, NextResponse } from 'next/server';
import { query } from '@/lib/db';

export async function GET(req: NextRequest) {
    const { searchParams } = new URL(req.url);
    const q = searchParams.get('q') || '';

    try {
        const res = await query(`
            SELECT o.id, o.title, o.price_iqd, o.image_url,
                   u.name as creator_name, u.id as creator_id
            FROM offers o
            JOIN users u ON o.creator_id = u.id
            WHERE o.status = 'active'
            AND ($1 = '' OR o.title ILIKE $2)
            ORDER BY o.created_at DESC
            LIMIT 30
        `, [q, `%${q}%`]);

        return NextResponse.json(res.rows);
    } catch (e: any) {
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}
