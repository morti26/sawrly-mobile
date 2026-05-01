import { NextRequest, NextResponse } from 'next/server';
import { query } from '@/lib/db';
import { ADMIN_PANEL_ROLES, requireRole } from '@/lib/auth';
import { logAudit } from '@/lib/logic';

export async function POST(req: NextRequest, { params }: { params: Promise<{ id: string }> }) {
    const auth = requireRole(req, ADMIN_PANEL_ROLES);
    if (auth.error || !auth.user) {
        return NextResponse.json({ error: auth.error }, { status: auth.status });
    }

    try {
        const { id } = await params;
        const body = await req.json().catch(() => ({}));
        const reason = typeof body?.reason === 'string' ? body.reason.trim() : '';

        const res = await query(
            `
                UPDATE payments
                SET status = 'rejected', confirmed_by = $1, confirmed_at = NOW()
                WHERE id = $2 AND status = 'pending'
                RETURNING id, status
            `,
            [auth.user.userId, id]
        );

        if (res.rowCount === 0) {
            return NextResponse.json({ error: 'Payment not found or already processed' }, { status: 404 });
        }

        await logAudit('payment', id, 'payment_rejected', auth.user.userId, {
            reason: reason || null,
        });

        return NextResponse.json(res.rows[0]);
    } catch (e) {
        console.error('Admin Payment Reject Error:', e);
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}
