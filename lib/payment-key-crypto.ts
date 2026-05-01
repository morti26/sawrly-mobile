import crypto from 'crypto';

const ENCRYPTED_KEY_PREFIX = 'enc:v1';

function getEncryptionKey(): Buffer | null {
    const secret = process.env.APP_SETTINGS_ENCRYPTION_KEY?.trim();
    if (!secret) {
        return null;
    }

    // Derive a stable 32-byte key regardless of secret string length.
    return crypto.createHash('sha256').update(secret, 'utf8').digest();
}

export function isPaymentApiKeyEncrypted(value: string | null): boolean {
    return Boolean(value?.startsWith(`${ENCRYPTED_KEY_PREFIX}:`));
}

export function decryptPaymentApiKey(storedValue: string): string {
    const normalizedValue = storedValue.trim();
    if (!normalizedValue) {
        return '';
    }

    if (!isPaymentApiKeyEncrypted(normalizedValue)) {
        return normalizedValue;
    }

    const encryptionKey = getEncryptionKey();
    if (!encryptionKey) {
        throw new Error('APP_SETTINGS_ENCRYPTION_KEY is required to read payment API key');
    }

    const parts = normalizedValue.split(':');
    if (parts.length !== 4 || parts[0] !== ENCRYPTED_KEY_PREFIX) {
        throw new Error('Invalid encrypted payment API key format');
    }

    const [, ivB64Url, authTagB64Url, cipherTextB64Url] = parts;

    const iv = Buffer.from(ivB64Url, 'base64url');
    const authTag = Buffer.from(authTagB64Url, 'base64url');
    const cipherText = Buffer.from(cipherTextB64Url, 'base64url');

    const decipher = crypto.createDecipheriv('aes-256-gcm', encryptionKey, iv);
    decipher.setAuthTag(authTag);

    const plainText = Buffer.concat([
        decipher.update(cipherText),
        decipher.final(),
    ]).toString('utf8');

    return plainText.trim();
}

export function encryptPaymentApiKey(plainTextValue: string): string {
    const encryptionKey = getEncryptionKey();
    if (!encryptionKey) {
        throw new Error('APP_SETTINGS_ENCRYPTION_KEY is required to store payment API key');
    }

    const iv = crypto.randomBytes(12);
    const cipher = crypto.createCipheriv('aes-256-gcm', encryptionKey, iv);
    const encrypted = Buffer.concat([
        cipher.update(plainTextValue, 'utf8'),
        cipher.final(),
    ]);
    const authTag = cipher.getAuthTag();

    return [
        ENCRYPTED_KEY_PREFIX,
        iv.toString('base64url'),
        authTag.toString('base64url'),
        encrypted.toString('base64url'),
    ].join(':');
}

export function maybeEncryptStoredPaymentApiKey(value: string | null): string | null {
    if (!value) {
        return null;
    }
    if (isPaymentApiKeyEncrypted(value)) {
        return value;
    }
    if (!getEncryptionKey()) {
        return value;
    }
    return encryptPaymentApiKey(value);
}

export function isPaymentApiKeyConfigured(value: string | null): boolean {
    if (!value) {
        return false;
    }
    if (isPaymentApiKeyEncrypted(value)) {
        return true;
    }
    return value.trim().length > 0;
}
