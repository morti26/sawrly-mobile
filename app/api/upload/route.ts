import { NextRequest, NextResponse } from 'next/server';
import { saveFile } from '@/lib/upload';
import { ensureCreatorNotFrozen, getUserFromRequest } from '@/lib/auth';

export const runtime = 'nodejs';

export async function POST(req: NextRequest) {
    const user = getUserFromRequest(req);
    if (!user) {
        return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
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
        const formData = await req.formData();
        const file = formData.get('file') as File;
        const rawSubDir = (formData.get('subDir') ?? searchParams.get('subDir')) as unknown;
        const subDir = typeof rawSubDir === 'string' ? rawSubDir.trim() : '';
        const allowedSubDirs = new Set(['status', 'offers', 'photos', 'videos', 'events', 'banners']);

        if (!file) {
            return NextResponse.json({ error: 'No file provided' }, { status: 400 });
        }

        if (subDir && !allowedSubDirs.has(subDir)) {
            return NextResponse.json({ error: 'Invalid upload destination' }, { status: 400 });
        }

        const url = await saveFile(file, subDir || 'status');

        return NextResponse.json({ url });
    } catch (e) {
        const message = e instanceof Error ? e.message : '';
        if (
            message === 'No file provided' ||
            message === 'Uploaded file is empty' ||
            message === 'File size exceeds 150 MB limit' ||
            message === 'Unsupported file type'
        ) {
            return NextResponse.json({ error: message }, { status: 400 });
        }

        console.error('Upload Error:', e);
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}
