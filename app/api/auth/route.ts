import { NextRequest, NextResponse } from 'next/server';
import { query } from '@/lib/db';
import { ADMIN_PANEL_ROLES, verifyPassword, signToken } from '@/lib/auth';
import {
    buildLoginRateLimitKey,
    checkLoginRateLimit,
    clearLoginFailures,
    recordLoginFailure,
} from '@/lib/login-rate-limit';

// Backward-compatible login endpoint.
export async function POST(request: NextRequest) {
    try {
        const body = (await request.json().catch(() => null)) as {
            email?: unknown;
            password?: unknown;
        } | null;
        const normalizedEmail =
            typeof body?.email === 'string' ? body.email.trim().toLowerCase() : '';
        const password = typeof body?.password === 'string' ? body.password : '';

        if (!normalizedEmail || !password) {
            return NextResponse.json({ error: 'Email and password are required' }, { status: 400 });
        }

        const rateLimitKey = buildLoginRateLimitKey(request, normalizedEmail);
        const rateLimitState = await checkLoginRateLimit(rateLimitKey);
        if (rateLimitState.blocked) {
            return NextResponse.json(
                {
                    error: 'Too many login attempts. Please try again later.',
                    retryAfterSeconds: rateLimitState.retryAfterSeconds,
                },
                {
                    status: 429,
                    headers: { 'Retry-After': String(rateLimitState.retryAfterSeconds) },
                }
            );
        }

        const res = await query('SELECT * FROM users WHERE lower(trim(email)) = $1', [normalizedEmail]);

        if ((res.rowCount ?? 0) === 0) {
            await recordLoginFailure(rateLimitKey);
            return NextResponse.json({ error: 'Invalid credentials' }, { status: 401 });
        }

        const user = res.rows[0];
        const match = await verifyPassword(String(password), user.password_hash);
        if (!match) {
            await recordLoginFailure(rateLimitKey);
            return NextResponse.json({ error: 'Invalid credentials' }, { status: 401 });
        }

        await clearLoginFailures(rateLimitKey);

        const token = signToken({ userId: user.id, email: user.email, role: user.role });
        const response = NextResponse.json({
            token,
            user: {
                id: user.id,
                name: user.name,
                email: user.email,
                role: user.role,
            },
        });

        if (ADMIN_PANEL_ROLES.includes(user.role)) {
            response.cookies.set('admin_token', token, {
                httpOnly: true,
                sameSite: 'strict',
                secure: process.env.NODE_ENV === 'production',
                path: '/',
                maxAge: 60 * 60 * 24,
            });
        }

        return response;
    } catch (e: any) {
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}
