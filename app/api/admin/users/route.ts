import { NextRequest, NextResponse } from 'next/server';
import { query } from '@/lib/db';
import { ADMIN_PANEL_ROLES, hashPassword, requireRole } from '@/lib/auth';

const ALLOWED_CREATE_ROLES = ['creator', 'client', 'admin', 'moderator'] as const;

export async function GET(req: NextRequest) {
    const auth = requireRole(req, ADMIN_PANEL_ROLES);
    if (auth.error || !auth.user) {
        return NextResponse.json({ error: auth.error }, { status: auth.status });
    }

    const { searchParams } = new URL(req.url);
    const roleFilter = searchParams.get('role'); // 'creator' | 'client' | 'admin' | 'moderator'

    let sql = `
        SELECT id, name, email, role, phone, created_at, 
        frozen_until,
        CASE
            WHEN role = 'creator' AND frozen_until IS NOT NULL AND frozen_until > NOW() THEN TRUE
            ELSE FALSE
        END AS is_frozen,
        (SELECT COUNT(*) FROM projects WHERE projects.creator_id = users.id OR projects.client_id = users.id) as project_count
        FROM users
    `;
    const params: any[] = [];

    if (roleFilter) {
        sql += ' WHERE role = $1';
        params.push(roleFilter);
    }

    sql += ' ORDER BY created_at DESC';

    try {
        const res = await query(sql, params);
        return NextResponse.json(res.rows);
    } catch (e) {
        console.error("Error fetching users:", e);
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}

export async function POST(req: NextRequest) {
    try {
        const { error, status } = requireRole(req, ['admin']);
        if (error) {
            return NextResponse.json({ error }, { status: status || 401 });
        }

        const body = await req.json();
        let { name, email, password, role, phone } = body;

        // Automatically assign 'creator' role if creating from the "Creators" page without a specific role
        if (!role) role = 'creator';
        if (typeof role === 'string') role = role.trim().toLowerCase();
        if (typeof email === 'string') email = email.trim().toLowerCase();

        if (!name || !email || !password || !role) {
            return NextResponse.json({ error: 'Missing required fields' }, { status: 400 });
        }

        if (!ALLOWED_CREATE_ROLES.includes(role)) {
            return NextResponse.json({ error: 'Invalid role' }, { status: 400 });
        }

        // Check if user already exists
        const userCheck = await query('SELECT id FROM users WHERE email = $1', [email]);
        if (userCheck.rowCount && userCheck.rowCount > 0) {
            return NextResponse.json({ error: 'Email already exists' }, { status: 409 });
        }

        const hashedPassword = await hashPassword(password);

        const res = await query(
            `INSERT INTO users (name, email, password_hash, role, phone) 
             VALUES ($1, $2, $3, $4, $5) 
             RETURNING id, name, email, role, phone, created_at`,
            [name, email, hashedPassword, role, phone || null]
        );

        return NextResponse.json(res.rows[0], { status: 201 });
    } catch (e) {
        console.error("Error creating user:", e);
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}
