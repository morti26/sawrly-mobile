import { NextRequest, NextResponse } from 'next/server';
import { query } from '@/lib/db';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
    try {
        // Online if seen in last 15 minutes
        const res = await query(`
      SELECT creator_id, last_seen_at 
      FROM creator_presence
      WHERE last_seen_at > NOW() - INTERVAL '15 minutes'
    `);

        return NextResponse.json(res.rows);
    } catch (e: any) {
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}
