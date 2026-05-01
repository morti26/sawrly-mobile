import { NextRequest, NextResponse } from 'next/server';
import { query } from '@/lib/db';
import { requireActiveCreator } from '@/lib/auth';

const PACKAGES_TABLE_SQL = `
    CREATE TABLE IF NOT EXISTS service_packages (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        creator_id UUID NOT NULL REFERENCES users(id),
        title VARCHAR(255) NOT NULL,
        description TEXT NOT NULL,
        price_iqd DECIMAL(12, 2) NOT NULL,
        delivery_time_days INTEGER NOT NULL DEFAULT 0,
        booking_fee_iqd DECIMAL(12, 2) NOT NULL DEFAULT 0,
        is_active BOOLEAN NOT NULL DEFAULT TRUE,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
`;

let packagesSchemaEnsured = false;
let packagesTableAvailable: boolean | null = null;
let packagesEnsurePromise: Promise<void> | null = null;

function isMissingRelationError(error: any): boolean {
    return error?.code === '42P01';
}

function isInsufficientPrivilegeError(error: any): boolean {
    return error?.code === '42501';
}

async function checkPackagesTable(): Promise<boolean> {
    try {
        await query(`
            SELECT id, creator_id, title, description, price_iqd, delivery_time_days, booking_fee_iqd, is_active, created_at
            FROM service_packages
            LIMIT 1
        `);
        return true;
    } catch (error: any) {
        if (isMissingRelationError(error)) {
            return false;
        }
        throw error;
    }
}

async function ensurePackagesTable() {
    if (packagesSchemaEnsured) {
        return;
    }

    if (!packagesEnsurePromise) {
        packagesEnsurePromise = (async () => {
            if (await checkPackagesTable()) {
                packagesTableAvailable = true;
                packagesSchemaEnsured = true;
                return;
            }

            try {
                await query(PACKAGES_TABLE_SQL);
                packagesTableAvailable = true;
            } catch (error: any) {
                if (!isInsufficientPrivilegeError(error)) {
                    throw error;
                }
                packagesTableAvailable = await checkPackagesTable();
            }

            packagesSchemaEnsured = true;
        })().finally(() => {
            packagesEnsurePromise = null;
        });
    }

    await packagesEnsurePromise;
}

export async function POST(request: NextRequest) {
    const auth = await requireActiveCreator(request);
    if (auth.error || !auth.user) {
        return NextResponse.json({ error: auth.error }, { status: auth.status });
    }

    try {
        await ensurePackagesTable();
        if (!packagesTableAvailable) {
            return NextResponse.json(
                { error: 'Packages feature is not available in the current database configuration' },
                { status: 503 }
            );
        }

        const body = await request.json();
        const title = (body?.title || '').toString().trim();
        const description = (body?.description || '').toString().trim();
        const price = Number(body?.price);
        const deliveryTime = Number(body?.deliveryTime ?? body?.delivery_time_days ?? 0);
        const bookingFee = Number(body?.bookingFee ?? body?.booking_fee_iqd ?? 0);

        if (!title || !description || Number.isNaN(price) || price < 0) {
            return NextResponse.json(
                { error: 'title, description and valid non-negative price are required' },
                { status: 400 }
            );
        }
        if (Number.isNaN(deliveryTime) || deliveryTime < 0 || Number.isNaN(bookingFee) || bookingFee < 0) {
            return NextResponse.json(
                { error: 'deliveryTime and bookingFee must be non-negative numbers' },
                { status: 400 }
            );
        }

        const res = await query(
            `
                INSERT INTO service_packages
                    (creator_id, title, description, price_iqd, delivery_time_days, booking_fee_iqd)
                VALUES ($1, $2, $3, $4, $5, $6)
                RETURNING id, creator_id, title, description, price_iqd, delivery_time_days, booking_fee_iqd, is_active, created_at
            `,
            [auth.user.userId, title, description, price, deliveryTime, bookingFee]
        );

        return NextResponse.json(res.rows[0], { status: 201 });
    } catch (e: any) {
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}

export async function GET(request: NextRequest) {
    try {
        await ensurePackagesTable();
        if (!packagesTableAvailable) {
            return NextResponse.json({ packages: [] });
        }

        const { searchParams } = new URL(request.url);
        const creatorId = searchParams.get('creatorId');
        const includeInactive = searchParams.get('includeInactive') === '1';

        let sql = `
            SELECT id, creator_id, title, description, price_iqd, delivery_time_days, booking_fee_iqd, is_active, created_at
            FROM service_packages
            WHERE 1=1
        `;
        const params: any[] = [];

        if (creatorId) {
            params.push(creatorId);
            sql += ` AND creator_id = $${params.length}`;
        }
        if (!includeInactive) {
            sql += ` AND is_active = TRUE`;
        }
        sql += ' ORDER BY created_at DESC';

        const res = await query(sql, params);
        return NextResponse.json({ packages: res.rows });
    } catch (e: any) {
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}
