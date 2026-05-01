import { NextRequest, NextResponse } from 'next/server';
import { query } from '@/lib/db';
import { requireRole } from '@/lib/auth';
import { logAudit } from '@/lib/logic';

// POST /api/deliveries/[id]/approve - Client Only
export async function POST(req: NextRequest, { params }: { params: Promise<{ id: string }> }) {
    const auth = requireRole(req, ['client']);
    if (auth.error) return NextResponse.json({ error: auth.error }, { status: auth.status });

    try {
        const { id } = await params;
        const ownershipRes = await query(
            `
                SELECT d.id
                FROM deliveries d
                JOIN projects p ON p.id = d.project_id
                WHERE d.id = $1 AND p.client_id = $2
            `,
            [id, auth.user!.userId]
        );
        if (ownershipRes.rowCount === 0) {
            return NextResponse.json({ error: 'Forbidden' }, { status: 403 });
        }

        // 1. Approve Delivery
        const delRes = await query(`
      UPDATE deliveries 
      SET status = 'approved', approved_at = NOW()
      WHERE id = $1 AND status = 'submitted'
      RETURNING id, project_id
    `, [id]);

        if (delRes.rowCount === 0) return NextResponse.json({ error: 'Delivery not found or already processed' }, { status: 404 });
        const delivery = delRes.rows[0];

        // 2. Mark Project Completed
        await query(`
      UPDATE projects 
      SET status = 'completed', completed_at = NOW()
      WHERE id = $1
    `, [delivery.project_id]);

        await logAudit('project', delivery.project_id, 'project_completed', auth.user!.userId, { deliveryId: id });

        return NextResponse.json({ success: true, status: 'approved' });
    } catch (e: any) {
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}
