import { NextRequest, NextResponse } from 'next/server';
import { query } from '@/lib/db';
import { ADMIN_PANEL_ROLES, requireRole } from '@/lib/auth';

export async function GET(req: NextRequest) {
    const authCheck = requireRole(req, ADMIN_PANEL_ROLES);
    if (authCheck.error || !authCheck.user) {
        return NextResponse.json({ error: authCheck.error }, { status: authCheck.status });
    }

    const searchParams = req.nextUrl.searchParams;
    const userId = searchParams.get('userId');

    try {
        if (userId) {
            // Fetch chat history for a specific user
            const sql = `
                SELECT id, user_id, sender_type, content, created_at 
                FROM support_messages 
                WHERE user_id = $1 
                ORDER BY created_at ASC
            `;
            const res = await query(sql, [userId]);
            return NextResponse.json(res.rows);
        } else {
            // Fetch list of users who have sent support messages
            const sql = `
                SELECT 
                    u.id as user_id, 
                    u.name as user_name, 
                    u.phone as user_phone,
                    u.role as user_role,
                    MAX(sm.created_at) as last_message_time,
                    COUNT(sm.id) as message_count
                FROM support_messages sm
                JOIN users u ON sm.user_id = u.id
                GROUP BY u.id, u.name, u.phone, u.role
                ORDER BY last_message_time DESC
            `;
            const res = await query(sql);
            return NextResponse.json(res.rows);
        }
    } catch (e) {
        console.error("Admin Get Support Error:", e);
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}

export async function POST(req: NextRequest) {
    const authCheck = requireRole(req, ADMIN_PANEL_ROLES);
    if (authCheck.error || !authCheck.user) {
        return NextResponse.json({ error: authCheck.error }, { status: authCheck.status });
    }

    try {
        const body = await req.json();
        const { userId, content } = body;

        if (!userId || !content || typeof content !== 'string' || content.trim() === '') {
            return NextResponse.json({ error: 'User ID and message content are required' }, { status: 400 });
        }

        const sql = `
            INSERT INTO support_messages (user_id, sender_type, content) 
            VALUES ($1, 'admin', $2) 
            RETURNING id, user_id, sender_type, content, created_at
        `;
        const res = await query(sql, [userId, content.trim()]);

        return NextResponse.json(res.rows[0]);
    } catch (e) {
        console.error("Admin Post Support Error:", e);
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}
