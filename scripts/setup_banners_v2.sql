-- Banner v2 migration: Add media_items for multi-slide + video support
-- Run this once against the production database

ALTER TABLE banners ADD COLUMN IF NOT EXISTS media_items JSONB DEFAULT '[]'::jsonb;

-- Back-fill existing banners: wrap their existing image_url as the first slide
UPDATE banners
SET media_items = json_build_array(
    json_build_object('url', image_url, 'type', 'image')
)::jsonb
WHERE media_items = '[]'::jsonb OR media_items IS NULL;
