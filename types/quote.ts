export interface Quote {
    id: string;
    packageId: string;
    price: number;
    currency: string;
    bookingFee: number;
    terms: string;
    expiresAt: Date;
}
