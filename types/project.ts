import { ProjectStatus } from "../lib/statusMachine";

export interface Project {
    id: string;
    quoteId: string;
    clientId: string;
    creatorId: string;
    status: ProjectStatus;
    createdAt: Date;
    updatedAt: Date;
}
