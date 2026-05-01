import { NextRequest, NextResponse } from 'next/server';
import { query } from '@/lib/db';
import { ensureCreatorNotFrozen, requireRole } from '@/lib/auth';
import { logAudit } from '@/lib/logic';

// POST /api/projects/[id]/cancel
export async function POST(req: NextRequest, { params }: { params: Promise<{ id: string }> }) {
    const auth = requireRole(req, ['client', 'creator', 'admin']);
    if (auth.error) return NextResponse.json({ error: auth.error }, { status: auth.status });

    const frozen = await ensureCreatorNotFrozen(auth.user);
    if (frozen) {
        return NextResponse.json({
            error: frozen.error,
            frozenUntil: frozen.frozenUntil,
        }, { status: frozen.status });
    }

    const { id } = await params;
    const { reason } = await req.json();

    try {
        const projectRes = await query(
            `SELECT id, creator_id, client_id, status FROM projects WHERE id = $1`,
            [id]
        );
        if (projectRes.rowCount === 0) {
            return NextResponse.json({ error: 'Project not found' }, { status: 404 });
        }

        const project = projectRes.rows[0];
        if (auth.user!.role !== 'admin') {
            const isOwner =
                project.creator_id === auth.user!.userId ||
                project.client_id === auth.user!.userId;
            if (!isOwner) {
                return NextResponse.json({ error: 'Forbidden' }, { status: 403 });
            }
        }
        if (project.status !== 'in_progress') {
            return NextResponse.json({ error: 'Project not found or not active' }, { status: 404 });
        }

        const res = await query(`
      UPDATE projects 
      SET status = 'cancelled', completed_at = NOW() -- using completed_at implies ended
      WHERE id = $1 AND status = 'in_progress'
      RETURNING id
    `, [id]);

        if (res.rowCount === 0) return NextResponse.json({ error: 'Project not found or not active' }, { status: 404 });

        // Record Cancellation
        await query(`
      INSERT INTO cancellations (project_id, cancelled_by, reason)
      VALUES ($1, $2, $3)
    `, [id, auth.user!.userId, reason || 'No reason provided']);

        await logAudit('project', id, 'project_cancelled', auth.user!.userId, { reason });

        return NextResponse.json({ success: true });
    } catch (e: any) {
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}
