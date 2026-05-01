import { query } from '@/lib/db';

let reportsTableEnsured = false;

export async function ensureMediaReportsTable() {
    if (reportsTableEnsured) return;

    try {
        await query('SELECT 1 FROM media_reports LIMIT 1');
        reportsTableEnsured = true;
        return;
    } catch (error: any) {
        if (error?.code !== '42P01') {
            throw error;
        }
    }

    await query(`
        CREATE TABLE IF NOT EXISTS media_reports (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            media_id UUID REFERENCES media_gallery(id) ON DELETE SET NULL,
            reporter_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            reason VARCHAR(120) NOT NULL,
            details TEXT,
            status VARCHAR(20) NOT NULL DEFAULT 'pending'
                CHECK (status IN ('pending', 'in_review', 'resolved', 'rejected')),
            admin_note TEXT,
            handled_by UUID REFERENCES users(id),
            handled_at TIMESTAMP WITH TIME ZONE,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            UNIQUE(media_id, reporter_id)
        )
    `);

    await query(`CREATE INDEX IF NOT EXISTS idx_media_reports_status ON media_reports(status)`);
    await query(`CREATE INDEX IF NOT EXISTS idx_media_reports_created_at ON media_reports(created_at DESC)`);
    await query(`CREATE INDEX IF NOT EXISTS idx_media_reports_media_id ON media_reports(media_id)`);

    reportsTableEnsured = true;
}
