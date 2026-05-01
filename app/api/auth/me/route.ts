import { NextRequest, NextResponse } from 'next/server';
import { query } from '@/lib/db';
import { ensureCreatorNotFrozen, getUserFromRequest } from '@/lib/auth';

export async function GET(req: NextRequest) {
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

    const res = await query('SELECT id, name, email, role, phone, avatar_url, cover_image_url, bio, gender FROM users WHERE id = $1', [userPayload.userId]);
    if ((res.rowCount ?? 0) === 0) {
        return NextResponse.json({ error: 'User not found' }, { status: 404 });
    }

    return NextResponse.json(res.rows[0]);
}
