import { NextRequest, NextResponse } from 'next/server';
import { query } from '@/lib/db';
import { ensureCreatorNotFrozen, requireRole } from '@/lib/auth';
import { canStartProject, logAudit } from '@/lib/logic';

// POST /api/projects/from-quote
export async function POST(req: NextRequest) {
    const auth = requireRole(req, ['client', 'creator']);
    if (auth.error) return NextResponse.json({ error: auth.error }, { status: auth.status });

    const frozen = await ensureCreatorNotFrozen(auth.user);
    if (frozen) {
        return NextResponse.json({
            error: frozen.error,
            frozenUntil: frozen.frozenUntil,
        }, { status: frozen.status });
    }

    const { quoteId, override } = await req.json();

    try {
        // 1. Fetch Quote
        const quoteRes = await query('SELECT * FROM quotes WHERE id = $1', [quoteId]);
        if (quoteRes.rowCount === 0) return NextResponse.json({ error: 'Quote not found' }, { status: 404 });
        const quote = quoteRes.rows[0];

        if (auth.user!.role !== 'admin') {
            const isParticipant =
                quote.client_id === auth.user!.userId ||
                quote.creator_id === auth.user!.userId;
            if (!isParticipant) {
                return NextResponse.json({ error: 'Forbidden' }, { status: 403 });
            }
        }

        // 2. Check Logic
        // If not override, strictly require payment
        let isAuthorizedToStart = false;
        let startReason = 'payment_confirmed';

        const paymentConfirmed = await canStartProject(quoteId);

        if (paymentConfirmed) {
            isAuthorizedToStart = true;
        } else if (override && auth.user!.role === 'creator') {
            // Creator Override
            if (quote.creator_id !== auth.user!.userId) return NextResponse.json({ error: 'Forbidden' }, { status: 403 });
            isAuthorizedToStart = true;
            startReason = 'creator_override';
        }

        if (!isAuthorizedToStart) {
            return NextResponse.json({ error: 'Payment not confirmed' }, { status: 402 }); // 402 Payment Required
        }

        // 3. Create Project
        const res = await query(`
      INSERT INTO projects (quote_id, creator_id, client_id, status)
      VALUES ($1, $2, $3, 'in_progress')
      RETURNING id, status, started_at
    `, [quoteId, quote.creator_id, quote.client_id]);

        const project = res.rows[0];

        // 4. Audit
        await logAudit('project', project.id, 'project_started', auth.user!.userId, { reason: startReason });

        return NextResponse.json(project, { status: 201 });
    } catch (e: any) {
        if (e.message.includes('unique constraint')) { // If we had one on quote_id
            return NextResponse.json({ error: 'Project already active for this quote' }, { status: 409 });
        }
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}
