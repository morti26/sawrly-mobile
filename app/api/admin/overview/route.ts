import { NextRequest, NextResponse } from 'next/server';
import { query } from '@/lib/db';
import { ADMIN_PANEL_ROLES, requireRole } from '@/lib/auth';
import { APP_SETTING_KEYS, getAppSetting } from '@/lib/app_settings';
import { ensureMediaReportsTable } from '@/lib/media-reports';
import { isPaymentApiKeyConfigured } from '@/lib/payment-key-crypto';

export async function GET(req: NextRequest) {
    const auth = requireRole(req, ADMIN_PANEL_ROLES);
    if (auth.error || !auth.user) {
        return NextResponse.json({ error: auth.error }, { status: auth.status });
    }

    try {
        await ensureMediaReportsTable();

        const [overviewRes, reportsRes, paymentApiKey, paymentProviderName] = await Promise.all([
            query(
                `
                    SELECT
                        (SELECT COUNT(*)::int FROM projects WHERE status = 'in_progress') AS active_projects,
                        (
                            SELECT COUNT(*)::int
                            FROM quotes q
                            WHERE NOT EXISTS (
                                SELECT 1 FROM projects p WHERE p.quote_id = q.id
                            )
                        ) AS pending_quotes,
                        (SELECT COUNT(*)::int FROM payments WHERE status = 'pending') AS pending_payments,
                        COALESCE(
                            (
                                SELECT SUM(amount)
                                FROM payments
                                WHERE status = 'confirmed'
                                  AND date_trunc('month', confirmed_at) = date_trunc('month', NOW())
                            ),
                            0
                        ) AS revenue_month
                `
            ),
            query(
                `
                    SELECT COUNT(*)::int AS open_reports
                    FROM media_reports
                    WHERE status IN ('pending', 'in_review')
                `
            ),
            getAppSetting(APP_SETTING_KEYS.paymentApiKey),
            getAppSetting(APP_SETTING_KEYS.paymentProviderName),
        ]);

        const row = overviewRes.rows[0];
        const openReports = reportsRes.rows[0]?.open_reports ?? 0;

        return NextResponse.json({
            activeProjects: Number(row?.active_projects ?? 0),
            pendingQuotes: Number(row?.pending_quotes ?? 0),
            pendingPayments: Number(row?.pending_payments ?? 0),
            revenueMonth: Number(row?.revenue_month ?? 0),
            openReports: Number(openReports),
            paymentApiConfigured: isPaymentApiKeyConfigured(paymentApiKey),
            paymentProviderName: paymentProviderName || null,
        });
    } catch (e) {
        console.error('Admin Overview Error:', e);
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}
