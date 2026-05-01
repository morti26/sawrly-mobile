export type AuditEventType =
    | 'QUOTE_ACCEPTED'
    | 'PAYMENT_SUBMITTED'
    | 'PAYMENT_CONFIRMED'
    | 'PAYMENT_REJECTED'
    | 'SELLER_OVERRIDE_START'
    | 'PROJECT_CANCELLED'
    | 'STATUS_CHANGE'
    | 'DELIVERY_MARKED'
    | 'DELIVERY_APPROVED'
    | 'FEEDBACK_LEFT';

export interface AuditLogEntry {
    id: string;
    projectId: string;
    actorId: string; // User ID
    actorRole: 'CREATOR' | 'CLIENT' | 'SYSTEM';
    eventType: AuditEventType;
    timestamp: Date;
    metadata?: Record<string, any>; // e.g., { from: 'DRAFT', to: 'SENT' } or { amount: 500 }
    ipAddress?: string;
}
