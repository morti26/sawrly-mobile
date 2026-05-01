import { query } from './db';

// Business Rules for Status Transitions

export const canStartProject = async (quoteId: string): Promise<boolean> => {
    // Rule: Project can only start if Payment is CONFIRMED (or overridden).
    // Check if there is a confirmed payment for this quote.
    const res = await query(
        `SELECT 1 FROM payments WHERE quote_id = $1 AND status = 'confirmed'`,
        [quoteId]
    );
    return res.rowCount !== null && res.rowCount > 0;
};

export const validateProjectTransition = (currentStatus: string, action: string): string | null => {
    // Returns new status or null if invalid
    const transitions: Record<string, Record<string, string>> = {
        'in_progress': {
            'complete': 'completed',
            'cancel': 'cancelled'
        },
        // Once completed or cancelled, it's terminal (mostly)
    };

    return transitions[currentStatus]?.[action] || null;
};

export const logAudit = async (
    entityType: string,
    entityId: string,
    eventType: string,
    actorId: string,
    metadata: any = {}
) => {
    await query(
        `INSERT INTO audit_logs (entity_type, entity_id, event_type, actor_id, metadata)
     VALUES ($1, $2, $3, $4, $5)`,
        [entityType, entityId, eventType, actorId, JSON.stringify(metadata)]
    );
};
