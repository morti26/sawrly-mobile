'use client';

import { useCallback, useEffect, useState } from 'react';

type AuditEntityType = 'user' | 'project' | 'payment' | 'quote' | 'offer' | 'delivery';

interface AuditLogRow {
    id: string;
    entity_type: AuditEntityType;
    entity_id: string;
    event_type: string;
    actor_id: string;
    actor_name: string | null;
    actor_email: string | null;
    metadata: Record<string, unknown> | null;
    created_at: string;
    entity_title: string | null;
}

const entityLabels: Record<AuditEntityType, string> = {
    user: 'مستخدم',
    project: 'مشروع',
    payment: 'دفعة',
    quote: 'طلب',
    offer: 'عرض',
    delivery: 'تسليم',
};

const eventLabels: Record<string, string> = {
    quote_created: 'إنشاء طلب',
    payment_submitted: 'إرسال دفعة',
    payment_confirmed: 'تأكيد دفعة',
    payment_rejected: 'رفض دفعة',
    project_started: 'بدء مشروع',
    project_status_updated: 'تحديث حالة المشروع',
    project_cancelled: 'إلغاء مشروع',
    delivery_submitted: 'إرسال تسليم',
    project_completed: 'اكتمال المشروع',
};

const eventClassName = (eventType: string): string => {
    if (eventType.includes('confirmed') || eventType.includes('completed')) {
        return 'bg-green-100 text-green-700';
    }
    if (eventType.includes('rejected') || eventType.includes('cancelled')) {
        return 'bg-red-100 text-red-700';
    }
    if (eventType.includes('started') || eventType.includes('submitted')) {
        return 'bg-blue-100 text-blue-700';
    }
    if (eventType.includes('updated')) {
        return 'bg-amber-100 text-amber-700';
    }
    return 'bg-slate-100 text-slate-700';
};

const formatMetadataValue = (value: unknown): string => {
    if (value === null || value === undefined) {
        return '-';
    }
    if (typeof value === 'string' || typeof value === 'number' || typeof value === 'boolean') {
        return String(value);
    }
    return JSON.stringify(value);
};

const getMetadataEntries = (metadata: AuditLogRow['metadata']): [string, unknown][] => {
    if (!metadata || typeof metadata !== 'object' || Array.isArray(metadata)) {
        return [];
    }

    return Object.entries(metadata);
};

export default function AuditLogsTable() {
    const [logs, setLogs] = useState<AuditLogRow[]>([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);
    const [query, setQuery] = useState('');
    const [appliedQuery, setAppliedQuery] = useState('');
    const [entityType, setEntityType] = useState<'all' | AuditEntityType>('all');

    const fetchLogs = useCallback(async () => {
        try {
            setLoading(true);
            setError(null);

            const token = localStorage.getItem('token');
            const params = new URLSearchParams();

            if (entityType !== 'all') {
                params.set('entityType', entityType);
            }

            if (appliedQuery.trim()) {
                params.set('q', appliedQuery.trim());
            }

            const res = await fetch(`/api/admin/audit-logs${params.toString() ? `?${params}` : ''}`, {
                headers: { Authorization: `Bearer ${token}` },
            });
            const data = await res.json();

            if (!res.ok) {
                throw new Error(data?.error || 'Failed to fetch audit logs');
            }

            setLogs(Array.isArray(data) ? data : []);
        } catch (err) {
            setError(err instanceof Error ? err.message : 'حدث خطأ غير متوقع');
        } finally {
            setLoading(false);
        }
    }, [appliedQuery, entityType]);

    useEffect(() => {
        void fetchLogs();
    }, [fetchLogs]);

    const handleSearchSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        const nextQuery = query.trim();
        if (nextQuery === appliedQuery) {
            await fetchLogs();
            return;
        }
        setAppliedQuery(nextQuery);
    };

    if (loading) {
        return <div className="p-4 text-center">جاري تحميل سجل التدقيق...</div>;
    }

    return (
        <div dir="rtl" className="space-y-4">
            <form onSubmit={handleSearchSubmit} className="flex flex-wrap items-end gap-3">
                <div className="min-w-[260px] flex-1">
                    <label className="mb-1 block text-sm font-medium text-slate-700">بحث</label>
                    <input
                        type="text"
                        value={query}
                        onChange={(e) => setQuery(e.target.value)}
                        placeholder="ابحث بالحدث أو المستخدم أو المعرف أو التفاصيل"
                        className="w-full rounded-lg border border-slate-200 px-3 py-2"
                    />
                </div>
                <div className="min-w-[180px]">
                    <label className="mb-1 block text-sm font-medium text-slate-700">نوع الكيان</label>
                    <select
                        value={entityType}
                        onChange={(e) => setEntityType(e.target.value as 'all' | AuditEntityType)}
                        className="w-full rounded-lg border border-slate-200 px-3 py-2"
                    >
                        <option value="all">الكل</option>
                        <option value="project">المشاريع</option>
                        <option value="payment">المدفوعات</option>
                        <option value="quote">الطلبات</option>
                        <option value="delivery">التسليمات</option>
                        <option value="offer">العروض</option>
                        <option value="user">المستخدمون</option>
                    </select>
                </div>
                <button
                    type="submit"
                    className="rounded-lg bg-blue-600 px-4 py-2 text-white hover:bg-blue-700"
                >
                    بحث
                </button>
            </form>

            <div className="rounded-lg border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-600">
                أحدث {logs.length} سجل من النظام
            </div>

            {error && (
                <div className="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
                    {error}
                </div>
            )}

            <div className="overflow-x-auto rounded-lg border border-slate-200 shadow-sm">
                <table className="min-w-full bg-white text-sm">
                    <thead>
                        <tr className="border-b border-slate-200 bg-slate-50">
                            <th className="px-4 py-4 text-right font-semibold text-slate-600">الحدث</th>
                            <th className="px-4 py-4 text-right font-semibold text-slate-600">الكيان</th>
                            <th className="px-4 py-4 text-right font-semibold text-slate-600">المنفذ</th>
                            <th className="px-4 py-4 text-right font-semibold text-slate-600">التفاصيل</th>
                            <th className="px-4 py-4 text-right font-semibold text-slate-600">التاريخ</th>
                        </tr>
                    </thead>
                    <tbody className="divide-y divide-slate-100">
                        {logs.map((log) => {
                            const metadataEntries = getMetadataEntries(log.metadata);

                            return (
                                <tr key={log.id} className="transition-colors hover:bg-slate-50">
                                    <td className="px-4 py-4 text-right">
                                        <div className="space-y-2">
                                            <span className={`inline-flex rounded-full px-3 py-1 text-xs font-bold ${eventClassName(log.event_type)}`}>
                                                {eventLabels[log.event_type] || log.event_type}
                                            </span>
                                            <div className="text-[11px] font-mono text-slate-400" dir="ltr">{log.event_type}</div>
                                        </div>
                                    </td>
                                    <td className="px-4 py-4 text-right">
                                        <div className="font-medium text-slate-800">{entityLabels[log.entity_type]}</div>
                                        {log.entity_title && (
                                            <div className="mt-1 text-xs text-slate-500">{log.entity_title}</div>
                                        )}
                                        <div className="mt-1 text-[11px] font-mono text-slate-400" dir="ltr">{log.entity_id}</div>
                                    </td>
                                    <td className="px-4 py-4 text-right">
                                        <div className="font-medium text-slate-800">{log.actor_name || 'غير معروف'}</div>
                                        {log.actor_email && (
                                            <div className="mt-1 text-xs text-slate-500" dir="ltr">{log.actor_email}</div>
                                        )}
                                        <div className="mt-1 text-[11px] font-mono text-slate-400" dir="ltr">{log.actor_id}</div>
                                    </td>
                                    <td className="px-4 py-4 text-right">
                                        {metadataEntries.length > 0 ? (
                                            <div className="flex max-w-[360px] flex-wrap gap-2">
                                                {metadataEntries.slice(0, 4).map(([key, value]) => (
                                                    <span
                                                        key={`${log.id}-${key}`}
                                                        className="inline-flex max-w-full items-center gap-1 rounded-full bg-slate-100 px-3 py-1 text-xs text-slate-700"
                                                        title={formatMetadataValue(value)}
                                                    >
                                                        <span className="font-semibold text-slate-600">{key}:</span>
                                                        <span className="truncate">{formatMetadataValue(value)}</span>
                                                    </span>
                                                ))}
                                            </div>
                                        ) : (
                                            <span className="text-slate-400">لا توجد تفاصيل إضافية</span>
                                        )}
                                    </td>
                                    <td className="px-4 py-4 text-right text-slate-500">
                                        <div>{new Date(log.created_at).toLocaleDateString('ar-IQ')}</div>
                                        <div className="mt-1 text-xs text-slate-400">
                                            {new Date(log.created_at).toLocaleTimeString('ar-IQ')}
                                        </div>
                                    </td>
                                </tr>
                            );
                        })}
                        {logs.length === 0 && (
                            <tr>
                                <td colSpan={5} className="py-12 text-center font-medium text-slate-500">
                                    لا توجد سجلات مطابقة حالياً.
                                </td>
                            </tr>
                        )}
                    </tbody>
                </table>
            </div>
        </div>
    );
}
