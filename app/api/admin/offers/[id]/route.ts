import { NextRequest, NextResponse } from 'next/server';
import { query } from '@/lib/db';
import { ADMIN_PANEL_ROLES, requireRole } from '@/lib/auth';

const ALLOWED_STATUSES = ['active', 'inactive', 'archived'] as const;
type OfferStatus = (typeof ALLOWED_STATUSES)[number];

export async function PATCH(req: NextRequest, { params }: { params: Promise<{ id: string }> }) {
    const auth = requireRole(req, ADMIN_PANEL_ROLES);
    if (auth.error || !auth.user) {
        return NextResponse.json({ error: auth.error }, { status: auth.status });
    }

    try {
        const { id } = await params;
        const body = await req.json();
        const status = String(body?.status || '').trim() as OfferStatus;

        if (!ALLOWED_STATUSES.includes(status)) {
            return NextResponse.json({ error: 'Invalid status' }, { status: 400 });
        }

        const res = await query(
            `
                UPDATE offers
                SET status = $1, updated_at = NOW()
                WHERE id = $2
                RETURNING id, status, updated_at
            `,
            [status, id]
        );

        if (res.rowCount === 0) {
            return NextResponse.json({ error: 'Offer not found' }, { status: 404 });
        }

        return NextResponse.json(res.rows[0]);
    } catch (e) {
        console.error('Admin Offers PATCH Error:', e);
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}

export async function DELETE(_req: NextRequest, { params }: { params: Promise<{ id: string }> }) {
    const auth = requireRole(_req, ADMIN_PANEL_ROLES);
    if (auth.error || !auth.user) {
        return NextResponse.json({ error: auth.error }, { status: auth.status });
    }

    try {
        const { id } = await params;
        const res = await query(
            `
                DELETE FROM offers
                WHERE id = $1
                RETURNING id
            `,
            [id]
        );

        if (res.rowCount === 0) {
            return NextResponse.json({ error: 'Offer not found' }, { status: 404 });
        }

        return NextResponse.json({ success: true, id });
    } catch (e: any) {
        console.error('Admin Offers DELETE Error:', e);
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}
