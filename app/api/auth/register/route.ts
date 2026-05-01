import { NextRequest, NextResponse } from 'next/server';
import { query } from '@/lib/db';
import { hashPassword, signToken } from '@/lib/auth';

// POST /api/auth/register
export async function POST(req: NextRequest) {
    try {
        const body = await req.json();
        const { name, email, password, role, phone } = body;

        if (!['creator', 'client'].includes(role)) {
            return NextResponse.json({ error: 'Invalid role' }, { status: 400 });
        }

        // Check existing
        const existing = await query('SELECT id FROM users WHERE email = $1', [email]);
        if ((existing.rowCount ?? 0) > 0) {
            return NextResponse.json({ error: 'Email already registered' }, { status: 409 });
        }

        const hashed = await hashPassword(password);

        const res = await query(
            `INSERT INTO users (role, name, email, phone, password_hash)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING id, role, name, email`,
            [role, name, email, phone, hashed]
        );

        const user = res.rows[0];
        const token = signToken({
            userId: user.id,
            email: user.email,
            role: user.role
        });

        return NextResponse.json({ user, token }, { status: 201 });
    } catch (e: any) {
        console.error('[REGISTRATION] Error:', e);
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}
