export type ProjectStatus =
    | 'DRAFT'
    | 'SENT'
    | 'ACCEPTED'
    | 'BOOKED'
    | 'IN_PROGRESS'
    | 'DELIVERED'
    | 'APPROVED'
    | 'COMPLETED'
    | 'CANCELLED';

export const VALID_TRANSITIONS: Record<ProjectStatus, ProjectStatus[]> = {
    DRAFT: ['SENT', 'CANCELLED'],
    SENT: ['ACCEPTED', 'DRAFT', 'CANCELLED'],
    ACCEPTED: ['BOOKED', 'CANCELLED'],     // Action: Client pays booking fee OR Seller overrides
    BOOKED: ['IN_PROGRESS', 'CANCELLED'],  // Action: Seller starts work
    IN_PROGRESS: ['DELIVERED', 'CANCELLED'], // Action: Seller delivers logic
    DELIVERED: ['APPROVED', 'IN_PROGRESS'], // Action: Client approves OR requests revision (back to InProgress)
    APPROVED: ['COMPLETED'],               // Action: Final settlement
    COMPLETED: [],                         // End state
    CANCELLED: []                          // End state
};

export interface TransitionContext {
    role: 'CREATOR' | 'CLIENT';
    paymentStatus?: 'PENDING' | 'CONFIRMED' | 'REJECTED';
    bookingFeeRequired?: boolean;
    sellerOverride?: boolean;
}

export function validateTransition(
    current: ProjectStatus,
    next: ProjectStatus,
    context: TransitionContext
): { valid: boolean; error?: string } {

    // 1. Check if transition path exists
    const allowedNext = VALID_TRANSITIONS[current];
    if (!allowedNext || !allowedNext.includes(next)) {
        return { valid: false, error: `Invalid transition from ${current} to ${next}` };
    }

    // 2. Cancellation Rules
    if (next === 'CANCELLED') {
        if (['COMPLETED', 'CANCELLED'].includes(current)) {
            return { valid: false, error: "Cannot cancel a finished project" };
        }
        return { valid: true };
    }

    // 3. Status-Specific Gates
    switch (current) {
        case 'ACCEPTED':
            // ACCEPTED -> BOOKED
            // Requires Payment Confirmed OR Seller Override
            if (next === 'BOOKED') {
                if (context.sellerOverride) {
                    return { valid: true };
                }
                if (context.bookingFeeRequired && context.paymentStatus !== 'CONFIRMED') {
                    return { valid: false, error: "Booking fee payment required before booking can be confirmed." };
                }
            }
            break;

        case 'BOOKED':
            // BOOKED -> IN_PROGRESS
            // Usually just a manual trigger by Creator, but ensure they are the Creator
            if (next === 'IN_PROGRESS' && context.role !== 'CREATOR') {
                return { valid: false, error: "Only Creator can start the project." };
            }
            break;

        case 'DELIVERED':
            // DELIVERED -> APPROVED (Client only)
            if (next === 'APPROVED' && context.role !== 'CLIENT') {
                return { valid: false, error: "Only Client can approve delivery." };
            }
            // DELIVERED -> IN_PROGRESS (Revision)
            if (next === 'IN_PROGRESS' && context.role !== 'CLIENT') {
                return { valid: false, error: "Only Client can request revisions (move back to In Progress)." };
            }
            break;
    }

    return { valid: true };
}
