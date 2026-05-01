"use client";

import { useEffect, useMemo, useState } from 'react';

interface AdminUserOption {
    id: string;
    name: string;
    email: string;
    role: string;
}

export default function NotificationsPage() {
    const [title, setTitle] = useState('');
    const [message, setMessage] = useState('');
    const [isBroadcast, setIsBroadcast] = useState(true);
    const [targetUserId, setTargetUserId] = useState('');
    const [users, setUsers] = useState<AdminUserOption[]>([]);
    const [usersLoading, setUsersLoading] = useState(true);
    const [status, setStatus] = useState<null | { type: 'success' | 'error'; text: string }>(null);
    const [isSubmitting, setIsSubmitting] = useState(false);

    useEffect(() => {
        const loadUsers = async () => {
            try {
                setUsersLoading(true);
                const token = localStorage.getItem('token');
                const res = await fetch('/api/admin/users', {
                    headers: { Authorization: `Bearer ${token}` },
                });
                const data = await res.json();
                if (!res.ok) {
                    throw new Error(data?.error || 'تعذر تحميل المستخدمين');
                }
                setUsers(Array.isArray(data) ? data : []);
            } catch (error) {
                setStatus({
                    type: 'error',
                    text: error instanceof Error ? error.message : 'تعذر تحميل المستخدمين',
                });
            } finally {
                setUsersLoading(false);
            }
        };

        void loadUsers();
    }, []);

    const selectableUsers = useMemo(
        () => users.filter((user) => user.role !== 'admin' && user.role !== 'moderator'),
        [users],
    );

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        setIsSubmitting(true);
        setStatus(null);

        try {
            const token = localStorage.getItem('token');
            const res = await fetch('/api/notifications', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    Authorization: `Bearer ${token}`,
                },
                body: JSON.stringify({
                    title,
                    message,
                    type: 'system',
                    broadcast: isBroadcast,
                    target_user_id: isBroadcast ? null : targetUserId,
                }),
            });

            const data = await res.json().catch(() => ({}));

            if (!res.ok) {
                throw new Error(data?.error || 'فشل إرسال الإشعار');
            }

            setStatus({ type: 'success', text: 'تم إرسال الإشعار بنجاح' });
            setTitle('');
            setMessage('');
            if (!isBroadcast) {
                setTargetUserId('');
            }
        } catch (error) {
            setStatus({
                type: 'error',
                text: error instanceof Error ? error.message : 'حدث خطأ غير متوقع',
            });
        } finally {
            setIsSubmitting(false);
        }
    };

    return (
        <div className="max-w-3xl mx-auto space-y-6" dir="rtl">
            <div>
                <h1 className="text-3xl font-bold mb-2">إرسال الإشعارات</h1>
                <p className="text-sm text-gray-500">يمكنك إرسال إشعار عام لكل المستخدمين أو توجيهه إلى مستخدم محدد.</p>
            </div>

            <div className="bg-white p-6 rounded-xl shadow-sm border border-gray-100">
                {status && (
                    <div
                        className={`p-4 mb-4 rounded ${status.type === 'success'
                            ? 'bg-green-100 text-green-700'
                            : 'bg-red-100 text-red-700'
                            }`}
                    >
                        {status.text}
                    </div>
                )}

                <form onSubmit={handleSubmit} className="space-y-4">
                    <div>
                        <label className="block text-sm font-medium text-gray-700 mb-1">العنوان</label>
                        <input
                            type="text"
                            required
                            className="w-full border p-2 rounded focus:ring-2 focus:ring-blue-500"
                            value={title}
                            onChange={(e) => setTitle(e.target.value)}
                            placeholder="مثال: تحديث مهم"
                        />
                    </div>

                    <div>
                        <label className="block text-sm font-medium text-gray-700 mb-1">الرسالة</label>
                        <textarea
                            required
                            rows={4}
                            className="w-full border p-2 rounded focus:ring-2 focus:ring-blue-500"
                            value={message}
                            onChange={(e) => setMessage(e.target.value)}
                            placeholder="اكتب نص الإشعار هنا..."
                        />
                    </div>

                    <div className="flex items-center gap-2">
                        <input
                            type="checkbox"
                            id="broadcast"
                            className="h-4 w-4 text-blue-600 rounded"
                            checked={isBroadcast}
                            onChange={(e) => setIsBroadcast(e.target.checked)}
                        />
                        <label htmlFor="broadcast" className="text-sm font-medium text-gray-700">
                            إرسال الإشعار إلى جميع المستخدمين
                        </label>
                    </div>

                    {!isBroadcast && (
                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-1">اختر المستخدم</label>
                            <select
                                value={targetUserId}
                                onChange={(e) => setTargetUserId(e.target.value)}
                                required={!isBroadcast}
                                disabled={usersLoading}
                                className="w-full border p-2 rounded focus:ring-2 focus:ring-blue-500 bg-white"
                            >
                                <option value="">
                                    {usersLoading ? 'جاري تحميل المستخدمين...' : 'اختر مستخدماً واحداً'}
                                </option>
                                {selectableUsers.map((user) => (
                                    <option key={user.id} value={user.id}>
                                        {user.name} - {user.email} ({user.role})
                                    </option>
                                ))}
                            </select>
                        </div>
                    )}

                    <button
                        type="submit"
                        disabled={isSubmitting || (!isBroadcast && !targetUserId)}
                        className="w-full bg-blue-600 text-white py-2 px-4 rounded hover:bg-blue-700 disabled:opacity-50"
                    >
                        {isSubmitting ? 'جاري الإرسال...' : 'إرسال الإشعار'}
                    </button>
                </form>
            </div>
        </div>
    );
}
