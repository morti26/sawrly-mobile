-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ENUMS --
CREATE TYPE user_role AS ENUM ('creator', 'client', 'admin', 'moderator');
CREATE TYPE media_type AS ENUM ('image', 'video');
CREATE TYPE offer_status AS ENUM ('active', 'inactive', 'archived');
CREATE TYPE quote_status AS ENUM ('accepted', 'locked'); -- "Quote is basically Offer acceptance + terms lock"
CREATE TYPE project_status AS ENUM ('in_progress', 'completed', 'cancelled');
CREATE TYPE payment_method AS ENUM ('cash', 'bank_transfer', 'wallet', 'online');
CREATE TYPE payment_status AS ENUM ('pending', 'confirmed', 'rejected');
CREATE TYPE delivery_status AS ENUM ('submitted', 'approved', 'rejected');
CREATE TYPE notification_type AS ENUM ('booking', 'payment', 'delivery', 'system');
CREATE TYPE audit_entity AS ENUM ('user', 'project', 'payment', 'quote', 'offer', 'delivery');

-- 1. USERS --
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    role user_role NOT NULL,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(50),
    password_hash VARCHAR(255) NOT NULL, -- Added for Auth
    frozen_until TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
CREATE INDEX idx_users_frozen_until ON users(frozen_until);

-- 2. CREATOR STATUS (STORIES) --
CREATE TABLE creator_status (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    creator_id UUID NOT NULL REFERENCES users(id),
    media_url TEXT NOT NULL,
    media_type media_type NOT NULL,
    caption TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL -- 24h logic handled in API/Query
);
CREATE INDEX idx_creator_status_expires ON creator_status(creator_id, expires_at);

-- 2.1 STORY LIKES --
CREATE TABLE creator_status_likes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    status_id UUID NOT NULL REFERENCES creator_status(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(status_id, user_id)
);
CREATE INDEX idx_creator_status_likes_status ON creator_status_likes(status_id);
CREATE INDEX idx_creator_status_likes_user ON creator_status_likes(user_id);

-- 3. CREATOR PRESENCE --
CREATE TABLE creator_presence (
    creator_id UUID PRIMARY KEY REFERENCES users(id),
    last_seen_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3.5 FOLLOWERS --
CREATE TABLE followers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    follower_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    following_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(follower_id, following_id)
);
CREATE INDEX idx_followers_follower ON followers(follower_id);
CREATE INDEX idx_followers_following ON followers(following_id);
COMMENT ON TABLE followers IS 'Tracks which users follow other creators or users.';

-- 4. OFFERS --
CREATE TABLE offers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    creator_id UUID NOT NULL REFERENCES users(id),
    title VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    price_iqd DECIMAL(12, 2) NOT NULL,
    discount_percent INTEGER NOT NULL DEFAULT 0 CHECK (discount_percent >= 0 AND discount_percent <= 100),
    original_price_iqd DECIMAL(12, 2),
    view_count INTEGER NOT NULL DEFAULT 0,
    status offer_status DEFAULT 'active',
    image_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
CREATE INDEX idx_offers_active ON offers(creator_id, status);
CREATE INDEX idx_offers_search ON offers(title); -- Simple search index

-- 5. QUOTES --
-- Created when Client selects an Offer. Locks terms.
CREATE TABLE quotes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    offer_id UUID NOT NULL REFERENCES offers(id),
    client_id UUID NOT NULL REFERENCES users(id),
    creator_id UUID NOT NULL REFERENCES users(id), -- Denormalized for query speed
    price_snapshot DECIMAL(12, 2) NOT NULL, -- Locked price
    status quote_status DEFAULT 'accepted',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 6. PAYMENTS --
-- Linked to Quote initially, as Project doesn't exist until Payment confirmed.
CREATE TABLE payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    quote_id UUID REFERENCES quotes(id), 
    project_id UUID, -- Nullable initially, populated after project creation
    amount DECIMAL(12, 2) NOT NULL,
    method payment_method NOT NULL,
    status payment_status DEFAULT 'pending',
    proof_url TEXT, -- Screenshot or note
    gateway_reference TEXT,
    gateway_checkout_url TEXT,
    gateway_status TEXT,
    gateway_payload JSONB,
    created_by UUID NOT NULL REFERENCES users(id), -- Client or Creator
    confirmed_by UUID REFERENCES users(id), -- Creator or Admin
    confirmed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
CREATE INDEX idx_payments_quote ON payments(quote_id);
CREATE INDEX idx_payments_gateway_reference ON payments(gateway_reference);

-- 7. PROJECTS --
-- Created ONLY after Payment Confirmed OR Override
CREATE TABLE projects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    quote_id UUID NOT NULL REFERENCES quotes(id),
    creator_id UUID NOT NULL REFERENCES users(id),
    client_id UUID NOT NULL REFERENCES users(id),
    status project_status DEFAULT 'in_progress',
    started_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
CREATE INDEX idx_projects_status ON projects(creator_id, client_id, status);

-- Link Payment to Project foreign key (circular dependency resolved by nullable)
ALTER TABLE payments ADD FOREIGN KEY (project_id) REFERENCES projects(id);

-- 8. DELIVERIES --
CREATE TABLE deliveries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID NOT NULL REFERENCES projects(id),
    delivery_url TEXT NOT NULL,
    status delivery_status DEFAULT 'submitted',
    submitted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    approved_at TIMESTAMP WITH TIME ZONE
);

-- 9. CANCELLATIONS --
CREATE TABLE cancellations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID NOT NULL REFERENCES projects(id),
    cancelled_by UUID NOT NULL REFERENCES users(id),
    reason TEXT NOT NULL,
    cancelled_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 10. NOTIFICATIONS --
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    type notification_type NOT NULL,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    payload JSONB,
    is_read BOOLEAN DEFAULT FALSE,
    read_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
CREATE INDEX idx_notifications_user ON notifications(user_id, is_read);

-- 11. AUDIT LOGS --
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_type audit_entity NOT NULL,
    entity_id UUID NOT NULL,
    event_type VARCHAR(50) NOT NULL, -- e.g. 'project_started', 'payment_confirmed'
    actor_id UUID NOT NULL REFERENCES users(id),
    metadata JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);


-- 12. MEDIA GALLERY --
CREATE TABLE media_gallery (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    creator_id UUID NOT NULL REFERENCES users(id),
    url TEXT NOT NULL,
    type media_type NOT NULL, -- 'image' or 'video'
    caption TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 12.1 MEDIA REPORTS --
CREATE TABLE media_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    media_id UUID REFERENCES media_gallery(id) ON DELETE SET NULL,
    reporter_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reason VARCHAR(120) NOT NULL,
    details TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'in_review', 'resolved', 'rejected')),
    admin_note TEXT,
    handled_by UUID REFERENCES users(id),
    handled_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(media_id, reporter_id)
);
CREATE INDEX idx_media_reports_status ON media_reports(status);
CREATE INDEX idx_media_reports_created_at ON media_reports(created_at DESC);
CREATE INDEX idx_media_reports_media_id ON media_reports(media_id);

-- 13. EVENTS --
CREATE TABLE events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    creator_id UUID NOT NULL REFERENCES users(id),
    title VARCHAR(255) NOT NULL,
    date_time TIMESTAMP WITH TIME ZONE NOT NULL,
    location VARCHAR(255),
    cover_image_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 14. SUPPORT MESSAGES --
CREATE TABLE support_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    sender_type VARCHAR(10) NOT NULL CHECK (sender_type IN ('user', 'admin')),
    content TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
CREATE INDEX idx_support_messages_user_time ON support_messages(user_id, created_at);

-- 15. OFFER LIKES --
CREATE TABLE offer_likes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    offer_id UUID NOT NULL REFERENCES offers(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(offer_id, user_id)
);
CREATE INDEX idx_offer_likes_offer ON offer_likes(offer_id);
CREATE INDEX idx_offer_likes_user ON offer_likes(user_id);

-- 16. APP CATEGORIES (STORE) --
CREATE TABLE app_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(255) NOT NULL,
    image_url TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
CREATE INDEX idx_app_categories_sort ON app_categories(sort_order, created_at DESC);

-- 17. BANNERS / ADS --
CREATE TABLE banners (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    image_url TEXT,
    link_url TEXT,
    title VARCHAR(255) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT FALSE,
    media_items JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
CREATE INDEX idx_banners_active ON banners(is_active, created_at DESC);

-- 18. APP SETTINGS --
CREATE TABLE app_settings (
    setting_key TEXT PRIMARY KEY,
    setting_value TEXT,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 19. SERVICE PACKAGES --
CREATE TABLE service_packages (
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
);
CREATE INDEX idx_service_packages_creator_active ON service_packages(creator_id, is_active);

-- 20. OPERATIONS ERROR LOGS --
CREATE TABLE ops_error_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source VARCHAR(120) NOT NULL,
    level VARCHAR(16) NOT NULL DEFAULT 'error'
        CHECK (level IN ('error', 'warn')),
    message TEXT NOT NULL,
    request_path TEXT,
    details JSONB,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_ops_error_logs_created_at ON ops_error_logs(created_at DESC);
CREATE INDEX idx_ops_error_logs_source ON ops_error_logs(source, created_at DESC);

-- Comments for documentation
COMMENT ON TABLE quotes IS 'Represents an accepted offer with locked price. Precursor to Project.';
COMMENT ON TABLE projects IS 'Active engagement. Created only after valid payment/override.';
