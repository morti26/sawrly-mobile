"use client";

import { useCallback, useEffect, useMemo, useState } from 'react';

type ReadinessStatus = 'ok' | 'warn' | 'fail';

interface ReadinessCheck {
    id: string;
    title: string;
    status: ReadinessStatus;
    details: string;
    action?: string;
}

interface ReadinessReport {
    generatedAt: string;
    readyForManualPayments: boolean;
    readyForOnlinePayments: boolean;
    checks: ReadinessCheck[];
}

const statusStyles: Record<ReadinessStatus, string> = {
    ok: 'bg-emerald-100 text-emerald-700 border-emerald-200',
    warn: 'bg-amber-100 text-amber-700 border-amber-200',
    fail: 'bg-rose-100 text-rose-700 border-rose-200',
};

const statusLabels: Record<ReadinessStatus, string> = {
    ok: 'جاهز',
    warn: 'ملاحظة',
    fail: 'غير جاهز',
};

export default function ReadinessPage() {
    const [report, setReport] = useState<ReadinessReport | null>(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);

    const load = useCallback(async () => {
        setLoading(true);
        setError(null);
        try {
            const token = localStorage.getItem('token');
            const res = await fetch('/api/admin/readiness', {
                headers: { Authorization: `Bearer ${token}` },
            });
            const data = await res.json();
            if (!res.ok) {
                throw new Error(data?.error || 'Failed to load readiness report');
            }
            setReport(data as ReadinessReport);
        } catch (err) {
            setError(err instanceof Error ? err.message : 'Unexpected error');
        } finally {
            setLoading(false);
        }
    }, []);

    useEffect(() => {
        void load();
    }, [load]);

    const summary = useMemo(() => {
        if (!report) {
            return { ok: 0, warn: 0, fail: 0 };
        }
        return report.checks.reduce(
            (acc, check) => {
                acc[check.status] += 1;
                return acc;
            },
            { ok: 0, warn: 0, fail: 0 }
        );
    }, [report]);

    return (
        <div dir="rtl" className="space-y-6">
            <div className="flex items-start justify-between gap-3">
                <div>
                    <h1 className="text-2xl font-bold text-slate-900">جاهزية الإنتاج</h1>
                    <p className="mt-1 text-sm text-slate-500">
                        فحص تلقائي لما تبقى قبل الإطلاق. يمكنك التحديث في أي وقت.
                    </p>
                </div>
                <button
                    type="button"
                    onClick={() => void load()}
                    className="rounded-lg bg-black px-4 py-2 text-sm font-semibold text-white hover:bg-slate-800"
                >
                    تحديث الفحص
                </button>
            </div>

            {error && (
                <div className="rounded-lg border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">
                    {error}
                </div>
            )}

            {loading ? (
                <div className="rounded-xl border border-slate-200 bg-white p-8 text-center text-slate-500">
                    جاري تشغيل فحص الجاهزية...
                </div>
            ) : report ? (
                <>
                    <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
                        <div className="rounded-xl border border-slate-200 bg-white p-4 shadow-sm">
                            <p className="text-xs text-slate-500">جاهزية الدفع اليدوي</p>
                            <p className={`mt-2 text-lg font-bold ${report.readyForManualPayments ? 'text-emerald-700' : 'text-rose-700'}`}>
                                {report.readyForManualPayments ? 'جاهز' : 'غير جاهز'}
                            </p>
                        </div>
                        <div className="rounded-xl border border-slate-200 bg-white p-4 shadow-sm">
                            <p className="text-xs text-slate-500">جاهزية الدفع الإلكتروني</p>
                            <p className={`mt-2 text-lg font-bold ${report.readyForOnlinePayments ? 'text-emerald-700' : 'text-amber-700'}`}>
                                {report.readyForOnlinePayments ? 'جاهز' : 'بانتظار الإعداد'}
                            </p>
                        </div>
                        <div className="rounded-xl border border-slate-200 bg-white p-4 shadow-sm">
                            <p className="text-xs text-slate-500">آخر تحديث</p>
                            <p className="mt-2 text-sm font-semibold text-slate-700">
                                {new Date(report.generatedAt).toLocaleString('ar-IQ')}
                            </p>
                        </div>
                    </div>

                    <div className="grid grid-cols-3 gap-3">
                        <div className="rounded-lg border border-emerald-200 bg-emerald-50 px-3 py-2 text-sm text-emerald-700">
                            ناجح: {summary.ok}
                        </div>
                        <div className="rounded-lg border border-amber-200 bg-amber-50 px-3 py-2 text-sm text-amber-700">
                            ملاحظات: {summary.warn}
                        </div>
                        <div className="rounded-lg border border-rose-200 bg-rose-50 px-3 py-2 text-sm text-rose-700">
                            مشاكل: {summary.fail}
                        </div>
                    </div>

                    <div className="space-y-3">
                        {report.checks.map((check) => (
                            <div key={check.id} className="rounded-xl border border-slate-200 bg-white p-4 shadow-sm">
                                <div className="flex items-center justify-between gap-2">
                                    <h2 className="text-sm font-semibold text-slate-900">{check.title}</h2>
                                    <span className={`rounded-full border px-2.5 py-0.5 text-xs font-bold ${statusStyles[check.status]}`}>
                                        {statusLabels[check.status]}
                                    </span>
                                </div>
                                <p className="mt-2 text-sm text-slate-700">{check.details}</p>
                                {check.action && (
                                    <p className="mt-2 text-xs font-medium text-slate-500">
                                        الإجراء: {check.action}
                                    </p>
                                )}
                            </div>
                        ))}
                    </div>
                </>
            ) : null}
        </div>
    );
}
