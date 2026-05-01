-- Offer popularity: likes table + views counter
-- Run once against production database

-- Offer likes table
CREATE TABLE IF NOT EXISTS offer_likes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    offer_id UUID NOT NULL REFERENCES offers(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(offer_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_offer_likes_offer ON offer_likes(offer_id);
CREATE INDEX IF NOT EXISTS idx_offer_likes_user ON offer_likes(user_id);

-- Add view_count to offers for tracking
ALTER TABLE offers ADD COLUMN IF NOT EXISTS view_count INTEGER DEFAULT 0;
