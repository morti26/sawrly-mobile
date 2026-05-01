import { NextResponse } from 'next/server';
import { query } from '@/lib/db';
import { ensureBannersSchema } from '@/lib/feature-schema';

export const dynamic = 'force-dynamic';

type BannerSlide = {
    url: string;
    type: 'image' | 'video';
    title?: string;
    link_url?: string;
};

function shuffleSlides(slides: BannerSlide[]): BannerSlide[] {
    const shuffled = [...slides];
    for (let index = shuffled.length - 1; index > 0; index--) {
        const randomIndex = Math.floor(Math.random() * (index + 1));
        [shuffled[index], shuffled[randomIndex]] = [shuffled[randomIndex], shuffled[index]];
    }
    return shuffled;
}

export async function GET() {
    try {
        await ensureBannersSchema();

        // Fetch ALL active banners (each banner = one slide in the mobile app)
        const sql = `
            SELECT id, image_url, link_url, title, media_items
            FROM banners 
            WHERE is_active = true 
            ORDER BY id DESC
        `;
        const res = await query(sql);

        if (res.rows.length > 0) {
            // Build a combined slides array from ALL active banners
            const slides: BannerSlide[] = [];

            for (const banner of res.rows) {
                // If banner has media_items (v2), use them
                if (Array.isArray(banner.media_items) && banner.media_items.length > 0) {
                    for (const item of banner.media_items) {
                        if (!item?.url) continue;
                        slides.push({
                            url: item.url,
                            type: item.type === 'video' ? 'video' : 'image',
                            title: banner.title,
                            link_url: banner.link_url,
                        });
                    }
                } else if (banner.image_url) {
                    // Fallback to single image_url (v1)
                    slides.push({
                        url: banner.image_url,
                        type: 'image',
                        title: banner.title,
                        link_url: banner.link_url,
                    });
                }
            }

            const randomSlides = shuffleSlides(slides);

            // Return in the new format: array of slides
            return NextResponse.json({
                id: res.rows[0].id,
                title: res.rows[0].title,
                link_url: res.rows[0].link_url,
                image_url: res.rows[0].image_url, // backwards compat
                slides: randomSlides,
            }, {
                headers: {
                    'Cache-Control': 'no-store',
                },
            });
        } else {
            return NextResponse.json(null, {
                headers: {
                    'Cache-Control': 'no-store',
                },
            });
        }
    } catch (e) {
        console.error("Fetch Active Banner Error:", e);
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}
