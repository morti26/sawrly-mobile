import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { NextRequest, NextResponse } from 'next/server';
import { query } from './db';

const SALT_ROUNDS = 10;
const JWT_SECRET = process.env.JWT_SECRET ||
    (process.env.NODE_ENV === 'production' ? '' : 'dev-secret-do-not-use-in-prod');

if (!JWT_SECRET) {
    throw new Error('JWT_SECRET environment variable is required in production');
}

export type AppRole = 'creator' | 'client' | 'admin' | 'moderator';

export interface TokenPayload {
    userId: string;
    email: string; // Added email
    role: AppRole;
}

export const ADMIN_PANEL_ROLES: AppRole[] = ['admin', 'moderator'];
export const CREATOR_FROZEN_ERROR = 'تم تجميد حساب المبدع مؤقتاً';

export const hashPassword = async (password: string): Promise<string> => {
    return await bcrypt.hash(password, SALT_ROUNDS);
};

export const verifyPassword = async (password: string, hash: string): Promise<boolean> => {
    return await bcrypt.compare(password, hash);
};

export const signToken = (payload: TokenPayload): string => {
    return jwt.sign(payload, JWT_SECRET, { expiresIn: '7d' });
};

export const verifyToken = (token: string): TokenPayload | null => {
    try {
        return jwt.verify(token, JWT_SECRET) as TokenPayload;
    } catch (error) {
        return null;
    }
};

// Middleware helper to get user from request
export const getUserFromRequest = (req: NextRequest): TokenPayload | null => {
    const authHeader = req.headers.get('authorization');
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return null;
    }
    const token = authHeader.split(' ')[1];
    return verifyToken(token);
};

export const getActiveCreatorFreezeUntil = async (userId: string): Promise<string | null> => {
    const res = await query(
        `
            SELECT frozen_until
            FROM users
            WHERE id = $1
              AND role = 'creator'
              AND frozen_until IS NOT NULL
              AND frozen_until > NOW()
            LIMIT 1
        `,
        [userId]
    );

    return res.rowCount && res.rows[0]?.frozen_until
        ? new Date(res.rows[0].frozen_until).toISOString()
        : null;
};

export const ensureCreatorNotFrozen = async (user: Pick<TokenPayload, 'userId' | 'role'> | null) => {
    if (!user || user.role !== 'creator') {
        return null;
    }

    const frozenUntil = await getActiveCreatorFreezeUntil(user.userId);
    if (!frozenUntil) {
        return null;
    }

    return {
        error: CREATOR_FROZEN_ERROR,
        status: 403,
        frozenUntil,
    };
};

export const requireActiveCreator = async (req: NextRequest) => {
    const auth = requireRole(req, ['creator']);
    if (auth.error || !auth.user) {
        return auth;
    }

    const frozen = await ensureCreatorNotFrozen(auth.user);
    if (frozen) {
        return { error: frozen.error, status: frozen.status, user: null, frozenUntil: frozen.frozenUntil };
    }

    return auth;
};

// Role Guard
export const requireRole = (req: NextRequest, allowedRoles: AppRole[]) => {
    const user = getUserFromRequest(req);
    if (!user) {
        return { error: 'Unauthorized', status: 401, user: null };
    }
    if (!allowedRoles.includes(user.role)) {
        return { error: 'Forbidden', status: 403, user: null };
    }
    return { error: null, user };
};
