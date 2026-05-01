import type { Metadata } from "next";
import { Tajawal } from "next/font/google";
import "./globals.css";

const tajawal = Tajawal({
    subsets: ["arabic"],
    weight: ["200", "300", "400", "500", "700", "800", "900"]
});

export const metadata: Metadata = {
    title: "صورلي Admin",
    description: "Platform for photographers and filmmakers in Iraq",
};

export default function RootLayout({
    children,
}: Readonly<{
    children: React.ReactNode;
}>) {
    return (
        <html lang="ar" dir="rtl" translate="no">
            <head>
                <meta name="google" content="notranslate" />
            </head>
            <body className={tajawal.className}>{children}</body>
        </html>
    );
}
