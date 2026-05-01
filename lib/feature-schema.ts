import { query } from '@/lib/db';

let offerSchemaEnsured = false;
let offerSchemaEnsuring: Promise<void> | null = null;
let categorySchemaEnsured = false;
let categorySchemaEnsuring: Promise<void> | null = null;
let bannerSchemaEnsured = false;
let bannerSchemaEnsuring: Promise<void> | null = null;

function isSchemaMissingError(error: any): boolean {
    return error?.code === '42P01' || error?.code === '42703';
}

function isInsufficientPrivilegeError(error: any): boolean {
    return error?.code === '42501';
}

async function isOfferSchemaReady(): Promise<boolean> {
    try {
        await query(`
            SELECT discount_percent, original_price_iqd, view_count
            FROM offers
            LIMIT 1
        `);
        await query(`
            SELECT offer_id, user_id
            FROM offer_likes
            LIMIT 1
        `);
        await query(`
            SELECT offer_id, url, type, sort_order
            FROM offer_media_items
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

async function isCategoriesSchemaReady(): Promise<boolean> {
    try {
        await query(`
            SELECT title, image_url, is_active, sort_order, created_at, updated_at
            FROM app_categories
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

async function isBannersSchemaReady(): Promise<boolean> {
    try {
        await query(`
            SELECT image_url, link_url, title, is_active, media_items, created_at, updated_at
            FROM banners
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

async function ensureOfferSchemaInternal(): Promise<void> {
    await query(`
        ALTER TABLE offers
        ADD COLUMN IF NOT EXISTS discount_percent INTEGER NOT NULL DEFAULT 0
    `);
    await query(`
        ALTER TABLE offers
        ADD COLUMN IF NOT EXISTS original_price_iqd DECIMAL(12, 2)
    `);
    await query(`
        ALTER TABLE offers
        ADD COLUMN IF NOT EXISTS view_count INTEGER NOT NULL DEFAULT 0
    `);
    await query(`
        CREATE TABLE IF NOT EXISTS offer_media_items (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            offer_id UUID NOT NULL REFERENCES offers(id) ON DELETE CASCADE,
            url TEXT NOT NULL,
            type TEXT NOT NULL CHECK (type IN ('image', 'video')),
            sort_order INTEGER NOT NULL DEFAULT 0,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        )
    `);
    await query(`
        CREATE INDEX IF NOT EXISTS idx_offer_media_items_offer
        ON offer_media_items(offer_id, sort_order)
    `);
    await query(`
        CREATE TABLE IF NOT EXISTS offer_likes (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            offer_id UUID NOT NULL REFERENCES offers(id) ON DELETE CASCADE,
            user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            UNIQUE(offer_id, user_id)
        )
    `);
    await query(`
        CREATE INDEX IF NOT EXISTS idx_offer_likes_offer
        ON offer_likes(offer_id)
    `);
    await query(`
        CREATE INDEX IF NOT EXISTS idx_offer_likes_user
        ON offer_likes(user_id)
    `);
}

async function ensureCategoriesSchemaInternal(): Promise<void> {
    await query(`
        CREATE TABLE IF NOT EXISTS app_categories (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            title VARCHAR(255) NOT NULL,
            image_url TEXT NOT NULL,
            is_active BOOLEAN NOT NULL DEFAULT TRUE,
            sort_order INTEGER NOT NULL DEFAULT 0,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        )
    `);
    await query(`
        CREATE INDEX IF NOT EXISTS idx_app_categories_sort
        ON app_categories(sort_order, created_at DESC)
    `);
}

async function ensureBannersSchemaInternal(): Promise<void> {
    await query(`
        CREATE TABLE IF NOT EXISTS banners (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            image_url TEXT,
            link_url TEXT,
            title VARCHAR(255),
            is_active BOOLEAN NOT NULL DEFAULT FALSE,
            media_items JSONB NOT NULL DEFAULT '[]'::jsonb,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        )
    `);
    await query(`ALTER TABLE banners ADD COLUMN IF NOT EXISTS image_url TEXT`);
    await query(`ALTER TABLE banners ADD COLUMN IF NOT EXISTS link_url TEXT`);
    await query(`ALTER TABLE banners ADD COLUMN IF NOT EXISTS title VARCHAR(255)`);
    await query(`ALTER TABLE banners ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT FALSE`);
    await query(`
        ALTER TABLE banners
        ADD COLUMN IF NOT EXISTS media_items JSONB NOT NULL DEFAULT '[]'::jsonb
    `);
    await query(`ALTER TABLE banners ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()`);
    await query(`ALTER TABLE banners ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()`);
    await query(`
        CREATE INDEX IF NOT EXISTS idx_banners_active
        ON banners(is_active, created_at DESC)
    `);
}

export async function ensureOfferSchema(): Promise<void> {
    if (offerSchemaEnsured) return;
    if (!offerSchemaEnsuring) {
        offerSchemaEnsuring = (async () => {
            if (await isOfferSchemaReady()) {
                offerSchemaEnsured = true;
                return;
            }

            try {
                await ensureOfferSchemaInternal();
            } catch (error: any) {
                if (!isInsufficientPrivilegeError(error)) {
                    throw error;
                }

                if (!(await isOfferSchemaReady())) {
                    throw error;
                }
            }

            offerSchemaEnsured = true;
        })()
            .finally(() => {
                offerSchemaEnsuring = null;
            });
    }
    await offerSchemaEnsuring;
}

export async function ensureCategoriesSchema(): Promise<void> {
    if (categorySchemaEnsured) return;
    if (!categorySchemaEnsuring) {
        categorySchemaEnsuring = (async () => {
            if (await isCategoriesSchemaReady()) {
                categorySchemaEnsured = true;
                return;
            }

            try {
                await ensureCategoriesSchemaInternal();
            } catch (error: any) {
                if (!isInsufficientPrivilegeError(error)) {
                    throw error;
                }

                if (!(await isCategoriesSchemaReady())) {
                    throw error;
                }
            }

            categorySchemaEnsured = true;
        })()
            .finally(() => {
                categorySchemaEnsuring = null;
            });
    }
    await categorySchemaEnsuring;
}

export async function ensureBannersSchema(): Promise<void> {
    if (bannerSchemaEnsured) return;
    if (!bannerSchemaEnsuring) {
        bannerSchemaEnsuring = (async () => {
            if (await isBannersSchemaReady()) {
                bannerSchemaEnsured = true;
                return;
            }

            try {
                await ensureBannersSchemaInternal();
            } catch (error: any) {
                if (!isInsufficientPrivilegeError(error)) {
                    throw error;
                }

                if (!(await isBannersSchemaReady())) {
                    throw error;
                }
            }

            bannerSchemaEnsured = true;
        })()
            .finally(() => {
                bannerSchemaEnsuring = null;
            });
    }
    await bannerSchemaEnsuring;
}
