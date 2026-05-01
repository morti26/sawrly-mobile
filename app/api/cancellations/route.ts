import { NextRequest, NextResponse } from 'next/server';
import { query } from '@/lib/db';
import { ensureCreatorNotFrozen, requireRole } from '@/lib/auth';
import { logAudit } from '@/lib/logic';

export async function POST(request: NextRequest) {
    const auth = requireRole(request, ['client', 'creator', 'admin']);
    if (auth.error || !auth.user) {
        return NextResponse.json({ error: auth.error }, { status: auth.status });
    }

    const frozen = await ensureCreatorNotFrozen(auth.user);
    if (frozen) {
        return NextResponse.json({
            error: frozen.error,
            frozenUntil: frozen.frozenUntil,
        }, { status: frozen.status });
    }

    try {
        const body = await request.json();
        const projectId = (body?.projectId || '').toString();
        const reason = (body?.reason || '').toString().trim() || 'No reason provided';

        if (!projectId) {
            return NextResponse.json({ error: 'projectId is required' }, { status: 400 });
        }

        const projectRes = await query(
            `SELECT id, creator_id, client_id, status FROM projects WHERE id = $1`,
            [projectId]
        );
        if (projectRes.rowCount === 0) {
            return NextResponse.json({ error: 'Project not found' }, { status: 404 });
        }

        const project = projectRes.rows[0];
        if (auth.user.role !== 'admin') {
            const isOwner =
                project.creator_id === auth.user.userId ||
                project.client_id === auth.user.userId;
            if (!isOwner) {
                return NextResponse.json({ error: 'Forbidden' }, { status: 403 });
            }
        }

        if (project.status !== 'in_progress') {
            return NextResponse.json({ error: 'Project is not cancellable in current status' }, { status: 400 });
        }

        await query(
            `UPDATE projects SET status = 'cancelled', completed_at = NOW() WHERE id = $1`,
            [projectId]
        );

        await query(
            `INSERT INTO cancellations (project_id, cancelled_by, reason) VALUES ($1, $2, $3)`,
            [projectId, auth.user.userId, reason]
        );

        await logAudit('project', projectId, 'project_cancelled', auth.user.userId, { reason });

        return NextResponse.json({ success: true, refundPolicy: 'See Terms' });
    } catch (e: any) {
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}
