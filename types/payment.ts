export enum PaymentStatus {
    PENDING = 'PENDING',
    VERIFIED = 'VERIFIED',
    REJECTED = 'REJECTED'
}

export interface Payment {
    id: string;
    projectId: string;
    amount: number;
    evidenceUrl: string; // URL to uploaded receipt
    status: PaymentStatus;
    verifiedAt?: Date;
}
