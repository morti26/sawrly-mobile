import { query } from '@/lib/db';

let paymentSchemaEnsured = false;
let ensuringPromise: Promise<void> | null = null;
let paymentGatewayColumnsAvailable: boolean | null = null;

function isSchemaMissingError(error: any): boolean {
    return error?.code === '42P01' || error?.code === '42703';
}

function isInsufficientPrivilegeError(error: any): boolean {
    return error?.code === '42501';
}

async function isPaymentSchemaReady(): Promise<boolean> {
    try {
        await query(`
            SELECT gateway_reference, gateway_checkout_url, gateway_status, gateway_payload
            FROM payments
            LIMIT 1
        `);
        return true;
    } catch (error: any) {
        if (isSchemaMissingError(error)) {
            return false;
        }
        throw error;
    }
}

export async function hasPaymentGatewayColumns(): Promise<boolean> {
    if (paymentGatewayColumnsAvailable !== null) {
        return paymentGatewayColumnsAvailable;
    }

    paymentGatewayColumnsAvailable = await isPaymentSchemaReady();
    return paymentGatewayColumnsAvailable;
}

async function ensurePaymentSchemaInternal(): Promise<void> {
    await query(`
        ALTER TABLE payments
        ADD COLUMN IF NOT EXISTS gateway_reference TEXT
    `);
    await query(`
        ALTER TABLE payments
        ADD COLUMN IF NOT EXISTS gateway_checkout_url TEXT
    `);
    await query(`
        ALTER TABLE payments
        ADD COLUMN IF NOT EXISTS gateway_status TEXT
    `);
    await query(`
        ALTER TABLE payments
        ADD COLUMN IF NOT EXISTS gateway_payload JSONB
    `);
    await query(`
        CREATE INDEX IF NOT EXISTS idx_payments_gateway_reference
        ON payments(gateway_reference)
    `);
}

export async function ensurePaymentSchema(): Promise<void> {
    if (paymentSchemaEnsured) {
        return;
    }

    if (!ensuringPromise) {
        ensuringPromise = (async () => {
            if (await hasPaymentGatewayColumns()) {
                paymentSchemaEnsured = true;
                return;
            }

            try {
                await ensurePaymentSchemaInternal();
            } catch (error: any) {
                if (!isInsufficientPrivilegeError(error)) {
                    throw error;
                }

                // In hosted production we may not own legacy tables.
                // Keep manual-payment flows running even when online-gateway columns can't be auto-added.
                paymentGatewayColumnsAvailable = await isPaymentSchemaReady();
                if (!paymentGatewayColumnsAvailable) {
                    paymentSchemaEnsured = true;
                    return;
                }
            }

            paymentGatewayColumnsAvailable = true;
            paymentSchemaEnsured = true;
        })()
            .finally(() => {
                ensuringPromise = null;
            });
    }

    await ensuringPromise;
}
