import { NextRequest, NextResponse } from 'next/server';
import { ADMIN_PANEL_ROLES, requireRole } from '@/lib/auth';
import { getOpsErrorRows } from '@/lib/ops-monitoring';

export async function GET(req: NextRequest) {
    const auth = requireRole(req, ADMIN_PANEL_ROLES);
    if (auth.error || !auth.user) {
        return NextResponse.json({ error: auth.error }, { status: auth.status });
    }

    try {
        const source = req.nextUrl.searchParams.get('source')?.trim();
        const rawLimit = Number(req.nextUrl.searchParams.get('limit') || '100');
        const limit = Number.isFinite(rawLimit)
            ? Math.min(Math.max(Math.trunc(rawLimit), 1), 500)
            : 100;
        const rows = await getOpsErrorRows({ source, limit });
        return NextResponse.json(rows);
    } catch (e) {
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}
