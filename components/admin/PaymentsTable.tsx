'use client';

import { useEffect, useState } from 'react';

interface PaymentRow {
    id: string;
    quote_id: string | null;
    linked_project_id: string | null;
    amount: number;
    method: string;
    status: 'pending' | 'confirmed' | 'rejected';
    proof_url: string | null;
    created_at: string;
    confirmed_at: string | null;
    offer_title: string | null;
    creator_name: string | null;
    client_name: string | null;
    created_by_name: string | null;
    confirmed_by_name: string | null;
    project_status: string | null;
}

const statusClassMap: Record<PaymentRow['status'], string> = {
    pending: 'bg-amber-100 text-amber-700',
    confirmed: 'bg-green-100 text-green-700',
    rejected: 'bg-red-100 text-red-700',
};

export default function PaymentsTable() {
    const [payments, setPayments] = useState<PaymentRow[]>([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);
    const [actionId, setActionId] = useState<string | null>(null);

    const fetchPayments = async () => {
        try {
            setLoading(true);
            setError(null);

            const token = localStorage.getItem('token');
            const res = await fetch('/api/admin/payments', {
                headers: { Authorization: `Bearer ${token}` },
            });

            const data = await res.json();
            if (!res.ok) {
                throw new Error(data?.error || 'Failed to fetch payments');
            }

            setPayments(Array.isArray(data) ? data : []);
        } catch (err) {
            setError(err instanceof Error ? err.message : 'حدث خطأ غير متوقع');
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        fetchPayments();
    }, []);

    const handleConfirm = async (paymentId: string) => {
        try {
            setActionId(paymentId);
            setError(null);

            const token = localStorage.getItem('token');
            const res = await fetch(`/api/payments/${paymentId}/confirm`, {
                method: 'POST',
                headers: { Authorization: `Bearer ${token}` },
            });
            const data = await res.json();

            if (!res.ok) {
                throw new Error(data?.error || 'فشل تأكيد الدفع');
            }

            await fetchPayments();
        } catch (err) {
            setError(err instanceof Error ? err.message : 'حدث خطأ غير متوقع');
        } finally {
            setActionId(null);
        }
    };

    const handleReject = async (paymentId: string) => {
        if (!window.confirm('هل تريد رفض هذا الدفع؟')) {
            return;
        }

        try {
            setActionId(paymentId);
            setError(null);

            const token = localStorage.getItem('token');
            const res = await fetch(`/api/admin/payments/${paymentId}/reject`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    Authorization: `Bearer ${token}`,
                },
                body: JSON.stringify({}),
            });
            const data = await res.json();

            if (!res.ok) {
                throw new Error(data?.error || 'فشل رفض الدفع');
            }

            await fetchPayments();
        } catch (err) {
            setError(err instanceof Error ? err.message : 'حدث خطأ غير متوقع');
        } finally {
            setActionId(null);
        }
    };

    if (loading) {
        return <div className="p-4 text-center">جاري تحميل المدفوعات...</div>;
    }

    if (error) {
        return <div className="p-4 text-red-500 bg-red-50 rounded-lg">{error}</div>;
    }

    return (
        <div dir="rtl" className="space-y-4">
            <div className="overflow-x-auto rounded-lg border border-slate-200 shadow-sm">
                <table className="min-w-full bg-white text-sm">
                    <thead>
                        <tr className="bg-slate-50 border-b border-slate-200">
                            <th className="py-4 px-4 text-right font-semibold text-slate-600">العرض</th>
                            <th className="py-4 px-4 text-right font-semibold text-slate-600">المبدع</th>
                            <th className="py-4 px-4 text-right font-semibold text-slate-600">العميل</th>
                            <th className="py-4 px-4 text-right font-semibold text-slate-600">المبلغ</th>
                            <th className="py-4 px-4 text-right font-semibold text-slate-600">الطريقة</th>
                            <th className="py-4 px-4 text-right font-semibold text-slate-600">إثبات الدفع</th>
                            <th className="py-4 px-4 text-right font-semibold text-slate-600">الحالة</th>
                            <th className="py-4 px-4 text-right font-semibold text-slate-600">المشروع</th>
                            <th className="py-4 px-4 text-right font-semibold text-slate-600">التاريخ</th>
                            <th className="py-4 px-4 text-center font-semibold text-slate-600">الإجراءات</th>
                        </tr>
                    </thead>
                    <tbody className="divide-y divide-slate-100">
                        {payments.map((payment) => (
                            <tr key={payment.id} className="hover:bg-slate-50 transition-colors">
                                <td className="py-4 px-4 text-right">
                                    <div className="font-medium text-slate-800">{payment.offer_title || 'بدون عنوان'}</div>
                                    <div className="text-xs text-slate-400 font-mono" dir="ltr">{payment.quote_id}</div>
                                </td>
                                <td className="py-4 px-4 text-right text-slate-700">{payment.creator_name || '-'}</td>
                                <td className="py-4 px-4 text-right text-slate-700">{payment.client_name || '-'}</td>
                                <td className="py-4 px-4 text-right font-semibold text-slate-800">
                                    <span dir="ltr">{Number(payment.amount || 0).toLocaleString('en-US')} IQD</span>
                                </td>
                                <td className="py-4 px-4 text-right text-slate-600">{payment.method}</td>
                                <td className="py-4 px-4 text-right">
                                    {payment.proof_url ? (
                                        <a
                                            href={payment.proof_url}
                                            target="_blank"
                                            rel="noreferrer"
                                            className="text-blue-600 hover:underline"
                                        >
                                            فتح الإثبات
                                        </a>
                                    ) : (
                                        <span className="text-slate-400">لا يوجد</span>
                                    )}
                                </td>
                                <td className="py-4 px-4 text-right">
                                    <span className={`inline-flex rounded-full px-3 py-1 text-xs font-bold ${statusClassMap[payment.status]}`}>
                                        {payment.status}
                                    </span>
                                    {payment.confirmed_by_name && (
                                        <div className="mt-1 text-xs text-slate-400">
                                            بواسطة {payment.confirmed_by_name}
                                        </div>
                                    )}
                                </td>
                                <td className="py-4 px-4 text-right">
                                    {payment.linked_project_id ? (
                                        <div>
                                            <div className="font-medium text-slate-700">{payment.project_status || 'linked'}</div>
                                            <div className="text-xs text-slate-400 font-mono" dir="ltr">{payment.linked_project_id}</div>
                                        </div>
                                    ) : (
                                        <span className="text-slate-400">غير مرتبط بعد</span>
                                    )}
                                </td>
                                <td className="py-4 px-4 text-right text-slate-500">
                                    {new Date(payment.created_at).toLocaleDateString('ar-IQ')}
                                </td>
                                <td className="py-4 px-4 text-center">
                                    {payment.status === 'pending' ? (
                                        <div className="flex items-center justify-center gap-2">
                                            <button
                                                onClick={() => handleConfirm(payment.id)}
                                                disabled={actionId === payment.id}
                                                className="rounded-md bg-green-600 px-3 py-1.5 text-white hover:bg-green-700 disabled:opacity-50"
                                            >
                                                تأكيد
                                            </button>
                                            <button
                                                onClick={() => handleReject(payment.id)}
                                                disabled={actionId === payment.id}
                                                className="rounded-md bg-red-100 px-3 py-1.5 text-red-700 hover:bg-red-200 disabled:opacity-50"
                                            >
                                                رفض
                                            </button>
                                        </div>
                                    ) : (
                                        <span className="text-slate-400">تمت المعالجة</span>
                                    )}
                                </td>
                            </tr>
                        ))}
                        {payments.length === 0 && (
                            <tr>
                                <td colSpan={10} className="py-12 text-center text-slate-500 font-medium">
                                    لا توجد مدفوعات حالياً.
                                </td>
                            </tr>
                        )}
                    </tbody>
                </table>
            </div>
        </div>
    );
}
