import { NextRequest, NextResponse } from 'next/server';
import { query } from '@/lib/db';
import { requireActiveCreator } from '@/lib/auth';
import { saveFile } from '@/lib/upload';

export const runtime = 'nodejs';

// GET /api/events?creatorId=...
export async function GET(req: NextRequest) {
    const { searchParams } = new URL(req.url);
    const creatorId = searchParams.get('creatorId');

    let sql = `
        SELECT id, creator_id, title, date_time, location, cover_image_url, created_at
        FROM events
        WHERE 1=1
    `;
    const params: any[] = [];

    if (creatorId) {
        sql += " AND creator_id = $1";
        params.push(creatorId);
    }

    sql += " ORDER BY date_time ASC";

    try {
        const res = await query(sql, params);
        return NextResponse.json(res.rows);
    } catch (e: any) {
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}

// POST /api/events
export async function POST(req: NextRequest) {
    const auth = await requireActiveCreator(req);
    if (auth.error) return NextResponse.json({ error: auth.error }, { status: auth.status });

    const { searchParams } = new URL(req.url);
    const methodOverride = searchParams.get('_method')?.toUpperCase();

    // 1. Get ID from URL first (most reliable on IIS)
    let id = searchParams.get('id');

    try {
        // FALLBACK DELETE via POST - Handle early to avoid body issues
        if (methodOverride === 'DELETE') {
            if (!id) return NextResponse.json({ error: 'Missing event ID' }, { status: 400 });
            const res = await query(`
                DELETE FROM events 
                WHERE id = $1::uuid AND creator_id = $2::uuid
                RETURNING id
            `, [id, auth.user!.userId]);

            if (res.rows.length === 0) {
                return NextResponse.json({ error: 'Event not found or unauthorized' }, { status: 404 });
            }

            return NextResponse.json({ success: true });
        }

        // Handle body for other methods (Update/Create)
        let contentType = req.headers.get('content-type') || '';
        let body: any = {};
        if (contentType.includes('application/json')) {
            const text = await req.text();
            if (text && text.trim().length > 0) {
                body = JSON.parse(text);
                if (!id) id = body.id;
            }
        }

        // FALLBACK UPDATE via POST (JSON)
        if (id || methodOverride === 'PATCH') {
            if (contentType.includes('application/json')) {
                const { title, dateTime, location, coverImageUrl } = body;
                const res = await query(`
                    UPDATE events 
                    SET title = COALESCE($1, title),
                        date_time = COALESCE($2, date_time),
                        location = COALESCE($3, location),
                        cover_image_url = COALESCE($4, cover_image_url),
                        updated_at = NOW()
                    WHERE id = $5::uuid AND creator_id = $6::uuid
                    RETURNING id
                `, [title, dateTime, location, coverImageUrl, id, auth.user!.userId]);

                if (res.rows.length === 0) {
                    return NextResponse.json({ error: 'Event not found or unauthorized' }, { status: 404 });
                }
                return NextResponse.json({ success: true });
            }
        }

        if (contentType.includes('application/json')) {
            const { title, dateTime, location, coverImageUrl } = body;
            if (!title || !dateTime) {
                return NextResponse.json({ error: 'Title and dateTime are required' }, { status: 400 });
            }
            const res = await query(`
                INSERT INTO events (creator_id, title, date_time, location, cover_image_url)
                VALUES ($1::uuid, $2, $3, $4, $5)
                RETURNING id, title
            `, [auth.user!.userId, title, dateTime, location, coverImageUrl ?? null]);

            return NextResponse.json(res.rows[0], { status: 201 });
        }

        // ORIGINAL CREATE (Multipart)
        const formData = await req.formData();
        const title = formData.get('title') as string;
        const dateTime = formData.get('dateTime') as string; // ISO string
        const location = formData.get('location') as string;
        const coverImage = formData.get('coverImage') as File;

        let coverImageUrl = null;
        if (coverImage) {
            const isImage = coverImage.type.startsWith('image/');
            const isVideo = coverImage.type.startsWith('video/');
            if (!isImage && !isVideo) {
                return NextResponse.json({ error: 'Cover file must be an image or video' }, { status: 400 });
            }
            coverImageUrl = await saveFile(coverImage, 'events');
        }

        // Insert into DB
        const res = await query(`
            INSERT INTO events (creator_id, title, date_time, location, cover_image_url)
            VALUES ($1::uuid, $2, $3, $4, $5)
            RETURNING id, title
        `, [auth.user!.userId, title, dateTime, location, coverImageUrl]);

        return NextResponse.json(res.rows[0], { status: 201 });
    } catch (e: any) {
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}

// PATCH /api/events - Update Event
export async function PATCH(req: NextRequest) {
    const auth = await requireActiveCreator(req);
    if (auth.error) return NextResponse.json({ error: auth.error }, { status: auth.status });

    const { id, title, dateTime, location, coverImageUrl } = await req.json();

    if (!id) return NextResponse.json({ error: 'Missing event ID' }, { status: 400 });

    try {
        const res = await query(`
            UPDATE events 
            SET title = COALESCE($1, title),
                date_time = COALESCE($2, date_time),
                location = COALESCE($3, location),
                cover_image_url = COALESCE($4, cover_image_url),
                updated_at = NOW()
            WHERE id = $5::uuid AND creator_id = $6::uuid
            RETURNING id
        `, [title, dateTime, location, coverImageUrl, id, auth.user!.userId]);

        if (res.rows.length === 0) {
            return NextResponse.json({ error: 'Event not found or unauthorized' }, { status: 404 });
        }

        return NextResponse.json({ success: true });
    } catch (e: any) {
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}

// DELETE /api/events - Delete Event
export async function DELETE(req: NextRequest) {
    const auth = await requireActiveCreator(req);
    if (auth.error) return NextResponse.json({ error: auth.error }, { status: auth.status });

    const { searchParams } = new URL(req.url);
    const id = searchParams.get('id');

    if (!id) return NextResponse.json({ error: 'Missing event ID' }, { status: 400 });

    try {
        const res = await query(`
            DELETE FROM events 
            WHERE id = $1::uuid AND creator_id = $2::uuid
            RETURNING id
        `, [id, auth.user!.userId]);

        if (res.rows.length === 0) {
            return NextResponse.json({ error: 'Event not found or unauthorized' }, { status: 404 });
        }

        return NextResponse.json({ success: true });
    } catch (e: any) {
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}
