import { NextRequest } from 'next/server';
import { query } from '@/lib/db';
import { ADMIN_PANEL_ROLES, requireRole } from '@/lib/auth';

export const runtime = 'nodejs';

const encoder = new TextEncoder();

async function fetchSupportUsers() {
    const res = await query(`
        SELECT
            u.id as user_id,
            u.name as user_name,
            u.phone as user_phone,
            u.role as user_role,
            MAX(sm.created_at) as last_message_time,
            COUNT(sm.id) as message_count
        FROM support_messages sm
        JOIN users u ON sm.user_id = u.id
        GROUP BY u.id, u.name, u.phone, u.role
        ORDER BY last_message_time DESC
    `);
    return res.rows;
}

async function fetchSupportMessages(userId: string) {
    const res = await query(
        `
            SELECT id, user_id, sender_type, content, created_at
            FROM support_messages
            WHERE user_id = $1
            ORDER BY created_at ASC
        `,
        [userId]
    );
    return res.rows;
}

export async function GET(req: NextRequest) {
    const authCheck = requireRole(req, ADMIN_PANEL_ROLES);
    if (authCheck.error || !authCheck.user) {
        return new Response(JSON.stringify({ error: authCheck.error }), {
            status: authCheck.status,
            headers: { 'Content-Type': 'application/json; charset=utf-8' },
        });
    }

    const userId = req.nextUrl.searchParams.get('userId');
    let interval: NodeJS.Timeout | null = null;
    let closed = false;
    let lastSnapshot = '';

    const stream = new ReadableStream<Uint8Array>({
        async start(controller) {
            const pushSnapshot = async () => {
                if (closed) {
                    return;
                }

                try {
                    const payload = userId
                        ? await fetchSupportMessages(userId)
                        : await fetchSupportUsers();
                    const snapshot = JSON.stringify(payload);
                    if (snapshot === lastSnapshot) {
                        return;
                    }
                    lastSnapshot = snapshot;
                    controller.enqueue(encoder.encode(`data: ${snapshot}\n\n`));
                } catch (error) {
                    controller.enqueue(
                        encoder.encode(
                            `event: error\ndata: ${JSON.stringify({ error: 'Failed to load support stream' })}\n\n`
                        )
                    );
                }
            };

            controller.enqueue(encoder.encode('retry: 3000\n\n'));
            await pushSnapshot();

            interval = setInterval(() => {
                void pushSnapshot();
            }, 3000);

            req.signal.addEventListener('abort', () => {
                if (interval) {
                    clearInterval(interval);
                    interval = null;
                }
                if (!closed) {
                    closed = true;
                    controller.close();
                }
            });
        },
        cancel() {
            if (interval) {
                clearInterval(interval);
                interval = null;
            }
            closed = true;
        },
    });

    return new Response(stream, {
        headers: {
            'Content-Type': 'text/event-stream; charset=utf-8',
            'Cache-Control': 'no-cache, no-transform',
            Connection: 'keep-alive',
        },
    });
}
