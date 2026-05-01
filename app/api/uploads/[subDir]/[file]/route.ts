import { readFile } from 'fs/promises';
import { join } from 'path';
import { NextRequest, NextResponse } from 'next/server';

export const runtime = 'nodejs';

function contentTypeFor(fileName: string): string {
  const lower = fileName.toLowerCase();
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.gif')) return 'image/gif';
  if (lower.endsWith('.mp4')) return 'video/mp4';
  if (lower.endsWith('.mov')) return 'video/quicktime';
  if (lower.endsWith('.webm')) return 'video/webm';
  if (lower.endsWith('.mkv')) return 'video/x-matroska';
  if (lower.endsWith('.3gp')) return 'video/3gpp';
  return 'application/octet-stream';
}

function isSafePathPart(value: string): boolean {
  if (!value) return false;
  if (value.includes('..')) return false;
  if (value.includes('/') || value.includes('\\')) return false;
  return true;
}

export async function GET(
  _req: NextRequest,
  { params }: { params: Promise<{ subDir: string; file: string }> },
) {
  const { subDir, file } = await params;

  if (!isSafePathPart(subDir) || !isSafePathPart(file)) {
    return NextResponse.json({ error: 'Invalid path' }, { status: 400 });
  }

  const fullPath = join(process.cwd(), 'public', 'uploads', subDir, file);

  try {
    const bytes = await readFile(fullPath);
    return new NextResponse(bytes, {
      status: 200,
      headers: {
        'Content-Type': contentTypeFor(file),
        'Cache-Control': 'public, max-age=31536000, immutable',
      },
    });
  } catch {
    return NextResponse.json({ error: 'Not found' }, { status: 404 });
  }
}
