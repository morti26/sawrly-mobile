"use client";

import { useCallback, useEffect, useState } from 'react';

interface OpsErrorRow {
    id: string;
    source: string;
    level: 'error' | 'warn';
    message: string;
    request_path: string | null;
    details: unknown;
    created_at: string;
}

const levelStyle: Record<OpsErrorRow['level'], string> = {
    error: 'bg-red-100 text-red-700',
    warn: 'bg-amber-100 text-amber-700',
};

export default function OpsErrorsPage() {
    const [items, setItems] = useState<OpsErrorRow[]>([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);

    const fetchItems = useCallback(async () => {
        try {
            setLoading(true);
            setError(null);
            const token = localStorage.getItem('token');
            const res = await fetch('/api/admin/ops-errors?limit=200', {
                headers: { Authorization: `Bearer ${token}` },
            });
            const data = await res.json();
            if (!res.ok) {
                throw new Error(data?.error || 'تعذر تحميل سجل الأخطاء');
            }
            setItems(Array.isArray(data) ? data : []);
        } catch (err) {
            setError(err instanceof Error ? err.message : 'حدث خطأ غير متوقع');
        } finally {
            setLoading(false);
        }
    }, []);

    useEffect(() => {
        void fetchItems();
    }, [fetchItems]);

    return (
        <div dir="rtl" className="space-y-4">
            <div className="flex items-center justify-between">
                <h1 className="text-2xl font-bold text-slate-800">سجل أخطاء التشغيل</h1>
                <button
                    type="button"
                    onClick={() => void fetchItems()}
                    className="rounded-lg bg-black px-4 py-2 text-white hover:bg-slate-800"
                >
                    تحديث
                </button>
            </div>

            {error && (
                <div className="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
                    {error}
                </div>
            )}

            {loading ? (
                <div className="rounded-lg border border-slate-200 bg-white p-8 text-center text-slate-500">
                    جاري تحميل السجل...
                </div>
            ) : (
                <div className="overflow-x-auto rounded-lg border border-slate-200 shadow-sm">
                    <table className="min-w-full bg-white text-sm">
                        <thead>
                            <tr className="border-b border-slate-200 bg-slate-50">
                                <th className="px-4 py-3 text-right font-semibold text-slate-600">المصدر</th>
                                <th className="px-4 py-3 text-right font-semibold text-slate-600">المستوى</th>
                                <th className="px-4 py-3 text-right font-semibold text-slate-600">الرسالة</th>
                                <th className="px-4 py-3 text-right font-semibold text-slate-600">المسار</th>
                                <th className="px-4 py-3 text-right font-semibold text-slate-600">الوقت</th>
                            </tr>
                        </thead>
                        <tbody className="divide-y divide-slate-100">
                            {items.map((item) => (
                                <tr key={item.id} className="hover:bg-slate-50">
                                    <td className="px-4 py-3 font-mono text-xs text-slate-700">{item.source}</td>
                                    <td className="px-4 py-3">
                                        <span className={`inline-flex rounded-full px-2 py-0.5 text-xs font-bold ${levelStyle[item.level]}`}>
                                            {item.level === 'error' ? 'خطأ' : 'تحذير'}
                                        </span>
                                    </td>
                                    <td className="px-4 py-3 text-slate-800">{item.message}</td>
                                    <td className="px-4 py-3 font-mono text-xs text-slate-500" dir="ltr">
                                        {item.request_path || '-'}
                                    </td>
                                    <td className="px-4 py-3 text-slate-500">
                                        {new Date(item.created_at).toLocaleString('ar-IQ')}
                                    </td>
                                </tr>
                            ))}
                            {items.length === 0 && (
                                <tr>
                                    <td colSpan={5} className="py-10 text-center text-slate-500">
                                        لا توجد أخطاء مسجلة حالياً.
                                    </td>
                                </tr>
                            )}
                        </tbody>
                    </table>
                </div>
            )}
        </div>
    );
}
