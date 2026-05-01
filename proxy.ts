import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';
import { verifyToken } from './lib/auth-middleware-helper';

const ADMIN_PANEL_ROLES = new Set(['admin', 'moderator']);

export async function proxy(request: NextRequest) {
    const path = request.nextUrl.pathname;

    if (path.startsWith('/admin')) {
        if (path === '/admin/login') {
            return NextResponse.next();
        }

        const token = request.cookies.get('admin_token')?.value;

        if (!token) {
            return NextResponse.redirect(new URL('/admin/login', request.url));
        }

        const payload = await verifyToken(token);
        if (!payload || !payload.role || !ADMIN_PANEL_ROLES.has(payload.role)) {
            const response = NextResponse.redirect(new URL('/admin/login', request.url));
            response.cookies.set('admin_token', '', { expires: new Date(0), path: '/' });
            return response;
        }
    }

    return NextResponse.next();
}

export const config = {
    matcher: '/admin/:path*',
};
