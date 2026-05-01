import { NextRequest, NextResponse } from 'next/server';
import { query } from '@/lib/db';
import { requireActiveCreator } from '@/lib/auth';
import { logAudit } from '@/lib/logic';

// POST /api/deliveries - Creator Submits
export async function POST(req: NextRequest) {
    const auth = await requireActiveCreator(req);
    if (auth.error) return NextResponse.json({ error: auth.error }, { status: auth.status });

    const { projectId, deliveryUrl } = await req.json();

    try {
        const projectRes = await query(
            `SELECT id, creator_id, status FROM projects WHERE id = $1`,
            [projectId]
        );
        if (projectRes.rowCount === 0) {
            return NextResponse.json({ error: 'Project not found' }, { status: 404 });
        }

        const project = projectRes.rows[0];
        if (project.creator_id !== auth.user!.userId) {
            return NextResponse.json({ error: 'Forbidden' }, { status: 403 });
        }
        if (project.status !== 'in_progress') {
            return NextResponse.json({ error: 'Project is not active' }, { status: 400 });
        }

        const res = await query(`
      INSERT INTO deliveries (project_id, delivery_url, status)
      VALUES ($1, $2, 'submitted')
      RETURNING id, status
    `, [projectId, deliveryUrl]);

        await logAudit('delivery', res.rows[0].id, 'delivery_submitted', auth.user!.userId, { projectId });

        return NextResponse.json(res.rows[0], { status: 201 });
    } catch (e: any) {
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}
