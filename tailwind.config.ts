import type { Config } from "tailwindcss";

const config: Config = {
    content: [
        "./pages/**/*.{js,ts,jsx,tsx,mdx}",
        "./components/**/*.{js,ts,jsx,tsx,mdx}",
        "./app/**/*.{js,ts,jsx,tsx,mdx}",
    ],
    theme: {
        extend: {
            backgroundImage: {
                "gradient-radial": "radial-gradient(var(--tw-gradient-stops))",
                "gradient-conic":
                    "conic-gradient(from 180deg at 50% 50%, var(--tw-gradient-stops))",
            },
            // Design tokens - Colors
            colors: {
                primary: {
                    DEFAULT: "#7A3EED",
                    light: "#9B6AFF",
                    dark: "#5A2EAD",
                },
                background: {
                    DEFAULT: "#161921",
                    light: "#1E2028",
                },
                surface: {
                    DEFAULT: "#222530",
                    light: "#2D3140",
                },
                text: {
                    primary: "#FFFFFF",
                    secondary: "#B0B0B0",
                    tertiary: "#707070",
                },
                status: {
                    success: "#22C55E",
                    warning: "#F59E0B",
                    error: "#EF4444",
                    info: "#3B82F6",
                },
                border: {
                    DEFAULT: "#3D3D4D",
                    light: "#2D2D3D",
                },
            },
            // Design tokens - Typography
            fontFamily: {
                tajawal: ["Tajawal", "sans-serif"],
            },
            fontSize: {
                h1: ["32px", { lineHeight: "1.2", fontWeight: "700" }],
                h2: ["24px", { lineHeight: "1.3", fontWeight: "700" }],
                h3: ["20px", { lineHeight: "1.3", fontWeight: "600" }],
                h4: ["18px", { lineHeight: "1.4", fontWeight: "600" }],
                body: ["14px", { lineHeight: "1.5", fontWeight: "400" }],
                bodyLarge: ["16px", { lineHeight: "1.5", fontWeight: "400" }],
                label: ["14px", { lineHeight: "1.4", fontWeight: "500" }],
                caption: ["11px", { lineHeight: "1.3", fontWeight: "400" }],
            },
            // Design tokens - Spacing
            spacing: {
                xs: "4px",
                sm: "8px",
                md: "12px",
                lg: "16px",
                xl: "20px",
                xxl: "24px",
                xxxl: "32px",
            },
            // Design tokens - Border radius
            borderRadius: {
                sm: "8px",
                md: "12px",
                lg: "16px",
                xl: "24px",
            },
            // Design tokens - Shadows
            boxShadow: {
                card: "0 2px 8px rgba(0, 0, 0, 0.2)",
                button: "0 2px 8px rgba(122, 62, 237, 0.3)",
                modal: "0 4px 16px rgba(0, 0, 0, 0.4)",
            },
        },
    },
    plugins: [],
};
export default config;
