-- Create banners table
CREATE TABLE IF NOT EXISTS banners (
    id SERIAL PRIMARY KEY,
    image_url TEXT NOT NULL,
    link_url TEXT,
    title VARCHAR(255),
    is_active BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Insert a default active banner if the table is empty
INSERT INTO banners (image_url, title, is_active)
SELECT 'https://picsum.photos/600/300?blur=2', 'Special Announcement / Ad Space', true
WHERE NOT EXISTS (SELECT 1 FROM banners);
