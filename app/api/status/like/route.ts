import { NextRequest, NextResponse } from 'next/server';
import { query } from '@/lib/db';
import { getUserFromRequest } from '@/lib/auth';
import { ensureStatusLikesTable, getStatusLikeStats, hasStatusLikesTable } from '@/lib/status-likes';

export async function POST(req: NextRequest) {
    const user = getUserFromRequest(req);
    if (!user) {
        return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    try {
        await ensureStatusLikesTable();
        if (!(await hasStatusLikesTable())) {
            return NextResponse.json({ error: 'Story likes are temporarily unavailable' }, { status: 503 });
        }

        const body = await req.json();
        const statusId = body?.statusId as string | undefined;
        const liked = body?.liked !== false;

        if (!statusId) {
            return NextResponse.json({ error: 'statusId is required' }, { status: 400 });
        }

        const statusRes = await query(
            `SELECT id, creator_id FROM creator_status WHERE id = $1 AND expires_at > NOW()`,
            [statusId]
        );
        if (statusRes.rowCount === 0) {
            return NextResponse.json({ error: 'Story not found or expired' }, { status: 404 });
        }

        const creatorId = statusRes.rows[0].creator_id as string;
        if (creatorId === user.userId) {
            return NextResponse.json({ error: 'You cannot like your own story' }, { status: 400 });
        }

        if (liked) {
            await query(
                `
                    INSERT INTO creator_status_likes (status_id, user_id)
                    VALUES ($1, $2)
                    ON CONFLICT (status_id, user_id) DO NOTHING
                `,
                [statusId, user.userId]
            );
        } else {
            await query(
                `DELETE FROM creator_status_likes WHERE status_id = $1 AND user_id = $2`,
                [statusId, user.userId]
            );
        }

        const stats = await getStatusLikeStats(statusId, user.userId);
        return NextResponse.json({
            success: true,
            status_id: statusId,
            ...stats,
        });
    } catch (e) {
        console.error('Status Like Error:', e);
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}
