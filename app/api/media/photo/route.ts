import { NextRequest, NextResponse } from 'next/server';
import { query } from '@/lib/db';
import { requireActiveCreator } from '@/lib/auth';
import { saveFile } from '@/lib/upload';

// GET /api/media/photo?creatorId=...
export async function GET(req: NextRequest) {
    const { searchParams } = new URL(req.url);
    const creatorId = searchParams.get('creatorId');

    // Allow fetching all if no creatorId? Or require it? 
    // For profile we need specific creator.

    let sql = "SELECT * FROM media_gallery WHERE type = 'image'";
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

export const runtime = 'nodejs';

// POST /api/media/photo - Upload Photo (Supports Fallback for DELETE)
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

            if (!id) return NextResponse.json({ error: 'Missing photo ID' }, { status: 400 });

            const res = await query(`
                DELETE FROM media_gallery 
                WHERE id = $1::uuid AND creator_id = $2::uuid AND type = 'image'
                RETURNING id
            `, [id, auth.user!.userId]);

            if (res.rows.length === 0) {
                return NextResponse.json({ error: 'Photo not found or unauthorized' }, { status: 404 });
            }

            return NextResponse.json({ success: true });
        }

        const formData = await req.formData();
        const file = formData.get('file') as File;
        const caption = formData.get('caption') as string;

        if (!file) {
            return NextResponse.json({ error: 'No file uploaded' }, { status: 400 });
        }

        // Validate type (basic check)
        if (!file.type.startsWith('image/')) {
            return NextResponse.json({ error: 'File is not an image' }, { status: 400 });
        }

        const url = await saveFile(file, 'photos');

        // Insert into DB
        const res = await query(`
            INSERT INTO media_gallery (creator_id, url, type, caption)
            VALUES ($1, $2, 'image', $3)
            RETURNING id, url, caption
        `, [auth.user!.userId, url, caption]);

        return NextResponse.json(res.rows[0], { status: 201 });
    } catch (e: any) {
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}

// DELETE /api/media/photo - Delete Photo
export async function DELETE(req: NextRequest) {
    const auth = await requireActiveCreator(req);
    if (auth.error) return NextResponse.json({ error: auth.error }, { status: auth.status });

    const { searchParams } = new URL(req.url);
    const id = searchParams.get('id');

    if (!id) return NextResponse.json({ error: 'Missing photo ID' }, { status: 400 });

    try {
        const res = await query(`
            DELETE FROM media_gallery 
            WHERE id = $1::uuid AND creator_id = $2::uuid AND type = 'image'
            RETURNING id
        `, [id, auth.user!.userId]);

        if (res.rows.length === 0) {
            return NextResponse.json({ error: 'Photo not found or unauthorized' }, { status: 404 });
        }

        return NextResponse.json({ success: true });
    } catch (e: any) {
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}
