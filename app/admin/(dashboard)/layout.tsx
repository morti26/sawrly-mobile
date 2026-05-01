"use client";

import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';

export default function AdminLayout({
    children,
}: {
    children: React.ReactNode;
}) {
    const pathname = usePathname();
    const router = useRouter();

    const navItems = [
        { label: 'لوحة القيادة', href: '/admin/dashboard' },
        { label: 'المستخدمون', href: '/admin/users' },
        { label: 'المبدعون', href: '/admin/creators' },
        { label: 'العروض', href: '/admin/offers' },
        { label: 'المشاريع', href: '/admin/projects' },
        { label: 'المدفوعات', href: '/admin/payments' },
        { label: 'الإشعارات', href: '/admin/notifications' }, // Notifications
        { label: 'البلاغات', href: '/admin/reports' },
        { label: 'سجل التدقيق', href: '/admin/audit-logs' },
        { label: 'سجل الأخطاء', href: '/admin/ops-errors' },
        { label: 'الدعم', href: '/admin/support' }, // Support Chat
        { label: 'الإعلانات', href: '/admin/banners' }, // Banners / Ads
        { label: 'المتجر', href: '/admin/categories' }, // Store
        { label: 'الإعدادات', href: '/admin/settings' },
        { label: 'جاهزية الإطلاق', href: '/admin/readiness' },
    ];

    const handleLogout = () => {
        document.cookie = 'admin_token=; path=/; max-age=0';
        localStorage.removeItem('token');
        router.push('/admin/login');
    };

    return (
        <div dir="rtl" className="flex h-screen flex-row bg-gray-50 text-gray-900">
            {/* Sidebar */}
            <aside className="w-64 bg-slate-900 shadow-2xl flex flex-col relative z-20">
                <div className="px-6 py-8 border-b border-slate-800 mb-4 flex items-center gap-3">
                    <h1 className="text-2xl font-black text-white tracking-tight">لوحة تحكم صورلي</h1>
                </div>
                <nav className="flex-1 space-y-1.5 px-4 overflow-y-auto">
                    {navItems.map((item) => {
                        const isActive = pathname === item.href;
                        return (
                            <Link
                                key={item.href}
                                href={item.href}
                                className={`block px-4 py-2.5 rounded-lg transition-all duration-200 font-medium ${isActive
                                    ? 'bg-purple-600 text-white shadow-md shadow-purple-500/20'
                                    : 'text-slate-300 hover:bg-slate-800 hover:text-white hover:-translate-x-1'
                                    }`}
                            >
                                {item.label}
                            </Link>
                        );
                    })}
                </nav>
                <div className="p-4 mt-auto border-t border-slate-800">
                    <button
                        onClick={handleLogout}
                        className="w-full px-4 py-2.5 bg-red-500 hover:bg-red-600 transition-colors rounded-lg text-center text-white font-medium shadow-sm flex items-center justify-center gap-2"
                    >
                        تسجيل الخروج
                    </button>
                </div>
            </aside>

            {/* Main Content */}
            <main className="flex-1 overflow-y-auto bg-slate-50 text-slate-900">
                <div className="p-8 max-w-7xl mx-auto">
                    {children}
                </div>
            </main>
        </div>
    );
}


