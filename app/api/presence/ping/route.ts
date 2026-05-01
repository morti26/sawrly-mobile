import { NextRequest, NextResponse } from 'next/server';
import { query } from '@/lib/db';
import { requireActiveCreator } from '@/lib/auth';

// POST /api/presence/ping - Creator Only
export async function POST(req: NextRequest) {
    const auth = await requireActiveCreator(req);
    if (auth.error) return NextResponse.json({ error: auth.error }, { status: auth.status });

    try {
        await query(`
      INSERT INTO creator_presence (creator_id, last_seen_at)
      VALUES ($1, NOW())
      ON CONFLICT (creator_id) DO UPDATE SET last_seen_at = NOW()
    `, [auth.user!.userId]);

        return NextResponse.json({ success: true });
    } catch (e: any) {
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}
