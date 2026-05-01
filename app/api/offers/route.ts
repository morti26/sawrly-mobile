import { NextRequest, NextResponse } from 'next/server';
import { getClient, query } from '@/lib/db';
import { requireActiveCreator } from '@/lib/auth';
import { ensureOfferSchema } from '@/lib/feature-schema';

type OfferMediaType = 'image' | 'video';
type OfferMediaItem = { url: string; type: OfferMediaType };

function isProbablyVideoUrl(url: string): boolean {
    const normalized = url.toLowerCase();
    if (normalized.includes('/videos/')) return true;
    return ['.mp4', '.mov', '.webm', '.mkv', '.m3u8', '.m4v', '.avi'].some((ext) => normalized.endsWith(ext));
}

function parseOfferMediaItems(input: unknown): { items: OfferMediaItem[] | null; error?: string } {
    if (input === undefined) return { items: null };
    if (!Array.isArray(input)) return { items: null, error: 'Invalid mediaItems' };

    const items: OfferMediaItem[] = [];
    for (const raw of input) {
        if (!raw || typeof raw !== 'object') return { items: null, error: 'Invalid mediaItems' };
        const url = typeof (raw as any).url === 'string' ? String((raw as any).url).trim() : '';
        if (!url) return { items: null, error: 'Invalid mediaItems' };

        const rawType = (raw as any).type;
        const type: OfferMediaType =
            rawType === 'image' || rawType === 'video'
                ? rawType
                : (isProbablyVideoUrl(url) ? 'video' : 'image');

        items.push({ url, type });
    }

    if (items.length > 4) return { items: null, error: 'Too many media items' };
    const videoCount = items.filter((i) => i.type === 'video').length;
    const imageCount = items.filter((i) => i.type === 'image').length;
    if (videoCount > 1) return { items: null, error: 'Only one video is allowed' };
    if (imageCount > 3) return { items: null, error: 'Only three images are allowed' };

    return { items };
}

function derivePrimaryImageUrl(mediaItems: OfferMediaItem[] | null, imageUrl: unknown): string | null {
    const direct = typeof imageUrl === 'string' ? imageUrl.trim() : '';
    if (direct) return direct;
    if (!mediaItems || mediaItems.length === 0) return null;
    const firstImage = mediaItems.find((i) => i.type === 'image');
    return (firstImage?.url || mediaItems[0]?.url || '').trim() || null;
}

async function replaceOfferMediaItems(
    client: { query: (text: string, params?: any[]) => Promise<any> },
    offerId: string,
    mediaItems: OfferMediaItem[] | null
): Promise<void> {
    if (mediaItems === null) return;
    await client.query(`DELETE FROM offer_media_items WHERE offer_id = $1`, [offerId]);
    if (mediaItems.length === 0) return;

    const insertSql = `
        INSERT INTO offer_media_items (offer_id, url, type, sort_order)
        VALUES ($1, $2, $3, $4)
    `;
    for (let i = 0; i < mediaItems.length; i++) {
        const item = mediaItems[i];
        await client.query(insertSql, [offerId, item.url, item.type, i]);
    }
}

// GET /api/offers - List Active Offers
// ?sort=popular   → sorted by likes + orders
// ?sort=newest    → sorted by date (default)
// ?filter=discount    → only offers with discount_percent > 0
// ?filter=no_discount → only offers without discount
// ?limit=N        → limit results
export async function GET(req: NextRequest) {
    await ensureOfferSchema();

    const { searchParams } = new URL(req.url);
    const creatorId = searchParams.get('creatorId');
    const sort = searchParams.get('sort');
    const filter = searchParams.get('filter');
    const limit = searchParams.get('limit');

    let sql = `
      SELECT o.id, o.title, o.description, o.price_iqd, o.image_url, o.creator_id,
             o.discount_percent, o.original_price_iqd,
             u.name as creator_name,
             COALESCE(lk.like_count, 0)::int as like_count,
             COALESCE(qc.order_count, 0)::int as order_count,
             COALESCE(mi.media_items, jsonb_build_array()) AS media_items
      FROM offers o
      JOIN users u ON o.creator_id = u.id
      LEFT JOIN LATERAL (
          SELECT jsonb_agg(
              jsonb_build_object('url', omi.url, 'type', omi.type)
              ORDER BY omi.sort_order
          ) AS media_items
          FROM offer_media_items omi
          WHERE omi.offer_id = o.id
      ) mi ON TRUE
      LEFT JOIN (
          SELECT offer_id, COUNT(*) as like_count FROM offer_likes GROUP BY offer_id
      ) lk ON lk.offer_id = o.id
      LEFT JOIN (
          SELECT offer_id, COUNT(*) as order_count FROM quotes GROUP BY offer_id
      ) qc ON qc.offer_id = o.id
      WHERE o.status = 'active'
    `;

    const params: any[] = [];
    let paramIdx = 1;

    if (creatorId) {
        sql += ` AND o.creator_id = $${paramIdx}`;
        params.push(creatorId);
        paramIdx++;
    }

    // Filter: discount / no_discount
    if (filter === 'discount') {
        sql += ` AND (COALESCE(o.discount_percent, 0) > 0 OR o.description ILIKE '%Discount:%')`;
    } else if (filter === 'no_discount') {
        sql += ` AND COALESCE(o.discount_percent, 0) = 0 AND o.description NOT ILIKE '%Discount:%'`;
    }

    if (sort === 'popular') {
        sql += ` ORDER BY (COALESCE(lk.like_count, 0) + COALESCE(qc.order_count, 0)) DESC, o.created_at DESC`;
    } else {
        sql += ` ORDER BY o.created_at DESC`;
    }

    if (limit) {
        sql += ` LIMIT $${paramIdx}`;
        params.push(parseInt(limit));
        paramIdx++;
    }

    try {
        const res = await query(sql, params);

        if (res.rows.length > 0) {
            return NextResponse.json(res.rows);
        }

        // Empty result — return empty array (no mock data)
        return NextResponse.json([]);
    } catch (e: any) {
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}

// POST /api/offers - Creator Only (Supports Fallback for PATCH/DELETE)
export async function POST(req: NextRequest) {
    await ensureOfferSchema();

    const auth = await requireActiveCreator(req);
    if (auth.error) return NextResponse.json({ error: auth.error }, { status: auth.status });

    const { searchParams } = new URL(req.url);
    const methodOverride = searchParams.get('_method')?.toUpperCase();

    let id = searchParams.get('id');

    // FALLBACK DELETE via POST
    if (methodOverride === 'DELETE') {
        if (!id) {
            return NextResponse.json({ error: 'Missing offer ID' }, { status: 400 });
        }
        try {
            const res = await query(`DELETE FROM offers WHERE id = $1 AND creator_id = $2 RETURNING id`, [id, auth.user!.userId]);
            if (res.rows.length === 0) {
                return NextResponse.json({ error: 'Offer not found or unauthorized' }, { status: 404 });
            }
            return NextResponse.json({ success: true });
        } catch (e: any) {
            return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
        }
    }

    // Try to parse body
    let body: any = {};
    try {
        const contentType = req.headers.get('content-type') || '';
        if (contentType.includes('application/json')) {
            const text = await req.text();
            if (text && text.trim().length > 0) {
                body = JSON.parse(text);
                if (!id) id = body.id;
            }
        }
    } catch {}

    const { title, description, priceIqd, imageUrl, mediaItems, discountPercent, originalPriceIqd } = body;
    const parsedMedia = parseOfferMediaItems(mediaItems);
    if (parsedMedia.error) {
        return NextResponse.json({ error: parsedMedia.error }, { status: 400 });
    }
    const finalMediaItems = parsedMedia.items;
    const finalImageUrl = derivePrimaryImageUrl(finalMediaItems, imageUrl);

    // FALLBACK UPDATE via POST
    if (id || methodOverride === 'PATCH') {
        if (!id) {
            return NextResponse.json({ error: 'Missing offer ID' }, { status: 400 });
        }
        const client = await getClient();
        try {
            await client.query('BEGIN');
            const res = await client.query(
                `
                    UPDATE offers 
                    SET title = COALESCE($1, title),
                        description = COALESCE($2, description),
                        price_iqd = COALESCE($3, price_iqd),
                        image_url = COALESCE($4, image_url),
                        discount_percent = COALESCE($7, discount_percent),
                        original_price_iqd = COALESCE($8, original_price_iqd),
                        updated_at = NOW()
                    WHERE id = $5::uuid AND creator_id = $6::uuid
                    RETURNING id
                `,
                [title, description, priceIqd, finalImageUrl, id, auth.user!.userId, discountPercent ?? null, originalPriceIqd ?? null]
            );

            if (res.rows.length === 0) {
                await client.query('ROLLBACK');
                return NextResponse.json({ error: 'Offer not found or unauthorized' }, { status: 404 });
            }

            await replaceOfferMediaItems(client, id, finalMediaItems);
            await client.query('COMMIT');
            return NextResponse.json({ success: true });
        } catch (e: any) {
            try {
                await client.query('ROLLBACK');
            } catch {}
            return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
        } finally {
            client.release();
        }
    }

    // CREATE NEW OFFER
    const client = await getClient();
    try {
        const finalDiscount = discountPercent && discountPercent > 0 ? discountPercent : 0;
        const finalOriginal = originalPriceIqd && originalPriceIqd > 0 ? originalPriceIqd : null;

        await client.query('BEGIN');
        const res = await client.query(
            `
                INSERT INTO offers (creator_id, title, description, price_iqd, image_url, discount_percent, original_price_iqd)
                VALUES ($1, $2, $3, $4, $5, $6, $7)
                RETURNING id
            `,
            [auth.user!.userId, title, description, priceIqd, finalImageUrl, finalDiscount, finalOriginal]
        );
        const offerId = res.rows[0]?.id as string;
        await replaceOfferMediaItems(client, offerId, finalMediaItems ?? []);
        await client.query('COMMIT');

        // Automated Notification
        try {
            const userRes = await query('SELECT name FROM users WHERE id = $1', [auth.user!.userId]);
            const creatorName = userRes.rows[0]?.name || 'Unknown Creator';
            const notifTitle = `عرض جديد: ${title}`;
            const notifMessage = `تفقد العرض الجديد من ${creatorName}`;
            await query(`
                INSERT INTO notifications (user_id, type, title, message, created_at)
                SELECT id, 'system', $1, $2, NOW() FROM users
            `, [notifTitle, notifMessage]);
        } catch (notifError) {
            console.error('Failed to send auto-notification:', notifError);
        }

        return NextResponse.json(res.rows[0], { status: 201 });
    } catch (e: any) {
        try {
            await client.query('ROLLBACK');
        } catch {}
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    } finally {
        client.release();
    }
}

// PATCH /api/offers - Update Offer
export async function PATCH(req: NextRequest) {
    await ensureOfferSchema();

    const auth = await requireActiveCreator(req);
    if (auth.error) return NextResponse.json({ error: auth.error }, { status: auth.status });

    const { id, title, description, priceIqd, imageUrl, mediaItems, discountPercent, originalPriceIqd } = await req.json();
    if (!id) return NextResponse.json({ error: 'Missing offer ID' }, { status: 400 });
    const parsedMedia = parseOfferMediaItems(mediaItems);
    if (parsedMedia.error) {
        return NextResponse.json({ error: parsedMedia.error }, { status: 400 });
    }
    const finalMediaItems = parsedMedia.items;
    const finalImageUrl = derivePrimaryImageUrl(finalMediaItems, imageUrl);

    const client = await getClient();
    try {
        await client.query('BEGIN');
        const res = await client.query(
            `
                UPDATE offers 
                SET title = COALESCE($1, title),
                    description = COALESCE($2, description),
                    price_iqd = COALESCE($3, price_iqd),
                    image_url = COALESCE($4, image_url),
                    discount_percent = COALESCE($7, discount_percent),
                    original_price_iqd = COALESCE($8, original_price_iqd),
                    updated_at = NOW()
                WHERE id = $5::uuid AND creator_id = $6::uuid
                RETURNING id
            `,
            [title, description, priceIqd, finalImageUrl, id, auth.user!.userId, discountPercent ?? null, originalPriceIqd ?? null]
        );

        if (res.rows.length === 0) {
            await client.query('ROLLBACK');
            return NextResponse.json({ error: 'Offer not found or unauthorized' }, { status: 404 });
        }
        await replaceOfferMediaItems(client, id, finalMediaItems);
        await client.query('COMMIT');
        return NextResponse.json({ success: true });
    } catch (e: any) {
        try {
            await client.query('ROLLBACK');
        } catch {}
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    } finally {
        client.release();
    }
}

// DELETE /api/offers
export async function DELETE(req: NextRequest) {
    await ensureOfferSchema();

    const auth = await requireActiveCreator(req);
    if (auth.error) return NextResponse.json({ error: auth.error }, { status: auth.status });

    const { searchParams } = new URL(req.url);
    const id = searchParams.get('id');
    if (!id) return NextResponse.json({ error: 'Missing offer ID' }, { status: 400 });

    try {
        const res = await query(`DELETE FROM offers WHERE id = $1 AND creator_id = $2 RETURNING id`, [id, auth.user!.userId]);
        if (res.rows.length === 0) {
            return NextResponse.json({ error: 'Offer not found or unauthorized' }, { status: 404 });
        }
        return NextResponse.json({ success: true });
    } catch (e: any) {
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}
