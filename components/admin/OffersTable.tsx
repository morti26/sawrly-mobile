'use client';

import Image from 'next/image';
import { useCallback, useEffect, useState } from 'react';

type OfferStatus = 'active' | 'inactive' | 'archived';

interface OfferRow {
    id: string;
    creator_id: string;
    title: string;
    description: string;
    price_iqd: number;
    status: OfferStatus;
    image_url: string | null;
    created_at: string;
    updated_at: string;
    view_count: number;
    discount_percent: number;
    original_price_iqd: number | null;
    creator_name: string;
    like_count: number;
    order_count: number;
}

const statusClassMap: Record<OfferStatus, string> = {
    active: 'bg-green-100 text-green-700',
    inactive: 'bg-amber-100 text-amber-700',
    archived: 'bg-slate-200 text-slate-700',
};

const statusLabels: Record<OfferStatus, string> = {
    active: 'نشط',
    inactive: 'غير نشط',
    archived: 'مؤرشف',
};

const isVideoUrl = (url: string | null): boolean => {
    if (!url) return false;
    return /\.(mp4|mov|webm|m4v|avi)(\?.*)?$/i.test(url);
};

export default function OffersTable() {
    const [offers, setOffers] = useState<OfferRow[]>([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);
    const [query, setQuery] = useState('');
    const [appliedQuery, setAppliedQuery] = useState('');
    const [statusFilter, setStatusFilter] = useState<'all' | OfferStatus>('all');
    const [actionId, setActionId] = useState<string | null>(null);

    const fetchOffers = useCallback(async () => {
        try {
            setLoading(true);
            setError(null);

            const token = localStorage.getItem('token');
            const params = new URLSearchParams();
            if (statusFilter !== 'all') {
                params.set('status', statusFilter);
            }
            if (appliedQuery.trim()) {
                params.set('q', appliedQuery.trim());
            }

            const res = await fetch(`/api/admin/offers${params.toString() ? `?${params}` : ''}`, {
                headers: { Authorization: `Bearer ${token}` },
            });
            const data = await res.json();

            if (!res.ok) {
                throw new Error(data?.error || 'Failed to fetch offers');
            }

            setOffers(Array.isArray(data) ? data : []);
        } catch (err) {
            setError(err instanceof Error ? err.message : 'حدث خطأ غير متوقع');
        } finally {
            setLoading(false);
        }
    }, [appliedQuery, statusFilter]);

    useEffect(() => {
        void fetchOffers();
    }, [fetchOffers]);

    const handleSearchSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        const nextQuery = query.trim();
        if (nextQuery === appliedQuery) {
            await fetchOffers();
            return;
        }
        setAppliedQuery(nextQuery);
    };

    const handleStatusUpdate = async (offerId: string, nextStatus: OfferStatus) => {
        try {
            setActionId(offerId);
            setError(null);

            const token = localStorage.getItem('token');
            const res = await fetch(`/api/admin/offers/${offerId}`, {
                method: 'PATCH',
                headers: {
                    'Content-Type': 'application/json',
                    Authorization: `Bearer ${token}`,
                },
                body: JSON.stringify({ status: nextStatus }),
            });
            const data = await res.json();

            if (!res.ok) {
                throw new Error(data?.error || 'فشل تحديث حالة العرض');
            }

            setOffers((prev) =>
                prev.map((offer) =>
                    offer.id === offerId ? { ...offer, status: nextStatus } : offer
                )
            );
        } catch (err) {
            setError(err instanceof Error ? err.message : 'حدث خطأ غير متوقع');
        } finally {
            setActionId(null);
        }
    };

    const handleDelete = async (offerId: string) => {
        if (!window.confirm('هل تريد حذف هذا العرض نهائياً؟')) {
            return;
        }

        try {
            setActionId(offerId);
            setError(null);

            const token = localStorage.getItem('token');
            const res = await fetch(`/api/admin/offers/${offerId}`, {
                method: 'DELETE',
                headers: { Authorization: `Bearer ${token}` },
            });
            const data = await res.json();

            if (!res.ok) {
                throw new Error(data?.error || 'فشل حذف العرض');
            }

            setOffers((prev) => prev.filter((offer) => offer.id !== offerId));
        } catch (err) {
            setError(err instanceof Error ? err.message : 'حدث خطأ غير متوقع');
        } finally {
            setActionId(null);
        }
    };

    if (loading) {
        return <div className="p-4 text-center">جاري تحميل العروض...</div>;
    }

    return (
        <div dir="rtl" className="space-y-4">
            <form
                onSubmit={handleSearchSubmit}
                className="grid grid-cols-1 items-end gap-3 md:grid-cols-[120px_180px_1fr]"
            >
                <button
                    type="submit"
                    className="rounded-lg bg-blue-600 px-4 py-2 text-white hover:bg-blue-700"
                >
                    بحث
                </button>
                <div className="min-w-[180px]">
                    <label className="mb-1 block text-sm font-medium text-slate-700">الحالة</label>
                    <select
                        value={statusFilter}
                        onChange={(e) => setStatusFilter(e.target.value as 'all' | OfferStatus)}
                        className="w-full rounded-lg border border-slate-200 px-3 py-2"
                    >
                        <option value="all">الكل</option>
                        <option value="active">نشط</option>
                        <option value="inactive">غير نشط</option>
                        <option value="archived">مؤرشف</option>
                    </select>
                </div>
                <div className="min-w-[240px]">
                    <label className="mb-1 block text-sm font-medium text-slate-700">بحث</label>
                    <input
                        type="text"
                        value={query}
                        onChange={(e) => setQuery(e.target.value)}
                        placeholder="ابحث بالعنوان أو الوصف أو اسم المبدع"
                        className="w-full rounded-lg border border-slate-200 px-3 py-2"
                    />
                </div>
            </form>

            {error && (
                <div className="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
                    {error}
                </div>
            )}

            <div className="overflow-x-auto rounded-lg border border-slate-200 shadow-sm">
                <table className="min-w-full bg-white text-sm">
                    <thead>
                        <tr className="border-b border-slate-200 bg-slate-50">
                            <th className="px-4 py-4 text-center font-semibold text-slate-600">الإجراءات</th>
                            <th className="px-4 py-4 text-right font-semibold text-slate-600">التاريخ</th>
                            <th className="px-4 py-4 text-right font-semibold text-slate-600">الحالة</th>
                            <th className="px-4 py-4 text-right font-semibold text-slate-600">الإحصائيات</th>
                            <th className="px-4 py-4 text-right font-semibold text-slate-600">السعر</th>
                            <th className="px-4 py-4 text-right font-semibold text-slate-600">المبدع</th>
                            <th className="px-4 py-4 text-right font-semibold text-slate-600">العرض</th>
                        </tr>
                    </thead>
                    <tbody className="divide-y divide-slate-100">
                        {offers.map((offer) => (
                            <tr key={offer.id} className="hover:bg-slate-50 transition-colors">
                                <td className="px-4 py-4 text-center">
                                    <div className="flex flex-col items-center gap-2">
                                        <select
                                            value={offer.status}
                                            disabled={actionId === offer.id}
                                            onChange={(e) => handleStatusUpdate(offer.id, e.target.value as OfferStatus)}
                                            className="rounded-md border border-slate-200 px-2 py-1 text-xs"
                                        >
                                            <option value="active">نشط</option>
                                            <option value="inactive">غير نشط</option>
                                            <option value="archived">مؤرشف</option>
                                        </select>
                                        <button
                                            onClick={() => handleDelete(offer.id)}
                                            disabled={actionId === offer.id}
                                            className="rounded-md bg-red-50 px-3 py-1.5 text-xs font-medium text-red-700 hover:bg-red-100 disabled:opacity-50"
                                        >
                                            حذف
                                        </button>
                                    </div>
                                </td>
                                <td className="px-4 py-4 text-right text-slate-500">
                                    <div>{new Date(offer.created_at).toLocaleDateString('ar-IQ')}</div>
                                    <div className="mt-1 text-xs text-slate-400">
                                        تحديث: {new Date(offer.updated_at).toLocaleDateString('ar-IQ')}
                                    </div>
                                </td>
                                <td className="px-4 py-4 text-right">
                                    <span
                                        className={`inline-flex rounded-full px-3 py-1 text-xs font-bold ${statusClassMap[offer.status]}`}
                                    >
                                        {statusLabels[offer.status]}
                                    </span>
                                </td>
                                <td className="px-4 py-4 text-right text-xs text-slate-600">
                                    <div>الإعجابات: {offer.like_count}</div>
                                    <div>الطلبات: {offer.order_count}</div>
                                    <div>المشاهدات: {offer.view_count}</div>
                                </td>
                                <td className="px-4 py-4 text-right">
                                    <div className="font-semibold text-slate-800" dir="ltr">
                                        {Number(offer.price_iqd || 0).toLocaleString('en-US')} IQD
                                    </div>
                                    {offer.discount_percent > 0 && (
                                        <div className="mt-1 text-xs text-red-500">
                                            خصم {offer.discount_percent}%{offer.original_price_iqd ? ` من ${Number(offer.original_price_iqd).toLocaleString('en-US')} IQD` : ''}
                                        </div>
                                    )}
                                </td>
                                <td className="px-4 py-4 text-right">
                                    <div className="font-medium text-slate-700">{offer.creator_name}</div>
                                    <div className="mt-1 text-[11px] font-mono text-slate-400" dir="ltr">
                                        {offer.creator_id}
                                    </div>
                                </td>
                                <td className="px-4 py-4 text-right">
                                    <div className="flex flex-row-reverse items-start gap-3">
                                        <div className="h-16 w-16 overflow-hidden rounded-lg border border-slate-200 bg-slate-100">
                                            {offer.image_url ? (
                                                isVideoUrl(offer.image_url) ? (
                                                    <div className="flex h-full items-center justify-center bg-slate-900 text-xs font-bold text-white">
                                                        VIDEO
                                                    </div>
                                                ) : (
                                                    <Image
                                                        src={offer.image_url}
                                                        alt={offer.title}
                                                        width={64}
                                                        height={64}
                                                        className="h-full w-full object-cover"
                                                        unoptimized
                                                    />
                                                )
                                            ) : (
                                                <div className="flex h-full items-center justify-center text-xs text-slate-400">
                                                    No Media
                                                </div>
                                            )}
                                        </div>
                                        <div className="min-w-[220px]">
                                            <div className="font-semibold text-slate-800">{offer.title}</div>
                                            <div className="mt-1 line-clamp-2 text-xs text-slate-500">
                                                {offer.description}
                                            </div>
                                            <div className="mt-2 text-[11px] font-mono text-slate-400" dir="ltr">
                                                {offer.id}
                                            </div>
                                        </div>
                                    </div>
                                </td>
                            </tr>
                        ))}
                        {offers.length === 0 && (
                            <tr>
                                <td colSpan={7} className="py-12 text-center font-medium text-slate-500">
                                    لا توجد عروض مطابقة.
                                </td>
                            </tr>
                        )}
                    </tbody>
                </table>
            </div>
        </div>
    );
}
