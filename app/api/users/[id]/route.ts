import { NextResponse } from 'next/server';
import { query } from '@/lib/db';
import { getUserIdFromRequest } from '@/lib/auth-middleware-helper';

export async function GET(
    req: Request,
    { params }: { params: Promise<{ id: string }> }
) {
    try {
        const { id: targetUserId } = await params;

        // Fetch basic user details
        const userQuery = `
            SELECT id, name, email, role, phone, avatar_url, cover_image_url, bio, gender, created_at 
            FROM users 
            WHERE id = $1
        `;
        const userResult = await query(userQuery, [targetUserId]);

        if (userResult.rowCount === 0) {
            return NextResponse.json({ error: 'User not found' }, { status: 404 });
        }

        const user = userResult.rows[0];

        // Fetch Follow Stats
        const statsQuery = `
            SELECT 
                (SELECT COUNT(*) FROM followers WHERE following_id = $1) as followers_count,
                (SELECT COUNT(*) FROM followers WHERE follower_id = $1) as following_count
        `;
        const statsResult = await query(statsQuery, [targetUserId]);

        user.followers_count = parseInt(statsResult.rows[0].followers_count);
        user.following_count = parseInt(statsResult.rows[0].following_count);
        user.is_following = false; // Default

        // Determine request auth state to check if the current user is following them
        const currentUserId = await getUserIdFromRequest(req);
        if (currentUserId) {
            const checkFollowQuery = `
                SELECT id FROM followers 
                WHERE follower_id = $1 AND following_id = $2
            `;
            const checkResult = await query(checkFollowQuery, [currentUserId, targetUserId]);
            user.is_following = (checkResult.rowCount ?? 0) > 0;
        }

        return NextResponse.json(user);

    } catch (error) {
        console.error('Fetch User Error:', error);
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}
