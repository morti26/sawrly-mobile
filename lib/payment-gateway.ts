import { PaymentGatewayCredentials } from '@/lib/payment-runtime';

export class PaymentGatewayError extends Error {
    constructor(message: string) {
        super(message);
        this.name = 'PaymentGatewayError';
    }
}

export interface GatewayCheckoutInput {
    paymentId: string;
    quoteId: string;
    offerId: string;
    creatorId: string;
    clientId: string;
    amountIqd: number;
}

export interface GatewayCheckoutResult {
    checkoutUrl: string;
    gatewayReference: string | null;
    gatewayPayload: unknown;
}

function normalizeBaseUrl(value: string): string {
    return value.trim().replace(/\/+$/, '');
}

function buildCheckoutEndpoint(baseUrl: string): string {
    return `${normalizeBaseUrl(baseUrl)}/checkout`;
}

function readAtPath(payload: unknown, path: string[]): string | null {
    let cursor: unknown = payload;
    for (const segment of path) {
        if (!cursor || typeof cursor !== 'object' || !(segment in (cursor as Record<string, unknown>))) {
            return null;
        }
        cursor = (cursor as Record<string, unknown>)[segment];
    }
    return typeof cursor === 'string' && cursor.trim().length > 0 ? cursor.trim() : null;
}

function pickFirstString(payload: unknown, paths: string[][]): string | null {
    for (const path of paths) {
        const value = readAtPath(payload, path);
        if (value) return value;
    }
    return null;
}

function extractCheckoutUrl(payload: unknown): string | null {
    return pickFirstString(payload, [
        ['checkoutUrl'],
        ['checkout_url'],
        ['paymentUrl'],
        ['payment_url'],
        ['redirectUrl'],
        ['redirect_url'],
        ['url'],
        ['data', 'checkoutUrl'],
        ['data', 'checkout_url'],
        ['data', 'paymentUrl'],
        ['data', 'payment_url'],
        ['data', 'redirectUrl'],
        ['data', 'redirect_url'],
        ['data', 'url'],
        ['result', 'checkoutUrl'],
        ['result', 'checkout_url'],
        ['result', 'paymentUrl'],
        ['result', 'payment_url'],
        ['result', 'url'],
    ]);
}

function extractGatewayReference(payload: unknown): string | null {
    return pickFirstString(payload, [
        ['gatewayReference'],
        ['gateway_reference'],
        ['transactionId'],
        ['transaction_id'],
        ['paymentId'],
        ['payment_id'],
        ['reference'],
        ['id'],
        ['data', 'gatewayReference'],
        ['data', 'gateway_reference'],
        ['data', 'transactionId'],
        ['data', 'transaction_id'],
        ['data', 'paymentId'],
        ['data', 'payment_id'],
        ['data', 'reference'],
        ['data', 'id'],
        ['result', 'transactionId'],
        ['result', 'transaction_id'],
        ['result', 'paymentId'],
        ['result', 'payment_id'],
        ['result', 'reference'],
        ['result', 'id'],
    ]);
}

function extractGatewayErrorMessage(payload: unknown): string | null {
    return pickFirstString(payload, [
        ['error'],
        ['message'],
        ['error_message'],
        ['data', 'error'],
        ['data', 'message'],
        ['result', 'error'],
        ['result', 'message'],
    ]);
}

export async function createGatewayCheckout(
    credentials: PaymentGatewayCredentials,
    input: GatewayCheckoutInput
): Promise<GatewayCheckoutResult> {
    const endpoint = buildCheckoutEndpoint(credentials.paymentApiBaseUrl);
    const returnBaseUrl = (process.env.NEXT_PUBLIC_APP_URL || '').trim().replace(/\/+$/, '');
    const returnUrl = returnBaseUrl
        ? `${returnBaseUrl}/orders?paymentId=${encodeURIComponent(input.paymentId)}`
        : undefined;

    const requestPayload = {
        amount: input.amountIqd,
        amount_iqd: input.amountIqd,
        currency: 'IQD',
        paymentId: input.paymentId,
        quoteId: input.quoteId,
        offerId: input.offerId,
        creatorId: input.creatorId,
        clientId: input.clientId,
        metadata: {
            source: 'fotgraf-web',
            paymentId: input.paymentId,
            quoteId: input.quoteId,
            offerId: input.offerId,
            creatorId: input.creatorId,
            clientId: input.clientId,
        },
        returnUrl,
    };

    const abortController = new AbortController();
    const timeout = setTimeout(() => abortController.abort(), 20_000);

    try {
        const response = await fetch(endpoint, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                Authorization: `Bearer ${credentials.paymentApiKey}`,
                'X-Payment-Provider': credentials.paymentProviderName,
            },
            body: JSON.stringify(requestPayload),
            signal: abortController.signal,
        });

        const responseBody = await response.json().catch(() => null);

        if (!response.ok) {
            const gatewayMessage = extractGatewayErrorMessage(responseBody);
            throw new PaymentGatewayError(
                gatewayMessage || `Gateway checkout failed with status ${response.status}`
            );
        }

        const checkoutUrl = extractCheckoutUrl(responseBody);
        if (!checkoutUrl) {
            throw new PaymentGatewayError('Gateway response did not include a checkout URL');
        }

        return {
            checkoutUrl,
            gatewayReference: extractGatewayReference(responseBody),
            gatewayPayload: responseBody,
        };
    } catch (error) {
        if (error instanceof PaymentGatewayError) {
            throw error;
        }

        if (error instanceof Error && error.name === 'AbortError') {
            throw new PaymentGatewayError('Gateway checkout request timed out');
        }

        throw new PaymentGatewayError('Unable to create gateway checkout session');
    } finally {
        clearTimeout(timeout);
    }
}
