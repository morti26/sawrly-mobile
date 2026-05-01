import { NextResponse } from 'next/server';
import { query } from '@/lib/db';
import { getUserIdFromRequest } from '@/lib/auth-middleware-helper';

// GET: fetch all reviews for a creator
export async function GET(
    req: Request,
    { params }: { params: Promise<{ id: string }> }
) {
    const { id: creatorId } = await params;
    try {
        const result = await query(`
            SELECT 
                r.id,
                r.rating,
                r.comment,
                r.created_at,
                u.name as reviewer_name,
                u.avatar_url as reviewer_avatar
            FROM reviews r
            JOIN users u ON r.reviewer_id = u.id
            WHERE r.creator_id = $1
            ORDER BY r.created_at DESC
        `, [creatorId]);

        // Also compute the average rating
        const avgResult = await query(`
            SELECT 
                COALESCE(AVG(rating), 0)::NUMERIC(3,1) as avg_rating,
                COUNT(*) as total_reviews
            FROM reviews 
            WHERE creator_id = $1
        `, [creatorId]);

        return NextResponse.json({
            reviews: result.rows,
            avg_rating: parseFloat(avgResult.rows[0].avg_rating),
            total_reviews: parseInt(avgResult.rows[0].total_reviews),
        });
    } catch (e: any) {
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}

// POST: submit or update a review
export async function POST(
    req: Request,
    { params }: { params: Promise<{ id: string }> }
) {
    const { id: creatorId } = await params;
    try {
        const reviewerId = await getUserIdFromRequest(req);
        if (!reviewerId) {
            return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
        }
        if (reviewerId === creatorId) {
            return NextResponse.json({ error: 'You cannot review yourself' }, { status: 400 });
        }

        const { rating, comment } = await req.json();
        if (!rating || rating < 1 || rating > 5) {
            return NextResponse.json({ error: 'Rating must be between 1 and 5' }, { status: 400 });
        }

        // Upsert: update if already reviewed, otherwise insert
        await query(`
            INSERT INTO reviews (creator_id, reviewer_id, rating, comment)
            VALUES ($1, $2, $3, $4)
            ON CONFLICT (creator_id, reviewer_id) 
            DO UPDATE SET rating = $3, comment = $4, created_at = NOW()
        `, [creatorId, reviewerId, rating, comment ?? null]);

        // Return updated stats
        const avgResult = await query(`
            SELECT 
                COALESCE(AVG(rating), 0)::NUMERIC(3,1) as avg_rating,
                COUNT(*) as total_reviews
            FROM reviews 
            WHERE creator_id = $1
        `, [creatorId]);

        return NextResponse.json({
            success: true,
            avg_rating: parseFloat(avgResult.rows[0].avg_rating),
            total_reviews: parseInt(avgResult.rows[0].total_reviews),
            message: 'Review submitted successfully',
        });
    } catch (e: any) {
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}
