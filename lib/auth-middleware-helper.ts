const JWT_SECRET = process.env.JWT_SECRET ||
    (process.env.NODE_ENV === 'production' ? '' : 'dev-secret-do-not-use-in-prod');

if (!JWT_SECRET) {
    throw new Error('JWT_SECRET environment variable is required in production');
}

export interface TokenPayload {
    userId: string;
    email: string; // Added email
    role: 'creator' | 'client' | 'admin' | 'moderator';
}

const textEncoder = new TextEncoder();
const textDecoder = new TextDecoder();

const base64UrlToUint8Array = (value: string): Uint8Array => {
    const base64 = value.replace(/-/g, '+').replace(/_/g, '/');
    const padded = base64.padEnd(Math.ceil(base64.length / 4) * 4, '=');
    const binary = atob(padded);
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i += 1) {
        bytes[i] = binary.charCodeAt(i);
    }
    return bytes;
};

const toArrayBuffer = (value: Uint8Array): ArrayBuffer => {
    return value.buffer.slice(value.byteOffset, value.byteOffset + value.byteLength) as ArrayBuffer;
};

const parseJwtSection = <T>(value: string): T | null => {
    try {
        return JSON.parse(textDecoder.decode(base64UrlToUint8Array(value))) as T;
    } catch {
        return null;
    }
};

export const verifyToken = async (token: string): Promise<TokenPayload | null> => {
    const parts = token.split('.');
    if (parts.length !== 3) {
        return null;
    }

    const [encodedHeader, encodedPayload, encodedSignature] = parts;
    const header = parseJwtSection<{ alg?: string; typ?: string }>(encodedHeader);
    const payload = parseJwtSection<(TokenPayload & { exp?: number }) | null>(encodedPayload);

    if (!header || !payload || header.alg !== 'HS256') {
        return null;
    }

    try {
        const key = await crypto.subtle.importKey(
            'raw',
            textEncoder.encode(JWT_SECRET),
            { name: 'HMAC', hash: 'SHA-256' },
            false,
            ['verify']
        );

        const isValid = await crypto.subtle.verify(
            'HMAC',
            key,
            toArrayBuffer(base64UrlToUint8Array(encodedSignature)),
            toArrayBuffer(textEncoder.encode(`${encodedHeader}.${encodedPayload}`))
        );

        if (!isValid) {
            return null;
        }

        if (typeof payload.exp === 'number' && payload.exp * 1000 <= Date.now()) {
            return null;
        }

        if (!payload.userId || !payload.email || !payload.role) {
            return null;
        }

        return {
            userId: payload.userId,
            email: payload.email,
            role: payload.role,
        };
    } catch {
        return null;
    }
};

export const getUserIdFromRequest = async (req: Request): Promise<string | null> => {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return null;
    }
    const token = authHeader.split(' ')[1];
    const payload = await verifyToken(token);
    return payload ? payload.userId : null;
};
