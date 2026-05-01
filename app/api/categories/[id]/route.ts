import { NextRequest, NextResponse } from 'next/server';
import { query } from '@/lib/db';
import { ADMIN_PANEL_ROLES, requireRole } from '@/lib/auth';
import { ensureCategoriesSchema } from '@/lib/feature-schema';

export async function PUT(req: NextRequest, { params }: { params: Promise<{ id: string }> }) {
    try {
        const { id } = await params;
        await ensureCategoriesSchema();

        const { error, status, user } = requireRole(req, ADMIN_PANEL_ROLES);
        if (error) {
            return NextResponse.json({ error }, { status: status || 401 });
        }

        const body = await req.json();
        const { title, image_url, is_active, sort_order } = body;

        let updateFields = [];
        let values = [];
        let index = 1;

        if (title !== undefined) {
            updateFields.push(`title = $${index++}`);
            values.push(title);
        }
        if (image_url !== undefined) {
            updateFields.push(`image_url = $${index++}`);
            values.push(image_url);
        }
        if (is_active !== undefined) {
            updateFields.push(`is_active = $${index++}`);
            values.push(is_active);
        }
        if (sort_order !== undefined) {
            updateFields.push(`sort_order = $${index++}`);
            values.push(sort_order);
        }
        updateFields.push(`updated_at = NOW()`);

        if (updateFields.length === 1) {
            return NextResponse.json({ message: "No fields to update" });
        }

        values.push(id);
        const sql = `
            UPDATE app_categories
            SET ${updateFields.join(', ')}
            WHERE id = $${index}
            RETURNING id, title, image_url, is_active, sort_order
        `;
        const res = await query(sql, values);

        if (res.rowCount === 0) {
            return NextResponse.json({ error: 'Category not found' }, { status: 404 });
        }

        return NextResponse.json(res.rows[0]);

    } catch (e) {
        console.error("Update Category Error:", e);
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}

export async function DELETE(req: NextRequest, { params }: { params: Promise<{ id: string }> }) {
    try {
        const { id } = await params;
        await ensureCategoriesSchema();

        const { error, status, user } = requireRole(req, ADMIN_PANEL_ROLES);
        if (error) {
            return NextResponse.json({ error }, { status: status || 401 });
        }

        const sql = `DELETE FROM app_categories WHERE id = $1`;
        const res = await query(sql, [id]);

        if (res.rowCount === 0) {
            return NextResponse.json({ error: 'Category not found' }, { status: 404 });
        }

        return NextResponse.json({ success: true, message: 'Category deleted' });
    } catch (e) {
        console.error("Delete Category Error:", e);
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}
