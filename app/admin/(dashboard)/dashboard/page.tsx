"use client";

import Link from "next/link";
import { useEffect, useState } from "react";

interface AdminOverview {
    activeProjects: number;
    pendingQuotes: number;
    pendingPayments: number;
    revenueMonth: number;
    openReports: number;
    paymentApiConfigured: boolean;
    paymentProviderName: string | null;
}

export default function DashboardPage() {
    const [overview, setOverview] = useState<AdminOverview>({
        activeProjects: 0,
        pendingQuotes: 0,
        pendingPayments: 0,
        revenueMonth: 0,
        openReports: 0,
        paymentApiConfigured: false,
        paymentProviderName: null,
    });
    const [error, setError] = useState<string | null>(null);

    useEffect(() => {
        const loadOverview = async () => {
            try {
                const token = localStorage.getItem("token");
                const res = await fetch("/api/admin/overview", {
                    headers: { Authorization: `Bearer ${token}` },
                });
                if (!res.ok) {
                    throw new Error("تعذر تحميل لوحة القيادة");
                }
                const data = await res.json();
                setOverview({
                    activeProjects: Number(data?.activeProjects ?? 0),
                    pendingQuotes: Number(data?.pendingQuotes ?? 0),
                    pendingPayments: Number(data?.pendingPayments ?? 0),
                    revenueMonth: Number(data?.revenueMonth ?? 0),
                    openReports: Number(data?.openReports ?? 0),
                    paymentApiConfigured: Boolean(data?.paymentApiConfigured),
                    paymentProviderName: data?.paymentProviderName || null,
                });
            } catch (err) {
                setError(err instanceof Error ? err.message : "تعذر تحميل لوحة القيادة");
            }
        };
        void loadOverview();
    }, []);

    return (
        <div dir="rtl" className="space-y-6">
            <div>
                <h1 className="text-3xl font-bold mb-2">لوحة القيادة</h1>
                <p className="text-sm text-gray-500">نظرة سريعة على الطلبات والمدفوعات والمشاريع والبلاغات المفتوحة.</p>
            </div>

            {error && (
                <div className="rounded border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
                    {error}
                </div>
            )}

            <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6">
                <div className="p-6 border rounded bg-white shadow-sm">
                    <h3 className="text-gray-500 text-sm">المشاريع النشطة</h3>
                    <p className="text-3xl font-bold">{overview.activeProjects}</p>
                    <Link href="/admin/projects" className="text-sm text-blue-600 hover:underline">
                        فتح المشاريع
                    </Link>
                </div>

                <div className="p-6 border rounded bg-white shadow-sm">
                    <h3 className="text-gray-500 text-sm">الطلبات المعلقة</h3>
                    <p className="text-3xl font-bold">{overview.pendingQuotes}</p>
                    <p className="text-xs text-gray-400 mt-2">طلبات بانتظار الانتقال إلى الخطوة التالية في مسار الحجز.</p>
                </div>

                <div className="p-6 border rounded bg-white shadow-sm">
                    <h3 className="text-gray-500 text-sm">المدفوعات المعلقة</h3>
                    <p className="text-3xl font-bold">{overview.pendingPayments}</p>
                    <Link href="/admin/payments" className="text-sm text-blue-600 hover:underline">
                        مراجعة المدفوعات
                    </Link>
                </div>

                <div className="p-6 border rounded bg-white shadow-sm">
                    <h3 className="text-gray-500 text-sm">إيراد هذا الشهر</h3>
                    <p className="text-3xl font-bold" dir="ltr">
                        {overview.revenueMonth.toLocaleString("en-US")} IQD
                    </p>
                </div>

                <div className="p-6 border rounded bg-white shadow-sm">
                    <h3 className="text-gray-500 text-sm">البلاغات المفتوحة</h3>
                    <p className="text-3xl font-bold">{overview.openReports}</p>
                    <Link href="/admin/reports" className="text-sm text-blue-600 hover:underline">
                        مراجعة البلاغات
                    </Link>
                </div>

                <div className="p-6 border rounded bg-white shadow-sm">
                    <h3 className="text-gray-500 text-sm">تكامل الدفع الخارجي</h3>
                    <p className={`text-2xl font-bold ${overview.paymentApiConfigured ? "text-green-700" : "text-amber-600"}`}>
                        {overview.paymentApiConfigured ? "جاهز" : "غير مكتمل"}
                    </p>
                    <p className="text-xs text-gray-400 mt-2">
                        {overview.paymentProviderName || "أدخل اسم المزود ومفتاح الـ API من صفحة الإعدادات."}
                    </p>
                    <Link href="/admin/settings" className="text-sm text-blue-600 hover:underline">
                        فتح الإعدادات
                    </Link>
                </div>
            </div>
        </div>
    );
}
