import { NextRequest, NextResponse } from 'next/server';
import { query } from '@/lib/db';
import { ensureCreatorNotFrozen, requireRole } from '@/lib/auth';

// POST /api/notifications (Send)
export async function POST(req: NextRequest) {
    const auth = requireRole(req, ['admin', 'creator']);
    if (auth.error) return NextResponse.json({ error: auth.error }, { status: auth.status });

    const frozen = await ensureCreatorNotFrozen(auth.user);
    if (frozen) {
        return NextResponse.json({
            error: frozen.error,
            frozenUntil: frozen.frozenUntil,
        }, { status: frozen.status });
    }

    try {
        const body = await req.json();
        const { title, message, type = 'system', target_user_id, broadcast } = body;

        if (!title || !message) {
            return NextResponse.json({ error: 'Title and message are required' }, { status: 400 });
        }

        if (broadcast) {
            // Broadcast to ALL users
            await query(`
                INSERT INTO notifications (user_id, type, title, message, created_at)
                SELECT id, $1, $2, $3, NOW()
                FROM users
            `, [type, title, message]);
            return NextResponse.json({ success: true, message: 'Broadcast sent' });
        } else if (target_user_id) {
            // Send to specific user
            await query(`
                INSERT INTO notifications (user_id, type, title, message, is_read)
                VALUES ($1, $2, $3, $4, false)
            `, [target_user_id, type, title, message]);
            return NextResponse.json({ success: true, message: 'Notification sent' });
        } else {
            return NextResponse.json({ error: 'Target user or broadcast flag required' }, { status: 400 });
        }

    } catch (e: any) {
        console.error("Notification POST Error:", e);
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}

// GET /api/notifications
export async function GET(req: NextRequest) {
    const auth = requireRole(req, ['client', 'creator', 'admin']);
    if (auth.error) return NextResponse.json({ error: auth.error }, { status: auth.status });

    try {
        const res = await query(`
      SELECT id, type, title, message, payload, is_read, created_at
      FROM notifications
      WHERE user_id = $1
      ORDER BY is_read ASC, created_at DESC
      LIMIT 50
    `, [auth.user!.userId]);

        return NextResponse.json(res.rows);
    } catch (e: any) {
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}
