"use client";

import { useEffect, useMemo, useState } from "react";

type BannerSlide = {
    url: string;
    type?: "image" | "video";
    title?: string;
};

type BannersResponse = {
    slides?: BannerSlide[];
};

const fallbackSlides: BannerSlide[] = [
    { url: "", title: "placeholder-1" },
    { url: "", title: "placeholder-2" },
    { url: "", title: "placeholder-3" },
];

function normalizeSlides(data: BannersResponse | null): BannerSlide[] {
    if (!data?.slides || !Array.isArray(data.slides)) return [];

    return data.slides
        .filter((slide): slide is BannerSlide => Boolean(slide?.url))
        .filter((slide) => (slide.type ?? "image") === "image")
        .slice(0, 12);
}

export function LandingPreviewSlider() {
    const [slides, setSlides] = useState<BannerSlide[]>([]);
    const [activeIndex, setActiveIndex] = useState(0);

    useEffect(() => {
        let cancelled = false;

        async function loadSlides() {
            try {
                const response = await fetch(`/api/banners?homePreview=${Date.now()}`, {
                    cache: "no-store",
                });
                if (!response.ok) return;

                const data = (await response.json()) as BannersResponse | null;
                if (!cancelled) {
                    setSlides(normalizeSlides(data));
                }
            } catch {
                if (!cancelled) {
                    setSlides([]);
                }
            }
        }

        loadSlides();

        return () => {
            cancelled = true;
        };
    }, []);

    const visibleSlides = useMemo(() => (slides.length > 0 ? slides : fallbackSlides), [slides]);
    const hasImages = slides.length > 0;

    useEffect(() => {
        if (visibleSlides.length < 2) return;

        const timer = window.setInterval(() => {
            setActiveIndex((current) => (current + 1) % visibleSlides.length);
        }, 3600);

        return () => window.clearInterval(timer);
    }, [visibleSlides.length]);

    return (
        <div
            aria-hidden="true"
            className="mx-auto grid aspect-[4/3] w-full max-w-[38rem] grid-rows-3 overflow-hidden rounded-[2rem] border border-white/10 bg-[#151923]/80 shadow-[0_18px_65px_rgba(255,86,170,0.16),inset_0_1px_0_rgba(255,255,255,0.08)] backdrop-blur"
        >
            {[0, 1, 2].map((row) => {
                const rowIndex = (activeIndex + row) % visibleSlides.length;

                return (
                    <div
                        key={row}
                        className="relative min-h-0 overflow-hidden border-white/10 first:border-t-0 [&:not(:first-child)]:border-t"
                    >
                        {visibleSlides.map((slide, index) => {
                            const isActive = index === rowIndex;

                            if (!slide.url) {
                                return (
                                    <div
                                        key={`${row}-${index}`}
                                        className={`absolute inset-0 bg-[radial-gradient(circle_at_20%_20%,rgba(255,86,170,0.14),rgba(255,255,255,0)_45%),linear-gradient(135deg,rgba(255,255,255,0.08),rgba(255,255,255,0.01))] transition-opacity duration-700 ${isActive ? "opacity-100" : "opacity-0"}`}
                                    />
                                );
                            }

                            return (
                                <img
                                    key={`${row}-${slide.url}-${index}`}
                                    src={slide.url}
                                    alt=""
                                    className={`absolute inset-0 h-full w-full object-cover transition-all duration-700 ease-out ${isActive ? "translate-x-0 scale-100 opacity-100" : row % 2 === 0 ? "-translate-x-6 scale-105 opacity-0" : "translate-x-6 scale-105 opacity-0"}`}
                                    loading={row === 0 ? "eager" : "lazy"}
                                />
                            );
                        })}

                        <div className="pointer-events-none absolute inset-0 bg-gradient-to-l from-black/18 via-transparent to-black/28" />
                        {!hasImages && <div className="absolute inset-x-6 top-1/2 h-px -translate-y-1/2 bg-white/10" />}
                    </div>
                );
            })}
        </div>
    );
}
