import { NextResponse } from 'next/server';
import { query } from '@/lib/db';
import { getUserIdFromRequest } from '@/lib/auth-middleware-helper';

export async function POST(
    req: Request,
    { params }: { params: Promise<{ id: string }> }
) {
    try {
        const { id: followingId } = await params;

        // Ensure user is authenticated
        const followerId = await getUserIdFromRequest(req);
        if (!followerId) {
            return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
        }

        if (followingId === followerId) {
            return NextResponse.json({ error: 'You cannot follow yourself' }, { status: 400 });
        }

        // Check if the user to follow exists
        const userCheck = await query('SELECT id FROM users WHERE id = $1', [followingId]);
        if (userCheck.rowCount === 0) {
            return NextResponse.json({ error: 'User not found' }, { status: 404 });
        }

        // 1. Check current follow status
        const checkFollowQuery = `
            SELECT id FROM followers 
            WHERE follower_id = $1 AND following_id = $2
        `;
        const existingFollow = await query(checkFollowQuery, [followerId, followingId]);

        let isFollowing = false;

        if (existingFollow.rowCount === 0) {
            // Not following -> Follow
            const insertQuery = `
                INSERT INTO followers (follower_id, following_id) 
                VALUES ($1, $2)
            `;
            await query(insertQuery, [followerId, followingId]);
            isFollowing = true;
        } else {
            // Following -> Unfollow
            const deleteQuery = `
                DELETE FROM followers 
                WHERE follower_id = $1 AND following_id = $2
            `;
            await query(deleteQuery, [followerId, followingId]);
            isFollowing = false;
        }

        // 2. Fetch updated statistics
        const statsQuery = `
            SELECT 
                (SELECT COUNT(*) FROM followers WHERE following_id = $1) as followers_count,
                (SELECT COUNT(*) FROM followers WHERE follower_id = $1) as following_count
        `;
        const statsResult = await query(statsQuery, [followingId]);

        return NextResponse.json({
            is_following: isFollowing,
            followers_count: parseInt(statsResult.rows[0].followers_count),
            following_count: parseInt(statsResult.rows[0].following_count),
            message: isFollowing ? 'Followed successfully' : 'Unfollowed successfully'
        });

    } catch (error) {
        console.error('Follow Error:', error);
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}
