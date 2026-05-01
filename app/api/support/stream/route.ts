import { NextRequest } from 'next/server';
import { query } from '@/lib/db';
import { getUserFromRequest } from '@/lib/auth';

export const runtime = 'nodejs';

const encoder = new TextEncoder();

async function fetchMessages(userId: string) {
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
    const user = getUserFromRequest(req);
    if (!user) {
        return new Response(JSON.stringify({ error: 'Unauthorized' }), {
            status: 401,
            headers: { 'Content-Type': 'application/json; charset=utf-8' },
        });
    }

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
                    const messages = await fetchMessages(user.userId);
                    const snapshot = JSON.stringify(messages);
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
