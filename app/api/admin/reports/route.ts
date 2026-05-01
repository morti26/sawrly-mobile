import { NextRequest, NextResponse } from 'next/server';
import { query } from '@/lib/db';
import { ADMIN_PANEL_ROLES, requireRole } from '@/lib/auth';
import { ensureMediaReportsTable } from '@/lib/media-reports';

const ALLOWED_STATUSES = ['pending', 'in_review', 'resolved', 'rejected'] as const;
type ReportStatus = (typeof ALLOWED_STATUSES)[number];

export async function GET(req: NextRequest) {
    const auth = requireRole(req, ADMIN_PANEL_ROLES);
    if (auth.error || !auth.user) {
        return NextResponse.json({ error: auth.error }, { status: auth.status });
    }

    try {
        await ensureMediaReportsTable();

        const status = req.nextUrl.searchParams.get('status')?.trim() || '';
        const onlyOpen = req.nextUrl.searchParams.get('onlyOpen') === '1';

        const params: any[] = [];
        const filters: string[] = [];

        if (status && ALLOWED_STATUSES.includes(status as ReportStatus)) {
            params.push(status);
            filters.push(`mr.status = $${params.length}`);
        }
        if (onlyOpen) {
            filters.push(`mr.status IN ('pending', 'in_review')`);
        }

        const where = filters.length ? `WHERE ${filters.join(' AND ')}` : '';

        const res = await query(
            `
                SELECT
                    mr.id,
                    mr.media_id,
                    mr.reason,
                    mr.details,
                    mr.status,
                    mr.admin_note,
                    mr.handled_at,
                    mr.created_at,
                    mr.updated_at,

                    mg.url AS media_url,
                    mg.type AS media_type,
                    mg.caption AS media_caption,
                    mg.creator_id AS creator_id,

                    creator.name AS creator_name,
                    reporter.name AS reporter_name,
                    reporter.role AS reporter_role,
                    handler.name AS handled_by_name
                FROM media_reports mr
                LEFT JOIN media_gallery mg ON mg.id = mr.media_id
                LEFT JOIN users creator ON creator.id = mg.creator_id
                JOIN users reporter ON reporter.id = mr.reporter_id
                LEFT JOIN users handler ON handler.id = mr.handled_by
                ${where}
                ORDER BY
                    CASE
                        WHEN mr.status = 'pending' THEN 1
                        WHEN mr.status = 'in_review' THEN 2
                        WHEN mr.status = 'resolved' THEN 3
                        WHEN mr.status = 'rejected' THEN 4
                        ELSE 5
                    END,
                    mr.created_at DESC
            `,
            params
        );

        return NextResponse.json(res.rows);
    } catch (e) {
        console.error('Admin Get Reports Error:', e);
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}

export async function PUT(req: NextRequest) {
    const auth = requireRole(req, ADMIN_PANEL_ROLES);
    if (auth.error || !auth.user) {
        return NextResponse.json({ error: auth.error }, { status: auth.status });
    }

    try {
        await ensureMediaReportsTable();

        const body = await req.json();
        const id = (body?.id || '').toString().trim();
        const status = (body?.status || '').toString().trim() as ReportStatus;
        const adminNote = (body?.adminNote || '').toString().trim();
        const removeMedia = body?.removeMedia === true;
        const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

        if (!id) {
            return NextResponse.json({ error: 'Report id is required' }, { status: 400 });
        }
        if (!uuidRegex.test(id)) {
            return NextResponse.json({ error: 'Invalid report id format' }, { status: 400 });
        }
        if (!ALLOWED_STATUSES.includes(status)) {
            return NextResponse.json({ error: 'Invalid status' }, { status: 400 });
        }

        const existingRes = await query(
            `SELECT id, media_id FROM media_reports WHERE id = $1::uuid`,
            [id]
        );
        if (existingRes.rowCount === 0) {
            return NextResponse.json({ error: 'Report not found' }, { status: 404 });
        }

        if (removeMedia && existingRes.rows[0].media_id) {
            await query(`DELETE FROM media_gallery WHERE id = $1::uuid`, [existingRes.rows[0].media_id]);
        }

        const res = await query(
            `
                UPDATE media_reports
                SET
                    status = $1,
                    admin_note = $2,
                    handled_by = $3::uuid,
                    handled_at = NOW(),
                    updated_at = NOW()
                WHERE id = $4::uuid
                RETURNING id, status, admin_note, handled_at, updated_at
            `,
            [status, adminNote || null, auth.user.userId, id]
        );

        return NextResponse.json({ success: true, report: res.rows[0] });
    } catch (e) {
        console.error('Admin Update Report Error:', e);
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}
