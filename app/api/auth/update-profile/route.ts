import { NextRequest, NextResponse } from 'next/server';
import { query } from '@/lib/db';
import { ensureCreatorNotFrozen, getUserFromRequest } from '@/lib/auth';

export const runtime = 'nodejs';

export async function POST(req: NextRequest) {
    const userPayload = getUserFromRequest(req);
    if (!userPayload) {
        return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const frozen = await ensureCreatorNotFrozen(userPayload);
    if (frozen) {
        return NextResponse.json({
            error: frozen.error,
            frozenUntil: frozen.frozenUntil,
        }, { status: frozen.status });
    }

    try {
        const body = await req.json();
        const { name, bio, gender, avatar_url, cover_image_url } = body;

        // Dynamic update query
        const updates: string[] = [];
        const params: any[] = [];
        let paramIndex = 1;

        if (name !== undefined) {
            updates.push(`name = $${paramIndex++}`);
            params.push(name);
        }
        if (bio !== undefined) {
            updates.push(`bio = $${paramIndex++}`);
            params.push(bio);
        }
        if (gender !== undefined) {
            updates.push(`gender = $${paramIndex++}`);
            params.push(gender);
        }
        if (avatar_url !== undefined) {
            updates.push(`avatar_url = $${paramIndex++}`);
            params.push(avatar_url);
        }
        if (cover_image_url !== undefined) {
            updates.push(`cover_image_url = $${paramIndex++}`);
            params.push(cover_image_url);
        }

        if (updates.length === 0) {
            return NextResponse.json({ error: 'No fields to update' }, { status: 400 });
        }

        params.push(userPayload.userId);
        const sql = `
            UPDATE users 
            SET ${updates.join(', ')}
            WHERE id = $${paramIndex}
            RETURNING id, name, email, role, phone, avatar_url, cover_image_url, bio, gender
        `;

        const res = await query(sql, params);

        if (res.rowCount === 0) {
            return NextResponse.json({ error: 'User not found' }, { status: 404 });
        }

        return NextResponse.json({
            success: true,
            user: res.rows[0]
        });

    } catch (e: any) {
        console.error('Update Profile Error:', e);
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}
