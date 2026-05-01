import { writeFile, mkdir } from 'fs/promises';
import { join } from 'path';
import { randomUUID } from 'crypto';

const MAX_UPLOAD_SIZE_BYTES = 150 * 1024 * 1024; // 150 MB
const ALLOWED_MIME_TYPES = new Set([
    'image/jpeg',
    'image/jpg',
    'image/png',
    'image/webp',
    'image/gif',
    'video/mp4',
    'video/quicktime',
    'video/webm',
    'video/x-matroska',
    'video/3gpp',
    'application/octet-stream', // some mobile uploads fallback to generic mime
]);
const ALLOWED_EXTENSIONS = new Set([
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.gif',
    '.mp4',
    '.mov',
    '.webm',
    '.mkv',
    '.avi',
    '.3gp',
    '.m4v',
    '.m3u8',
]);

function getFileExtension(fileName: string): string {
    const normalized = fileName.trim().toLowerCase();
    const lastDot = normalized.lastIndexOf('.');
    if (lastDot < 0 || lastDot === normalized.length - 1) {
        return '';
    }
    return normalized.slice(lastDot);
}

function validateUploadFile(file: File): void {
    if (!file) {
        throw new Error('No file provided');
    }

    if (file.size <= 0) {
        throw new Error('Uploaded file is empty');
    }

    if (file.size > MAX_UPLOAD_SIZE_BYTES) {
        throw new Error('File size exceeds 150 MB limit');
    }

    const mimeType = (file.type || '').trim().toLowerCase();
    const extension = getFileExtension(file.name || '');

    const hasAllowedMime = mimeType.length > 0 && ALLOWED_MIME_TYPES.has(mimeType);
    const hasAllowedExtension = extension.length > 0 && ALLOWED_EXTENSIONS.has(extension);

    if (!hasAllowedMime && !hasAllowedExtension) {
        throw new Error('Unsupported file type');
    }
}

export async function saveFile(file: File, subDir: string = ''): Promise<string> {
    validateUploadFile(file);

    const bytes = await file.arrayBuffer();
    const buffer = Buffer.from(bytes);

    // rudimentary extension extraction
    const ext = getFileExtension(file.name || '');

    const fileName = `${randomUUID()}${ext}`;
    const uploadDir = join(process.cwd(), 'public', 'uploads', subDir);
    const filePath = join(uploadDir, fileName);

    // Ensure directory exists
    await mkdir(uploadDir, { recursive: true });

    await writeFile(filePath, buffer);

    return `/uploads/${subDir ? subDir + '/' : ''}${fileName}`;
}
