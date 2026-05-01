import { NextRequest, NextResponse } from 'next/server';
import { query } from '@/lib/db';
import { requireRole } from '@/lib/auth';

// POST /api/notifications/read
export async function POST(req: NextRequest) {
    const auth = requireRole(req, ['client', 'creator']);
    if (auth.error) return NextResponse.json({ error: auth.error }, { status: auth.status });

    const { notificationIds } = await req.json(); // Array of IDs

    try {
        if (!notificationIds || !Array.isArray(notificationIds)) {
            return NextResponse.json({ error: 'Invalid payload' }, { status: 400 });
        }

        await query(`
      UPDATE notifications
      SET is_read = TRUE, read_at = NOW()
      WHERE user_id = $1 AND id = ANY($2::uuid[])
    `, [auth.user!.userId, notificationIds]);

        return NextResponse.json({ success: true });
    } catch (e: any) {
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}
