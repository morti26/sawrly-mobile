import { NextRequest, NextResponse } from 'next/server';
import { query } from '@/lib/db';
import { ensureCreatorNotFrozen, getUserFromRequest } from '@/lib/auth';
import { ensureStatusLikesTable, hasStatusLikesTable } from '@/lib/status-likes';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

function rewriteUploadsToApi(value: unknown): unknown {
    if (typeof value !== 'string') return value;
    const trimmed = value.trim();
    if (!trimmed.startsWith('/uploads/')) return value;
    const rest = trimmed.slice('/uploads/'.length);
    return `/api/uploads/${rest}`;
}

export async function GET(req: NextRequest) {
    try {
        await ensureStatusLikesTable();
        const likesTableAvailable = await hasStatusLikesTable();
        const user = getUserFromRequest(req);

        // Fetch statuses not expired (expires_at > NOW())
        // Join with users to get name and avatar (if available, user schema doesn't have avatar yet, use placeholder or match)
        // Since User doesn't have avatar_url in DB, we'll use a placeholder or derived one.
        // Actually, we can use the media_url from status as the visual.

        const likeCountSelect = likesTableAvailable
            ? `COALESCE(lc.like_count, 0) AS like_count`
            : `0::int AS like_count`;
        const likedByMeSelect = likesTableAvailable
            ? `
                CASE
                    WHEN $1::uuid IS NULL THEN FALSE
                    ELSE EXISTS(
                        SELECT 1
                        FROM creator_status_likes slm
                        WHERE slm.status_id = cs.id
                          AND slm.user_id = $1::uuid
                    )
                END AS liked_by_me
            `
            : `FALSE AS liked_by_me`;
        const likesJoin = likesTableAvailable
            ? `
                LEFT JOIN (
                    SELECT status_id, COUNT(*)::int AS like_count
                    FROM creator_status_likes
                    GROUP BY status_id
                ) lc ON lc.status_id = cs.id
            `
            : '';

        const sql = `
            SELECT 
                cs.id, 
                cs.creator_id, 
                cs.media_url, 
                cs.media_type, 
                cs.caption, 
                cs.created_at, 
                cs.expires_at,
                u.name as creator_name,
                u.avatar_url as creator_avatar,
                ${likeCountSelect},
                ${likedByMeSelect}
            FROM creator_status cs
            JOIN users u ON cs.creator_id = u.id
            ${likesJoin}
            WHERE cs.expires_at > NOW()
            ORDER BY cs.created_at DESC
        `;

        const res = await query(sql, [user?.userId ?? null]);

        // Map to client expectation
        const statuses = res.rows.map(row => ({
            id: row.id,
            creator_id: row.creator_id,
            creator_name: row.creator_name,
            creator_avatar: rewriteUploadsToApi(row.creator_avatar),
            media_url: rewriteUploadsToApi(row.media_url),
            media_type: row.media_type,
            caption: row.caption,
            created_at: row.created_at,
            expires_at: row.expires_at,
            like_count: Number(row.like_count || 0),
            liked_by_me: row.liked_by_me === true,
        }));

        return NextResponse.json(statuses, {
            headers: {
                'Cache-Control': 'no-store',
            },
        });
    } catch (e) {
        console.error("Get Status Error:", e);
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}

export async function POST(req: NextRequest) {
    const user = getUserFromRequest(req);
    if (!user || user.role !== 'creator') { // Only creators can post status
        return NextResponse.json({ error: 'Unauthorized: Creator access required' }, { status: 403 });
    }

    const frozen = await ensureCreatorNotFrozen(user);
    if (frozen) {
        return NextResponse.json({
            error: frozen.error,
            frozenUntil: frozen.frozenUntil,
        }, { status: frozen.status });
    }

    try {
        const body = await req.json();
        const { mediaUrl, mediaType = 'image', caption } = body;

        if (!mediaUrl) {
            return NextResponse.json({ error: 'Media URL required' }, { status: 400 });
        }

        // Insert into DB
        // Expires in 24 hours
        const sql = `
            INSERT INTO creator_status (creator_id, media_url, media_type, caption, expires_at)
            VALUES ($1, $2, $3, $4, NOW() + INTERVAL '24 hours')
            RETURNING id
        `;

        await query(sql, [user.userId, mediaUrl, mediaType, caption || '']);

        return NextResponse.json({ success: true });
    } catch (e) {
        console.error("Post Status Error:", e);
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}

export async function PATCH(req: NextRequest) {
    const user = getUserFromRequest(req);
    if (!user || user.role !== 'creator') {
        return NextResponse.json({ error: 'Unauthorized: Creator access required' }, { status: 403 });
    }

    const frozen = await ensureCreatorNotFrozen(user);
    if (frozen) {
        return NextResponse.json({
            error: frozen.error,
            frozenUntil: frozen.frozenUntil,
        }, { status: frozen.status });
    }

    try {
        const body = await req.json();
        const { id, mediaUrl, mediaType, caption } = body;

        if (!id) {
            return NextResponse.json({ error: 'Status ID required' }, { status: 400 });
        }

        const updates: string[] = [];
        const params: any[] = [];
        let i = 1;

        if (mediaUrl !== undefined) {
            updates.push(`media_url = $${i++}`);
            params.push(mediaUrl);
        }
        if (mediaType !== undefined) {
            updates.push(`media_type = $${i++}`);
            params.push(mediaType);
        }
        if (caption !== undefined) {
            updates.push(`caption = $${i++}`);
            params.push(caption);
        }

        if (updates.length === 0) {
            return NextResponse.json({ error: 'No fields to update' }, { status: 400 });
        }

        // Refresh expiry window when story is updated.
        updates.push(`expires_at = NOW() + INTERVAL '24 hours'`);

        params.push(id);
        params.push(user.userId);
        const sql = `
            UPDATE creator_status
            SET ${updates.join(', ')}
            WHERE id = $${i++} AND creator_id = $${i}
            RETURNING id
        `;
        const res = await query(sql, params);

        if (res.rowCount === 0) {
            return NextResponse.json({ error: 'Story not found or unauthorized' }, { status: 404 });
        }

        return NextResponse.json({ success: true });
    } catch (e) {
        console.error("Patch Status Error:", e);
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}

export async function DELETE(req: NextRequest) {
    const user = getUserFromRequest(req);
    if (!user || user.role !== 'creator') {
        return NextResponse.json({ error: 'Unauthorized: Creator access required' }, { status: 403 });
    }

    const frozen = await ensureCreatorNotFrozen(user);
    if (frozen) {
        return NextResponse.json({
            error: frozen.error,
            frozenUntil: frozen.frozenUntil,
        }, { status: frozen.status });
    }

    try {
        const { searchParams } = new URL(req.url);
        let id = searchParams.get('id');

        if (!id) {
            const contentType = req.headers.get('content-type') || '';
            if (contentType.includes('application/json')) {
                try {
                    const body = await req.json();
                    id = body?.id;
                } catch (_) {
                    // ignore JSON parse error and fail with clear validation message below
                }
            }
        }

        if (!id) {
            return NextResponse.json({ error: 'Status ID required' }, { status: 400 });
        }

        const res = await query(
            `DELETE FROM creator_status WHERE id = $1 AND creator_id = $2 RETURNING id`,
            [id, user.userId]
        );

        if (res.rowCount === 0) {
            return NextResponse.json({ error: 'Story not found or unauthorized' }, { status: 404 });
        }

        return NextResponse.json({ success: true });
    } catch (e) {
        console.error("Delete Status Error:", e);
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}
