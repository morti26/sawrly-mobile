import { NextResponse } from 'next/server';
import { APP_SETTING_KEYS, getAppSetting } from '@/lib/app_settings';

export const dynamic = 'force-dynamic';

export async function GET() {
    const adminWhatsApp = process.env.ADMIN_WHATSAPP_E164;
    let homeLogoUrl: string | null = null;

    try {
        homeLogoUrl = await getAppSetting(APP_SETTING_KEYS.homeLogoUrl);
    } catch (e) {
        // Keep this endpoint available even if settings storage fails.
        console.error('Public Config: failed to read home logo setting', e);
    }

    if (!adminWhatsApp) {
        console.warn('ADMIN_WHATSAPP_E164 is not set');
    }

    return NextResponse.json({
        adminWhatsAppE164: adminWhatsApp,
        homeLogoUrl,
    });
}
