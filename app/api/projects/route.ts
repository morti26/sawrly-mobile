import { NextRequest, NextResponse } from 'next/server';
import { query } from '@/lib/db';
import { ensureCreatorNotFrozen, requireRole } from '@/lib/auth';
import { logAudit } from '@/lib/logic';

const ALLOWED_STATUSES = ['in_progress', 'completed', 'cancelled'] as const;
type ProjectStatus = (typeof ALLOWED_STATUSES)[number];

export async function GET(req: NextRequest) {
    const auth = requireRole(req, ['client', 'creator', 'admin']);
    if (auth.error || !auth.user) {
        return NextResponse.json({ error: auth.error }, { status: auth.status });
    }

    try {
        let sql = `
            SELECT
                p.id,
                p.quote_id,
                p.creator_id,
                p.client_id,
                p.status,
                p.started_at,
                p.completed_at,
                p.created_at,
                offer.title AS offer_title,
                offer.image_url AS offer_image_url,
                creator.name AS creator_name,
                client.name AS client_name,
                latest_delivery.status AS latest_delivery_status,
                latest_delivery.delivery_url AS latest_delivery_url,
                COALESCE(confirmed_payments.confirmed_count, 0)::int AS confirmed_payment_count
            FROM projects p
            LEFT JOIN quotes q ON q.id = p.quote_id
            LEFT JOIN offers offer ON offer.id = q.offer_id
            LEFT JOIN users creator ON creator.id = p.creator_id
            LEFT JOIN users client ON client.id = p.client_id
            LEFT JOIN LATERAL (
                SELECT d.status, d.delivery_url
                FROM deliveries d
                WHERE d.project_id = p.id
                ORDER BY d.submitted_at DESC
                LIMIT 1
            ) latest_delivery ON TRUE
            LEFT JOIN LATERAL (
                SELECT COUNT(*) AS confirmed_count
                FROM payments pay
                WHERE (pay.project_id = p.id OR pay.quote_id = p.quote_id)
                  AND pay.status = 'confirmed'
            ) confirmed_payments ON TRUE
        `;
        const params: any[] = [];

        if (auth.user.role === 'creator') {
            sql += ' WHERE p.creator_id = $1';
            params.push(auth.user.userId);
        } else if (auth.user.role === 'client') {
            sql += ' WHERE p.client_id = $1';
            params.push(auth.user.userId);
        }

        sql += ' ORDER BY p.created_at DESC';
        const res = await query(sql, params);
        return NextResponse.json({ projects: res.rows });
    } catch (e: any) {
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}

export async function PATCH(req: NextRequest) {
    const auth = requireRole(req, ['client', 'creator', 'admin']);
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
        const body = await req.json();
        const projectId = (body?.projectId || '').toString();
        const nextStatus = (body?.newStatus || '').toString() as ProjectStatus;

        if (!projectId) {
            return NextResponse.json({ error: 'projectId is required' }, { status: 400 });
        }
        if (!ALLOWED_STATUSES.includes(nextStatus)) {
            return NextResponse.json({ error: 'Invalid status' }, { status: 400 });
        }

        const projectRes = await query(
            'SELECT id, creator_id, client_id, status FROM projects WHERE id = $1',
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

        const current = String(project.status) as ProjectStatus;
        if (current === nextStatus) {
            return NextResponse.json({ success: true, status: current });
        }

        const allowedNext: Record<ProjectStatus, ProjectStatus[]> = {
            in_progress: ['completed', 'cancelled'],
            completed: [],
            cancelled: [],
        };
        if (!allowedNext[current].includes(nextStatus)) {
            return NextResponse.json(
                { error: `Invalid transition from ${current} to ${nextStatus}` },
                { status: 400 }
            );
        }

        const res = await query(
            `
                UPDATE projects
                SET status = $1, completed_at = CASE WHEN $1 IN ('completed', 'cancelled') THEN NOW() ELSE completed_at END
                WHERE id = $2
                RETURNING id, status, completed_at
            `,
            [nextStatus, projectId]
        );

        await logAudit('project', projectId, 'project_status_updated', auth.user.userId, {
            from: current,
            to: nextStatus,
        });

        return NextResponse.json({ success: true, project: res.rows[0] });
    } catch (e: any) {
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}
