import { NextRequest, NextResponse } from 'next/server';
import { query } from '@/lib/db';
import { ADMIN_PANEL_ROLES, requireRole } from '@/lib/auth';

const ALLOWED_ENTITY_TYPES = ['user', 'project', 'payment', 'quote', 'offer', 'delivery'] as const;
type AuditEntityType = (typeof ALLOWED_ENTITY_TYPES)[number];

export async function GET(req: NextRequest) {
    const auth = requireRole(req, ADMIN_PANEL_ROLES);
    if (auth.error || !auth.user) {
        return NextResponse.json({ error: auth.error }, { status: auth.status });
    }

    try {
        const entityType = req.nextUrl.searchParams.get('entityType')?.trim() as AuditEntityType | undefined;
        const search = req.nextUrl.searchParams.get('q')?.trim() || '';

        const params: any[] = [];
        const filters: string[] = [];

        if (entityType && ALLOWED_ENTITY_TYPES.includes(entityType)) {
            params.push(entityType);
            filters.push(`a.entity_type = $${params.length}`);
        }

        if (search) {
            params.push(`%${search}%`);
            filters.push(`
                (
                    a.event_type ILIKE $${params.length}
                    OR a.entity_id::text ILIKE $${params.length}
                    OR COALESCE(actor.name, '') ILIKE $${params.length}
                    OR COALESCE(actor.email, '') ILIKE $${params.length}
                    OR COALESCE(a.metadata::text, '') ILIKE $${params.length}
                    OR COALESCE(
                        offer.title,
                        quote_offer.title,
                        payment_offer.title,
                        project_offer.title,
                        delivery_offer.title,
                        target_user.name,
                        ''
                    ) ILIKE $${params.length}
                )
            `);
        }

        const where = filters.length ? `WHERE ${filters.join(' AND ')}` : '';

        const res = await query(
            `
                SELECT
                    a.id,
                    a.entity_type,
                    a.entity_id,
                    a.event_type,
                    a.actor_id,
                    actor.name AS actor_name,
                    actor.email AS actor_email,
                    a.metadata,
                    a.created_at,
                    COALESCE(
                        offer.title,
                        quote_offer.title,
                        payment_offer.title,
                        project_offer.title,
                        delivery_offer.title,
                        target_user.name
                    ) AS entity_title
                FROM audit_logs a
                LEFT JOIN users actor ON actor.id = a.actor_id
                LEFT JOIN offers offer
                    ON a.entity_type = 'offer'
                   AND offer.id = a.entity_id
                LEFT JOIN quotes quote_entity
                    ON a.entity_type = 'quote'
                   AND quote_entity.id = a.entity_id
                LEFT JOIN offers quote_offer
                    ON quote_offer.id = quote_entity.offer_id
                LEFT JOIN payments payment_entity
                    ON a.entity_type = 'payment'
                   AND payment_entity.id = a.entity_id
                LEFT JOIN quotes payment_quote
                    ON payment_quote.id = payment_entity.quote_id
                LEFT JOIN offers payment_offer
                    ON payment_offer.id = payment_quote.offer_id
                LEFT JOIN projects project_entity
                    ON a.entity_type = 'project'
                   AND project_entity.id = a.entity_id
                LEFT JOIN quotes project_quote
                    ON project_quote.id = project_entity.quote_id
                LEFT JOIN offers project_offer
                    ON project_offer.id = project_quote.offer_id
                LEFT JOIN deliveries delivery_entity
                    ON a.entity_type = 'delivery'
                   AND delivery_entity.id = a.entity_id
                LEFT JOIN projects delivery_project
                    ON delivery_project.id = delivery_entity.project_id
                LEFT JOIN quotes delivery_quote
                    ON delivery_quote.id = delivery_project.quote_id
                LEFT JOIN offers delivery_offer
                    ON delivery_offer.id = delivery_quote.offer_id
                LEFT JOIN users target_user
                    ON a.entity_type = 'user'
                   AND target_user.id = a.entity_id
                ${where}
                ORDER BY a.created_at DESC
                LIMIT 200
            `,
            params
        );

        return NextResponse.json(res.rows);
    } catch (e) {
        console.error('Admin Audit Logs GET Error:', e);
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}
