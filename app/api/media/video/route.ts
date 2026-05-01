import { NextRequest, NextResponse } from 'next/server';
import { query } from '@/lib/db';
import { requireActiveCreator } from '@/lib/auth';
import { saveFile } from '@/lib/upload';

export const runtime = 'nodejs';

// GET /api/media/video?creatorId=...
export async function GET(req: NextRequest) {
    const { searchParams } = new URL(req.url);
    const creatorId = searchParams.get('creatorId');

    let sql = "SELECT * FROM media_gallery WHERE type = 'video'";
    const params: any[] = [];

    if (creatorId) {
        sql += " AND creator_id = $1";
        params.push(creatorId);
    }

    sql += " ORDER BY created_at DESC";

    try {
        const res = await query(sql, params);
        return NextResponse.json(res.rows);
    } catch (e: any) {
        const message = e instanceof Error ? e.message : '';
        if (
            message === 'Uploaded file is empty' ||
            message === 'File size exceeds 150 MB limit' ||
            message === 'Unsupported file type'
        ) {
            return NextResponse.json({ error: message }, { status: 400 });
        }
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}

// POST /api/media/video - Upload Video (Supports Fallback for DELETE)
export async function POST(req: NextRequest) {
    const auth = await requireActiveCreator(req);
    if (auth.error) return NextResponse.json({ error: auth.error }, { status: auth.status });

    const { searchParams } = new URL(req.url);
    const methodOverride = searchParams.get('_method')?.toUpperCase();

    // 1. Get ID from URL first (most reliable on IIS)
    let id = searchParams.get('id');

    try {
        const contentType = req.headers.get('content-type') || '';

        // FALLBACK DELETE via POST
        if (methodOverride === 'DELETE') {
            if (!id && contentType.includes('application/json')) {
                try {
                    const text = await req.text();
                    if (text && text.trim().length > 0) {
                        const body = JSON.parse(text);
                        id = body.id;
                    }
                } catch {}
            }

            if (!id) return NextResponse.json({ error: 'Missing video ID' }, { status: 400 });

            const res = await query(`
                DELETE FROM media_gallery 
                WHERE id = $1::uuid AND creator_id = $2::uuid AND type = 'video'
                RETURNING id
            `, [id, auth.user!.userId]);

            if (res.rows.length === 0) {
                return NextResponse.json({ error: 'Video not found or unauthorized' }, { status: 404 });
            }

            return NextResponse.json({ success: true });
        }

        const formData = await req.formData();
        const file = formData.get('file') as File;
        const caption = formData.get('caption') as string;

        if (!file) {
            return NextResponse.json({ error: 'No file uploaded' }, { status: 400 });
        }

        const normalizedType = (file.type || '').toLowerCase();
        const normalizedName = (file.name || '').toLowerCase();
        const hasVideoExtension = ['.mp4', '.mov', '.m4v', '.webm', '.mkv', '.avi', '.3gp', '.m3u8']
            .some((ext) => normalizedName.endsWith(ext));

        // Some Android/IIS uploads arrive with a generic MIME type.
        if (!normalizedType.startsWith('video/') && !hasVideoExtension) {
            return NextResponse.json({
                error: 'File is not a video',
                mimeType: file.type || null,
                fileName: file.name || null,
            }, { status: 400 });
        }

        const url = await saveFile(file, 'videos');

        // Insert into DB
        const res = await query(`
            INSERT INTO media_gallery (creator_id, url, type, caption)
            VALUES ($1, $2, 'video', $3)
            RETURNING id, url, caption
        `, [auth.user!.userId, url, caption]);

        return NextResponse.json(res.rows[0], { status: 201 });
    } catch (e: any) {
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}

// DELETE /api/media/video - Delete Video
export async function DELETE(req: NextRequest) {
    const auth = await requireActiveCreator(req);
    if (auth.error) return NextResponse.json({ error: auth.error }, { status: auth.status });

    const { searchParams } = new URL(req.url);
    const id = searchParams.get('id');

    if (!id) return NextResponse.json({ error: 'Missing video ID' }, { status: 400 });

    try {
        const res = await query(`
            DELETE FROM media_gallery 
            WHERE id = $1::uuid AND creator_id = $2::uuid AND type = 'video'
            RETURNING id
        `, [id, auth.user!.userId]);

        if (res.rows.length === 0) {
            return NextResponse.json({ error: 'Video not found or unauthorized' }, { status: 404 });
        }

        return NextResponse.json({ success: true });
    } catch (e: any) {
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}
