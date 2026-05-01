import { NextRequest, NextResponse } from 'next/server';
import { query } from '@/lib/db';

export async function GET(req: NextRequest) {
    const { searchParams } = new URL(req.url);
    const q = searchParams.get('q') || '';

    try {
        const res = await query(`
            SELECT id, name, role, avatar_url, bio
            FROM users 
            WHERE role = 'creator' 
            AND ($1 = '' OR name ILIKE $2)
            ORDER BY name ASC
            LIMIT 30
        `, [q, `%${q}%`]);

        return NextResponse.json(res.rows);
    } catch (e: any) {
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}
