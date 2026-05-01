export enum UserRole {
    CREATOR = 'CREATOR',
    CLIENT = 'CLIENT'
}

export interface User {
    id: string;
    name: string;
    phone: string;
    email?: string;
    role: UserRole;
    createdAt: Date;
}
