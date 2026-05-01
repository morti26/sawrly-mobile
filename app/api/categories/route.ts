import { NextRequest, NextResponse } from 'next/server';
import { query } from '@/lib/db';
import { ADMIN_PANEL_ROLES, requireRole } from '@/lib/auth';
import { ensureCategoriesSchema } from '@/lib/feature-schema';

export const dynamic = 'force-dynamic';

export async function GET() {
    try {
        await ensureCategoriesSchema();

        const sql = `
            SELECT id, title, image_url, is_active, sort_order
            FROM app_categories 
            ORDER BY sort_order ASC, created_at DESC
        `;
        const res = await query(sql);
        return NextResponse.json(res.rows);
    } catch (e) {
        console.error("Fetch Categories Error:", e);
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}

export async function POST(req: NextRequest) {
    try {
        await ensureCategoriesSchema();

        const { error, status, user } = requireRole(req, ADMIN_PANEL_ROLES);
        if (error) {
            return NextResponse.json({ error }, { status: status || 401 });
        }

        const body = await req.json();
        const { title, image_url, is_active, sort_order } = body;

        if (!title || !image_url) {
            return NextResponse.json({ error: 'Title and Image URL are required' }, { status: 400 });
        }

        const sql = `
            INSERT INTO app_categories (title, image_url, is_active, sort_order)
            VALUES ($1, $2, $3, $4)
            RETURNING id, title, image_url, is_active, sort_order
        `;
        const res = await query(sql, [
            title,
            image_url,
            is_active !== undefined ? is_active : true,
            sort_order || 0
        ]);

        return NextResponse.json(res.rows[0], { status: 201 });
    } catch (e) {
        console.error("Create Category Error:", e);
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}
