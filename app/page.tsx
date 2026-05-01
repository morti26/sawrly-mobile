import Link from 'next/link';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

export default function Home() {
    return (
        <main id="home" dir="rtl" className="relative min-h-screen overflow-hidden bg-[#151923] px-6 py-8 text-white">
            <div
                className="pointer-events-none absolute inset-0"
                style={{
                    backgroundImage:
                        'radial-gradient(circle at 72% 14%, rgba(255, 86, 170, 0.48), rgba(255, 86, 170, 0.18) 18%, rgba(255, 86, 170, 0.06) 34%, rgba(21, 25, 35, 0) 55%), radial-gradient(circle at 18% 30%, rgba(54, 69, 114, 0.42), rgba(54, 69, 114, 0) 44%), linear-gradient(135deg, #151923 0%, #121722 38%, rgba(76, 9, 28, 0.46) 63%, #151923 100%)',
                }}
            />
            <div
                className="pointer-events-none absolute inset-0 opacity-70"
                style={{
                    backgroundImage:
                        'radial-gradient(circle at 70% 15%, rgba(255, 232, 247, 0.88) 0 1px, transparent 2px), radial-gradient(circle at 76% 20%, rgba(255, 154, 205, 0.64) 0 1px, transparent 2px), radial-gradient(circle at 64% 23%, rgba(255, 216, 238, 0.52) 0 1px, transparent 2px), linear-gradient(120deg, rgba(255,255,255,0.06), rgba(255,255,255,0) 26%, rgba(255,86,170,0.14))',
                }}
            />
            <div className="pointer-events-none absolute inset-x-0 bottom-0 h-56 bg-gradient-to-t from-black/45 via-black/0 to-black/0" />

            <div className="relative mx-auto w-full max-w-7xl">
                <header className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
                    <nav className="flex w-fit items-center gap-2 rounded-full border border-white/10 bg-black/20 p-1 text-sm font-bold text-white/75 shadow-[0_12px_35px_rgba(0,0,0,0.22)] backdrop-blur">
                        <Link href="#home" className="rounded-full bg-white/10 px-4 py-2 text-white shadow-[0_8px_24px_rgba(255,74,151,0.18)] hover:bg-white/[0.15]">
                            الرئيسية
                        </Link>
                        <Link href="#about" className="rounded-full px-4 py-2 hover:bg-white/10 hover:text-white">
                            من نحن
                        </Link>
                    </nav>

                    <div className="rounded-full border border-white/10 bg-white/10 px-4 py-1.5 text-xs font-semibold text-white/80 shadow-[0_10px_35px_rgba(255,74,151,0.16)] backdrop-blur">
                        Mobile Experience صورلي
                    </div>
                </header>

                <section dir="ltr" className="mt-10 grid grid-cols-1 items-center gap-10 lg:grid-cols-[1.15fr_0.85fr]">
                    <div dir="rtl" className="relative">
                        <div
                            aria-hidden="true"
                            className="mx-auto aspect-[4/3] w-full max-w-[38rem] rounded-[2rem] border border-white/10 bg-[#151923]/80 shadow-[0_18px_65px_rgba(255,86,170,0.16),inset_0_1px_0_rgba(255,255,255,0.08)] backdrop-blur"
                        />
                    </div>

                    <div dir="rtl" className="flex flex-col gap-6">
                        <h1 className="text-4xl font-extrabold leading-tight tracking-tight sm:text-5xl">
                            حمّل تطبيق
                            <br />
                            صورلي
                            <br />
                            للعملاء
                        </h1>

                        <p className="max-w-xl text-sm leading-6 text-white/70">
                            احجز المصور المناسب، تصفح العروض، وتابع طلباتك من
                            iPhone و Android بنفس الوان الواجهة والهوية الموجودة داخل التطبيق.
                        </p>

                        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
                            <div className="rounded-3xl border border-white/10 bg-white/[0.07] p-4 shadow-sm backdrop-blur">
                                <div className="flex items-start justify-between gap-3">
                                    <div className="grid h-10 w-10 place-items-center rounded-2xl border border-white/10 bg-black/25 text-xs font-bold">
                                        iOS
                                    </div>
                                    <div className="text-left">
                                        <div className="text-[10px] font-semibold tracking-[0.18em] text-white/50">APP STORE</div>
                                        <div className="mt-1 text-lg font-extrabold">iPhone</div>
                                        <div className="mt-1 text-xs text-white/60">رابط مباشر لمستخدمي iPhone و iPad</div>
                                    </div>
                                </div>

                                <div className="mt-4 flex items-center justify-between">
                                    <div className="text-xs text-white/60">قريباً</div>
                                    <div className="rounded-2xl border border-white/10 bg-black/25 px-4 py-2 text-xs font-semibold text-white/80">
                                        App store
                                    </div>
                                </div>
                            </div>

                            <div className="rounded-3xl border border-white/10 bg-white/[0.07] p-4 shadow-sm backdrop-blur">
                                <div className="flex items-start justify-between gap-3">
                                    <div className="grid h-10 w-10 place-items-center rounded-2xl border border-white/10 bg-black/25 text-xs font-bold">
                                        A
                                    </div>
                                    <div className="text-left">
                                        <div className="text-[10px] font-semibold tracking-[0.18em] text-white/50">GOOGLE PLAY</div>
                                        <div className="mt-1 text-lg font-extrabold">Android</div>
                                        <div className="mt-1 text-xs text-white/60">تحميل سريع لمستخدمي Android</div>
                                    </div>
                                </div>

                                <div className="mt-4 flex items-center justify-between">
                                    <div className="text-xs text-white/60">قريباً</div>
                                    <div className="rounded-2xl border border-white/10 bg-black/25 px-4 py-2 text-xs font-semibold text-white/80">
                                        Google play
                                    </div>
                                </div>
                            </div>
                        </div>

                        <div className="flex flex-col items-start gap-3 sm:flex-row sm:items-center">
                            <Link
                                href="#about"
                                className="rounded-full bg-[#ff4a97] px-6 py-2.5 text-sm font-extrabold text-white shadow-[0_8px_28px_rgba(255,74,151,0.35)] hover:bg-[#ff4a97]/90"
                            >
                                من نحن
                            </Link>

                            <div className="rounded-full border border-white/10 bg-white/[0.07] px-5 py-2 text-xs font-semibold text-white/70 backdrop-blur" dir="ltr">
                                واجهة العملاء منفصلة عن لوحة الإدارة
                            </div>
                        </div>
                    </div>
                </section>

                <section id="about" className="mt-10 grid grid-cols-1 gap-4 scroll-mt-10 md:grid-cols-3">
                    <div className="rounded-3xl border border-white/10 bg-white/[0.07] p-5 shadow-sm backdrop-blur">
                        <div className="text-sm font-extrabold">من نحن</div>
                        <div className="mt-2 text-xs leading-5 text-white/70">
                            صورلي منصة تجمع العملاء مع المصورين وصناع الفيديو بطريقة سهلة وسريعة داخل العراق.
                        </div>
                    </div>
                    <div className="rounded-3xl border border-white/10 bg-white/[0.07] p-5 shadow-sm backdrop-blur">
                        <div className="text-sm font-extrabold">تجربة للعملاء</div>
                        <div className="mt-2 text-xs leading-5 text-white/70">
                            الصفحة الرئيسية مخصصة للزبائن: تحميل التطبيق، تصفح الخدمة، والوصول السريع للمعلومات المهمة.
                        </div>
                    </div>
                    <div className="rounded-3xl border border-white/10 bg-white/[0.07] p-5 shadow-sm backdrop-blur">
                        <div className="text-sm font-extrabold">تصميم قريب من التطبيق</div>
                        <div className="mt-2 text-xs leading-5 text-white/70">
                            نفس الإحساس الداكن والواجهات اللامعة، مع لون وردي يعطي الصفحة طابعاً أنيقاً وحديثاً.
                        </div>
                    </div>
                </section>

                <footer className="mt-10 flex flex-col items-center justify-between gap-3 border-t border-white/10 pt-6 text-xs text-white/60 sm:flex-row">
                    <div className="flex items-center gap-4">
                        <Link href="#" className="hover:text-white/80">
                            شروط الاستخدام
                        </Link>
                        <Link href="#" className="hover:text-white/80">
                            سياسة الخصوصية
                        </Link>
                        <Link href="#" className="hover:text-white/80">
                            اتصل بنا
                        </Link>
                    </div>
                    <div className="text-white/40" dir="ltr">
                        Sawrly.com
                    </div>
                </footer>
            </div>
        </main>
    );
}
