import { query } from '@/lib/db';

let likesTableEnsured = false;
let likesTableAvailable: boolean | null = null;
let likesEnsurePromise: Promise<void> | null = null;

function isMissingRelationError(error: any): boolean {
    return error?.code === '42P01';
}

function isInsufficientPrivilegeError(error: any): boolean {
    return error?.code === '42501';
}

export async function ensureStatusLikesTable() {
    if (likesTableEnsured) {
        return;
    }

    if (!likesEnsurePromise) {
        likesEnsurePromise = (async () => {
            try {
                await query('SELECT 1 FROM creator_status_likes LIMIT 1');
                likesTableAvailable = true;
                likesTableEnsured = true;
                return;
            } catch (error: any) {
                if (!isMissingRelationError(error)) {
                    throw error;
                }
            }

            try {
                await query(`
                    CREATE TABLE IF NOT EXISTS creator_status_likes (
                        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                        status_id UUID NOT NULL REFERENCES creator_status(id) ON DELETE CASCADE,
                        user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                        UNIQUE(status_id, user_id)
                    )
                `);
                await query(`CREATE INDEX IF NOT EXISTS idx_creator_status_likes_status ON creator_status_likes(status_id)`);
                await query(`CREATE INDEX IF NOT EXISTS idx_creator_status_likes_user ON creator_status_likes(user_id)`);
                likesTableAvailable = true;
            } catch (error: any) {
                if (!isInsufficientPrivilegeError(error)) {
                    throw error;
                }
                likesTableAvailable = false;
            }

            likesTableEnsured = true;
        })().finally(() => {
            likesEnsurePromise = null;
        });
    }

    await likesEnsurePromise;
}

export async function hasStatusLikesTable() {
    if (!likesTableEnsured) {
        await ensureStatusLikesTable();
    }
    return Boolean(likesTableAvailable);
}

export async function getStatusLikeStats(statusId: string, userId?: string | null) {
    if (!(await hasStatusLikesTable())) {
        return {
            like_count: 0,
            liked_by_me: false,
        };
    }

    const res = await query(
        `
            SELECT
                COUNT(*)::int AS like_count,
                EXISTS(
                    SELECT 1
                    FROM creator_status_likes sl2
                    WHERE sl2.status_id = $1
                      AND sl2.user_id = $2::uuid
                ) AS liked_by_me
            FROM creator_status_likes sl
            WHERE sl.status_id = $1
        `,
        [statusId, userId ?? null]
    );

    const row = res.rows[0] || {};
    return {
        like_count: Number(row.like_count || 0),
        liked_by_me: row.liked_by_me === true,
    };
}
