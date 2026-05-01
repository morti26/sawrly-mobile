import { NextRequest, NextResponse } from 'next/server';
import { query } from '@/lib/db';
import { getUserFromRequest } from '@/lib/auth';

// GET: Fetch support chat history for the logged-in user
export async function GET(req: NextRequest) {
    const user = getUserFromRequest(req);
    if (!user) {
        return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    try {
        const sql = `
            SELECT id, user_id, sender_type, content, created_at 
            FROM support_messages 
            WHERE user_id = $1 
            ORDER BY created_at ASC
        `;
        const res = await query(sql, [user.userId]);
        return NextResponse.json(res.rows);
    } catch (e) {
        console.error("Get Support Messages Error:", e);
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}

// POST: Add a new message from the logged-in user
export async function POST(req: NextRequest) {
    const user = getUserFromRequest(req);
    if (!user) {
        return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    try {
        const body = await req.json();
        const { content } = body;

        if (!content || typeof content !== 'string' || content.trim() === '') {
            return NextResponse.json({ error: 'Message content is required' }, { status: 400 });
        }

        const sql = `
            INSERT INTO support_messages (user_id, sender_type, content) 
            VALUES ($1, 'user', $2) 
            RETURNING id, user_id, sender_type, content, created_at
        `;
        const res = await query(sql, [user.userId, content.trim()]);

        return NextResponse.json(res.rows[0]);
    } catch (e) {
        console.error("Post Support Message Error:", e);
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}
