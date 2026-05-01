import { NextRequest, NextResponse } from 'next/server';
import { query } from '@/lib/db';
import { ADMIN_PANEL_ROLES, requireRole } from '@/lib/auth';
import { ensureBannersSchema } from '@/lib/feature-schema';

export async function GET(req: NextRequest) {
    const authCheck = requireRole(req, ADMIN_PANEL_ROLES);
    if (authCheck.error || !authCheck.user) {
        return NextResponse.json({ error: authCheck.error }, { status: authCheck.status });
    }

    try {
        await ensureBannersSchema();

        const sql = `
            SELECT id, image_url, link_url, title, is_active, media_items, created_at, updated_at
            FROM banners 
            ORDER BY created_at DESC
        `;
        const res = await query(sql);
        return NextResponse.json(res.rows);
    } catch (e) {
        console.error("Admin Get Banners Error:", e);
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}

export async function POST(req: NextRequest) {
    const authCheck = requireRole(req, ADMIN_PANEL_ROLES);
    if (authCheck.error || !authCheck.user) {
        return NextResponse.json({ error: authCheck.error }, { status: authCheck.status });
    }

    try {
        await ensureBannersSchema();

        const body = await req.json();
        const { title, link_url, is_active, media_items } = body;

        // media_items: [{ url: string, type: 'image' | 'video' }, ...]
        if (!title || !media_items || !Array.isArray(media_items) || media_items.length === 0) {
            return NextResponse.json({ error: 'Title and at least one media item are required' }, { status: 400 });
        }

        // Use first image as the legacy image_url for backwards compat
        const firstImage = media_items.find((m: { type: string }) => m.type === 'image');
        const legacy_image_url = firstImage?.url ?? media_items[0].url;

        // Multiple banners can be active (each = a slide in the app)

        const sql = `
            INSERT INTO banners (image_url, link_url, title, is_active, media_items) 
            VALUES ($1, $2, $3, $4, $5) 
            RETURNING id, image_url, link_url, title, is_active, media_items, created_at
        `;
        const res = await query(sql, [
            legacy_image_url,
            link_url || null,
            title,
            is_active || false,
            JSON.stringify(media_items),
        ]);

        return NextResponse.json(res.rows[0]);
    } catch (e) {
        console.error("Admin Post Banners Error:", e);
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}

export async function PUT(req: NextRequest) {
    const authCheck = requireRole(req, ADMIN_PANEL_ROLES);
    if (authCheck.error || !authCheck.user) {
        return NextResponse.json({ error: authCheck.error }, { status: authCheck.status });
    }

    try {
        await ensureBannersSchema();

        const body = await req.json();
        const { id, is_active, media_items, title, link_url } = body;

        if (!id) {
            return NextResponse.json({ error: 'Banner ID is required' }, { status: 400 });
        }

        // Multiple banners can be active (each = a slide in the app)

        // Build dynamic SET fields
        const updates: string[] = ['is_active = $1', 'updated_at = CURRENT_TIMESTAMP'];
        const params: unknown[] = [is_active ?? false, id];
        let paramIdx = 3;

        if (media_items && Array.isArray(media_items) && media_items.length > 0) {
            updates.push(`media_items = $${paramIdx}`);
            params.splice(params.length - 1, 0, JSON.stringify(media_items)); // insert before id
            paramIdx++;

            // Update legacy image_url to first image
            const firstImage = media_items.find((m: { type: string }) => m.type === 'image');
            const legacy = firstImage?.url ?? media_items[0].url;
            updates.push(`image_url = $${paramIdx}`);
            params.splice(params.length - 1, 0, legacy);
            paramIdx++;
        }

        if (title) {
            updates.push(`title = $${paramIdx}`);
            params.splice(params.length - 1, 0, title);
            paramIdx++;
        }

        if (link_url !== undefined) {
            updates.push(`link_url = $${paramIdx}`);
            params.splice(params.length - 1, 0, link_url || null);
            paramIdx++;
        }

        const sql = `
            UPDATE banners 
            SET ${updates.join(', ')}
            WHERE id = $2
            RETURNING id, image_url, link_url, title, is_active, media_items
        `;
        const res = await query(sql, params);

        if (res.rowCount === 0) {
            return NextResponse.json({ error: 'Banner not found' }, { status: 404 });
        }

        return NextResponse.json(res.rows[0]);
    } catch (e) {
        console.error("Admin Put Banners Error:", e);
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}

export async function DELETE(req: NextRequest) {
    const authCheck = requireRole(req, ADMIN_PANEL_ROLES);
    if (authCheck.error || !authCheck.user) {
        return NextResponse.json({ error: authCheck.error }, { status: authCheck.status });
    }

    try {
        await ensureBannersSchema();

        const { searchParams } = new URL(req.url);
        const id = searchParams.get('id');
        if (!id) {
            return NextResponse.json({ error: 'Banner ID is required' }, { status: 400 });
        }

        await query('DELETE FROM banners WHERE id = $1', [id]);
        return NextResponse.json({ success: true });
    } catch (e) {
        console.error("Admin Delete Banner Error:", e);
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}
