import { NextRequest, NextResponse } from 'next/server';
import { query } from '@/lib/db';
import { requireRole } from '@/lib/auth';
import { ensureMediaReportsTable } from '@/lib/media-reports';

export async function POST(req: NextRequest) {
    const auth = requireRole(req, ['client', 'creator', 'admin']);
    if (auth.error || !auth.user) {
        return NextResponse.json({ error: auth.error }, { status: auth.status });
    }

    try {
        await ensureMediaReportsTable();

        const body = await req.json();
        const mediaId = (body?.mediaId || '').toString().trim();
        const reason = (body?.reason || '').toString().trim();
        const details = (body?.details || '').toString().trim();
        const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

        if (!mediaId) {
            return NextResponse.json({ error: 'mediaId is required' }, { status: 400 });
        }
        if (!uuidRegex.test(mediaId)) {
            return NextResponse.json({ error: 'Invalid mediaId format' }, { status: 400 });
        }
        if (!reason) {
            return NextResponse.json({ error: 'reason is required' }, { status: 400 });
        }

        const mediaRes = await query(
            `SELECT id, creator_id, type FROM media_gallery WHERE id = $1::uuid`,
            [mediaId]
        );
        if (mediaRes.rowCount === 0) {
            return NextResponse.json({ error: 'Media not found' }, { status: 404 });
        }

        const media = mediaRes.rows[0];
        if (media.creator_id === auth.user.userId) {
            return NextResponse.json({ error: 'You cannot report your own media' }, { status: 400 });
        }

        const upsert = await query(
            `
                INSERT INTO media_reports (media_id, reporter_id, reason, details, status, updated_at)
                VALUES ($1::uuid, $2::uuid, $3, $4, 'pending', NOW())
                ON CONFLICT (media_id, reporter_id)
                DO UPDATE SET
                    reason = EXCLUDED.reason,
                    details = EXCLUDED.details,
                    status = 'pending',
                    updated_at = NOW(),
                    admin_note = NULL,
                    handled_by = NULL,
                    handled_at = NULL
                RETURNING id, status, created_at, updated_at
            `,
            [mediaId, auth.user.userId, reason, details || null]
        );

        return NextResponse.json({
            success: true,
            report: upsert.rows[0],
        });
    } catch (e) {
        console.error('Create Media Report Error:', e);
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}
