import { NextRequest, NextResponse } from 'next/server';
import { pool } from '@/lib/db';
import { ensureCreatorNotFrozen, requireRole } from '@/lib/auth';
import { logAudit } from '@/lib/logic';

// POST /api/payments/[id]/confirm
export async function POST(req: NextRequest, { params }: { params: Promise<{ id: string }> }) {
    const auth = requireRole(req, ['creator', 'admin']);
    if (auth.error) return NextResponse.json({ error: auth.error }, { status: auth.status });

    const frozen = await ensureCreatorNotFrozen(auth.user);
    if (frozen) {
        return NextResponse.json({
            error: frozen.error,
            frozenUntil: frozen.frozenUntil,
        }, { status: frozen.status });
    }

    try {
        const { id } = await params;
        const client = await pool.connect();
        let paymentStatus = 'confirmed';
        let projectId: string | null = null;
        let projectStatus = 'in_progress';
        let createdProject = false;

        try {
            await client.query('BEGIN');

            const payRes = await client.query(
                `
                    SELECT
                        p.id,
                        p.quote_id,
                        p.project_id,
                        p.status,
                        q.creator_id AS quote_creator_id,
                        q.client_id AS quote_client_id
                    FROM payments p
                    JOIN quotes q ON q.id = p.quote_id
                    WHERE p.id = $1
                    FOR UPDATE
                `,
                [id]
            );

            if (payRes.rowCount === 0) {
                await client.query('ROLLBACK');
                return NextResponse.json({ error: 'Payment not found' }, { status: 404 });
            }

            const payment = payRes.rows[0];
            if (auth.user!.role === 'creator' && payment.quote_creator_id !== auth.user!.userId) {
                await client.query('ROLLBACK');
                return NextResponse.json({ error: 'Forbidden' }, { status: 403 });
            }

            if (!payment.quote_id) {
                await client.query('ROLLBACK');
                return NextResponse.json({ error: 'Payment is not linked to a quote' }, { status: 400 });
            }

            if (payment.status === 'rejected') {
                await client.query('ROLLBACK');
                return NextResponse.json({ error: 'Rejected payment cannot be confirmed' }, { status: 400 });
            }

            if (payment.status !== 'confirmed') {
                const updatedPaymentRes = await client.query(
                    `
                        UPDATE payments
                        SET status = 'confirmed', confirmed_by = $1, confirmed_at = NOW()
                        WHERE id = $2
                        RETURNING status
                    `,
                    [auth.user!.userId, id]
                );
                paymentStatus = updatedPaymentRes.rows[0].status;
            } else {
                paymentStatus = payment.status;
            }

            const existingProjectRes = await client.query(
                `
                    SELECT id, status
                    FROM projects
                    WHERE id = $1 OR quote_id = $2
                    ORDER BY CASE WHEN id = $1 THEN 0 ELSE 1 END, created_at DESC
                    LIMIT 1
                `,
                [payment.project_id, payment.quote_id]
            );

            if (existingProjectRes.rowCount && existingProjectRes.rowCount > 0) {
                projectId = existingProjectRes.rows[0].id;
                projectStatus = existingProjectRes.rows[0].status;
            } else {
                const projectRes = await client.query(
                    `
                        INSERT INTO projects (quote_id, creator_id, client_id, status)
                        VALUES ($1, $2, $3, 'in_progress')
                        RETURNING id, status
                    `,
                    [payment.quote_id, payment.quote_creator_id, payment.quote_client_id]
                );
                projectId = projectRes.rows[0].id;
                projectStatus = projectRes.rows[0].status;
                createdProject = true;
            }

            await client.query(
                `
                    UPDATE payments
                    SET project_id = $1
                    WHERE id = $2
                `,
                [projectId, id]
            );

            await client.query('COMMIT');
        } catch (error) {
            await client.query('ROLLBACK');
            throw error;
        } finally {
            client.release();
        }

        await logAudit('payment', id, 'payment_confirmed', auth.user!.userId, {
            projectId,
        });

        if (createdProject && projectId) {
            await logAudit('project', projectId, 'project_started', auth.user!.userId, {
                reason: 'payment_confirmed',
                paymentId: id,
            });
        }

        return NextResponse.json({
            id,
            status: paymentStatus,
            project: projectId
                ? {
                    id: projectId,
                    status: projectStatus,
                }
                : null,
        });
    } catch (e: any) {
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}
