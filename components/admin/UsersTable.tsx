'use client';

import { useCallback, useEffect, useState } from 'react';

interface User {
    id: string;
    name: string;
    email: string;
    role: string;
    phone: string | null;
    created_at: string;
    project_count: string;
    frozen_until?: string | null;
    is_frozen?: boolean;
}

interface UsersTableProps {
    role?: 'creator' | 'client' | 'admin' | 'moderator';
}

type ManagedRole = 'creator' | 'client' | 'admin' | 'moderator';

export default function UsersTable({ role }: UsersTableProps) {
    const [users, setUsers] = useState<User[]>([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);

    const [isModalOpen, setIsModalOpen] = useState(false);
    const [isEditing, setIsEditing] = useState(false);
    const [currentUserId, setCurrentUserId] = useState<string | null>(null);

    const [name, setName] = useState('');
    const [email, setEmail] = useState('');
    const [phone, setPhone] = useState('');
    const [password, setPassword] = useState('');
    const [selectedRole, setSelectedRole] = useState<ManagedRole>(role || 'client');
    const [currentAdminRole, setCurrentAdminRole] = useState<string | null>(null);
    const [freezeDialog, setFreezeDialog] = useState<{ mode: 'freeze' | 'unfreeze'; user: User } | null>(null);
    const [freezeDaysInput, setFreezeDaysInput] = useState('3');
    const [freezeActionError, setFreezeActionError] = useState<string | null>(null);
    const [isFreezeActionLoading, setIsFreezeActionLoading] = useState(false);
    const [deleteDialogUser, setDeleteDialogUser] = useState<User | null>(null);
    const [deleteActionError, setDeleteActionError] = useState<string | null>(null);
    const [isDeleteActionLoading, setIsDeleteActionLoading] = useState(false);
    const [formError, setFormError] = useState<string | null>(null);

    const canManageUsers = currentAdminRole === 'admin';

    const fetchUsers = useCallback(async () => {
        try {
            setLoading(true);
            setError(null);

            let url = '/api/admin/users';
            if (role) {
                url += `?role=${role}`;
            }

            const res = await fetch(url, {
                headers: {
                    Authorization: `Bearer ${localStorage.getItem('token')}`,
                },
            });

            if (!res.ok) {
                if (res.status === 401 || res.status === 403) {
                    throw new Error('Unauthorized. Please login again.');
                }
                throw new Error('Failed to fetch users');
            }

            const data = await res.json();
            setUsers(Array.isArray(data) ? data : []);
        } catch (err) {
            setError(err instanceof Error ? err.message : 'An error occurred');
        } finally {
            setLoading(false);
        }
    }, [role]);

    useEffect(() => {
        void fetchUsers();
    }, [fetchUsers]);

    useEffect(() => {
        try {
            const rawUser = localStorage.getItem('user');
            if (!rawUser) return;
            const parsed = JSON.parse(rawUser);
            if (parsed?.role) {
                setCurrentAdminRole(String(parsed.role));
            }
        } catch {
            setCurrentAdminRole(null);
        }
    }, []);

    const handleAddClick = () => {
        setIsEditing(false);
        setCurrentUserId(null);
        setName('');
        setEmail('');
        setPhone('');
        setPassword('');
        setSelectedRole(role || 'client');
        setFormError(null);
        setIsModalOpen(true);
    };

    const handleEditClick = (user: User) => {
        setIsEditing(true);
        setCurrentUserId(user.id);
        setName(user.name);
        setEmail(user.email);
        setPhone(user.phone || '');
        setPassword('');
        setSelectedRole((user.role as ManagedRole) || (role || 'client'));
        setFormError(null);
        setIsModalOpen(true);
    };

    const closeDeleteDialog = () => {
        if (isDeleteActionLoading) return;
        setDeleteDialogUser(null);
        setDeleteActionError(null);
    };

    const handleDelete = (user: User) => {
        setDeleteDialogUser(user);
        setDeleteActionError(null);
    };

    const submitDeleteAction = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!deleteDialogUser) return;

        setIsDeleteActionLoading(true);
        setDeleteActionError(null);
        try {
            const res = await fetch(`/api/admin/users/${deleteDialogUser.id}`, {
                method: 'DELETE',
                headers: {
                    Authorization: `Bearer ${localStorage.getItem('token')}`,
                },
            });

            if (res.ok) {
                closeDeleteDialog();
                await fetchUsers();
            } else {
                const data = await res.json().catch(() => ({}));
                setDeleteActionError(data.error || 'فشل في عملية الحذف');
            }
        } catch {
            setDeleteActionError('حدث خطأ أثناء الحذف');
        } finally {
            setIsDeleteActionLoading(false);
        }
    };

    const closeFreezeDialog = () => {
        if (isFreezeActionLoading) return;
        setFreezeDialog(null);
        setFreezeDaysInput('3');
        setFreezeActionError(null);
    };

    const handleFreeze = (user: User) => {
        setFreezeDialog({ mode: 'freeze', user });
        setFreezeDaysInput('3');
        setFreezeActionError(null);
    };

    const handleUnfreeze = (user: User) => {
        setFreezeDialog({ mode: 'unfreeze', user });
        setFreezeActionError(null);
    };

    const submitFreezeAction = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!freezeDialog) return;

        const isFreezeMode = freezeDialog.mode === 'freeze';
        let freezeDays = 0;
        if (isFreezeMode) {
            freezeDays = Number(freezeDaysInput.trim());
            if (!Number.isInteger(freezeDays) || freezeDays <= 0) {
                setFreezeActionError('أدخل عدد أيام صحيح أكبر من صفر');
                return;
            }
        }

        setIsFreezeActionLoading(true);
        setFreezeActionError(null);
        try {
            const res = await fetch(`/api/admin/users/${freezeDialog.user.id}`, {
                method: 'PUT',
                headers: {
                    'Content-Type': 'application/json',
                    Authorization: `Bearer ${localStorage.getItem('token')}`,
                },
                body: JSON.stringify(
                    isFreezeMode
                        ? { freezeDays }
                        : { clearFreeze: true }
                ),
            });

            if (res.ok) {
                closeFreezeDialog();
                await fetchUsers();
            } else {
                const data = await res.json().catch(() => ({}));
                setFreezeActionError(
                    data.error || (isFreezeMode ? 'فشل في تجميد المبدع' : 'فشل في إلغاء التجميد')
                );
            }
        } catch {
            setFreezeActionError(
                isFreezeMode ? 'حدث خطأ أثناء التجميد' : 'حدث خطأ أثناء إلغاء التجميد'
            );
        } finally {
            setIsFreezeActionLoading(false);
        }
    };

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        setFormError(null);

        try {
            const url = isEditing ? `/api/admin/users/${currentUserId}` : '/api/admin/users';
            const method = isEditing ? 'PUT' : 'POST';

            const trimmedPassword = password.trim();
            const payload: Record<string, unknown> = { name, phone };
            if (!isEditing) {
                payload.email = email;
                payload.password = trimmedPassword;
                payload.role = role || selectedRole;
            } else if (trimmedPassword) {
                payload.password = trimmedPassword;
            }

            const res = await fetch(url, {
                method,
                headers: {
                    'Content-Type': 'application/json',
                    Authorization: `Bearer ${localStorage.getItem('token')}`,
                },
                body: JSON.stringify(payload),
            });

            if (res.ok) {
                setIsModalOpen(false);
                await fetchUsers();
            } else {
                const data = await res.json().catch(() => ({}));
                setFormError(data.error || 'فشل في حفظ المستخدم');
            }
        } catch {
            setFormError('حدث خطأ أثناء الحفظ');
        }
    };

    const getAddLabel = () => {
        if (role === 'creator') return 'مبدع';
        if (role === 'admin') return 'مدير';
        if (role === 'moderator') return 'مراقب';
        return 'مستخدم';
    };

    const getRoleBadgeClass = (userRole: string) => {
        if (userRole === 'creator') return 'bg-purple-100 text-purple-700';
        if (userRole === 'admin') return 'bg-red-100 text-red-700';
        if (userRole === 'moderator') return 'bg-amber-100 text-amber-700';
        return 'bg-blue-100 text-blue-700';
    };

    const getRoleLabel = (userRole: string) => {
        if (userRole === 'creator') return 'مبدع';
        if (userRole === 'client') return 'عميل';
        if (userRole === 'admin') return 'مدير';
        if (userRole === 'moderator') return 'مراقب';
        return userRole;
    };

    if (loading) {
        return <div className="p-4 text-center">جاري التحميل...</div>;
    }

    if (error) {
        return <div className="rounded bg-red-50 p-4 text-red-500">Error: {error}</div>;
    }

    return (
        <div dir="rtl">
            <div className="mb-6 flex items-center justify-between">
                {canManageUsers ? (
                    <button
                        onClick={handleAddClick}
                        className="flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2 font-medium text-white shadow-sm shadow-blue-500/30 transition-all hover:bg-blue-700"
                    >
                        <svg className="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M12 4v16m8-8H4" />
                        </svg>
                        إضافة {getAddLabel()}
                    </button>
                ) : (
                    <div className="text-sm font-medium text-slate-500">عرض فقط للمراقب</div>
                )}
            </div>

            <div className="overflow-x-auto rounded-lg border border-slate-200 shadow-sm">
                <table className="min-w-full bg-white text-sm">
                    <thead>
                        <tr className="border-b border-slate-200 bg-slate-50">
                            <th className="px-6 py-4 text-right font-semibold text-slate-600">الاسم</th>
                            <th className="px-6 py-4 text-right font-semibold text-slate-600">البريد</th>
                            <th className="px-6 py-4 text-right font-semibold text-slate-600">الدور</th>
                            <th className="px-6 py-4 text-right font-semibold text-slate-600">المشاريع</th>
                            <th className="px-6 py-4 text-right font-semibold text-slate-600">تاريخ الانضمام</th>
                            <th className="px-6 py-4 text-center font-semibold text-slate-600">الإجراءات</th>
                        </tr>
                    </thead>
                    <tbody className="divide-y divide-slate-100">
                        {users.map((user) => (
                            <tr key={user.id} className="transition-colors hover:bg-slate-50">
                                <td className="px-6 py-4 text-right font-medium text-slate-800">{user.name}</td>
                                <td className="px-6 py-4 text-right font-mono text-xs text-slate-500" dir="ltr">{user.email}</td>
                                <td className="px-6 py-4 text-right">
                                    <span className={`inline-flex items-center rounded-full px-3 py-1 text-xs font-bold ${getRoleBadgeClass(user.role)}`}>
                                        {getRoleLabel(user.role)}
                                    </span>
                                    {user.role === 'creator' && (
                                        <div className={`mt-2 text-xs font-medium ${user.is_frozen ? 'text-red-600' : 'text-emerald-600'}`}>
                                            {user.is_frozen && user.frozen_until
                                                ? `مجمد حتى ${new Date(user.frozen_until).toLocaleDateString('ar-IQ')}`
                                                : 'نشط'}
                                        </div>
                                    )}
                                </td>
                                <td className="px-6 py-4 text-right font-medium text-slate-600">{user.project_count}</td>
                                <td className="px-6 py-4 text-right text-slate-500">
                                    {new Date(user.created_at).toLocaleDateString('ar-IQ')}
                                </td>
                                <td className="px-6 py-4 text-center">
                                    {canManageUsers ? (
                                        <div className="flex items-center justify-center gap-3">
                                            <button
                                                onClick={() => handleEditClick(user)}
                                                className="rounded-md px-3 py-1.5 font-medium text-blue-600 transition-colors hover:bg-blue-50 hover:text-blue-800"
                                            >
                                                تعديل
                                            </button>
                                            {user.role === 'creator' && (
                                                user.is_frozen ? (
                                                    <button
                                                        onClick={() => handleUnfreeze(user)}
                                                        className="rounded-md px-3 py-1.5 font-medium text-emerald-600 transition-colors hover:bg-emerald-50 hover:text-emerald-700"
                                                    >
                                                        إلغاء التجميد
                                                    </button>
                                                ) : (
                                                    <button
                                                        onClick={() => handleFreeze(user)}
                                                        className="rounded-md px-3 py-1.5 font-medium text-amber-600 transition-colors hover:bg-amber-50 hover:text-amber-700"
                                                    >
                                                        تجميد
                                                    </button>
                                                )
                                            )}
                                            <button
                                                onClick={() => handleDelete(user)}
                                                className="rounded-md px-3 py-1.5 font-medium text-red-500 transition-colors hover:bg-red-50 hover:text-red-700"
                                            >
                                                حذف
                                            </button>
                                        </div>
                                    ) : (
                                        <span className="text-slate-400">لا يوجد</span>
                                    )}
                                </td>
                            </tr>
                        ))}
                        {users.length === 0 && (
                            <tr>
                                <td colSpan={6} className="py-12 text-center font-medium text-slate-500">
                                    لا يوجد مستخدمين.
                                </td>
                            </tr>
                        )}
                    </tbody>
                </table>
            </div>

            {isModalOpen && (
                <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/50 p-4 backdrop-blur-sm">
                    <div className="w-full max-w-md overflow-hidden rounded-2xl bg-white shadow-xl">
                        <div className="flex items-center justify-between border-b border-slate-100 p-6">
                            <h3 className="text-xl font-bold text-slate-800">
                                {isEditing ? 'تعديل المستخدم' : `إضافة ${getAddLabel()} جديد`}
                            </h3>
                            <button
                                onClick={() => setIsModalOpen(false)}
                                className="text-slate-400 transition-colors hover:text-slate-600"
                            >
                                <svg className="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M6 18L18 6M6 6l12 12" />
                                </svg>
                            </button>
                        </div>
                        <div className="p-6">
                            <form onSubmit={handleSubmit} className="space-y-4">
                                <div>
                                    <label className="mb-1 block text-sm font-medium text-slate-700">الاسم الكامل</label>
                                    <input
                                        type="text"
                                        required
                                        value={name}
                                        onChange={(e) => setName(e.target.value)}
                                        className="w-full rounded-lg border-2 border-slate-200 p-2.5 transition-all focus:border-blue-500 focus:outline-none focus:ring-4 focus:ring-blue-500/10"
                                    />
                                </div>

                                {!isEditing && (
                                    <>
                                        {!role && (
                                            <div>
                                                <label className="mb-1 block text-sm font-medium text-slate-700">الدور</label>
                                                <select
                                                    value={selectedRole}
                                                    onChange={(e) => setSelectedRole(e.target.value as ManagedRole)}
                                                    className="w-full rounded-lg border-2 border-slate-200 p-2.5 transition-all focus:border-blue-500 focus:outline-none focus:ring-4 focus:ring-blue-500/10"
                                                >
                                                    <option value="client">عميل</option>
                                                    <option value="creator">مبدع</option>
                                                    <option value="moderator">مراقب</option>
                                                    <option value="admin">مدير</option>
                                                </select>
                                            </div>
                                        )}
                                        <div>
                                            <label className="mb-1 block text-sm font-medium text-slate-700">البريد الإلكتروني</label>
                                            <input
                                                type="email"
                                                required
                                                value={email}
                                                onChange={(e) => setEmail(e.target.value)}
                                                className="w-full rounded-lg border-2 border-slate-200 p-2.5 text-left transition-all focus:border-blue-500 focus:outline-none focus:ring-4 focus:ring-blue-500/10"
                                                dir="ltr"
                                            />
                                        </div>
                                    </>
                                )}

                                <div>
                                    <label className="mb-1 block text-sm font-medium text-slate-700">
                                        {isEditing ? 'كلمة المرور الجديدة (اختياري)' : 'كلمة المرور'}
                                    </label>
                                    <input
                                        type="password"
                                        required={!isEditing}
                                        value={password}
                                        onChange={(e) => setPassword(e.target.value)}
                                        className="w-full rounded-lg border-2 border-slate-200 p-2.5 text-left transition-all focus:border-blue-500 focus:outline-none focus:ring-4 focus:ring-blue-500/10"
                                        dir="ltr"
                                        placeholder={isEditing ? 'اتركها فارغة بدون تغيير' : ''}
                                    />
                                </div>

                                <div>
                                    <label className="mb-1 block text-sm font-medium text-slate-700">رقم الهاتف (اختياري)</label>
                                    <input
                                        type="tel"
                                        value={phone}
                                        onChange={(e) => setPhone(e.target.value)}
                                        className="w-full rounded-lg border-2 border-slate-200 p-2.5 text-left transition-all focus:border-blue-500 focus:outline-none focus:ring-4 focus:ring-blue-500/10"
                                        dir="ltr"
                                    />
                                </div>

                                {formError && (
                                    <div className="rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">
                                        {formError}
                                    </div>
                                )}

                                <div className="mt-8 flex gap-3">
                                    <button
                                        type="submit"
                                        className="flex-1 rounded-lg bg-blue-600 py-3 font-bold text-white shadow-md shadow-blue-500/20 transition-all hover:bg-blue-700"
                                    >
                                        حفظ البيانات
                                    </button>
                                    <button
                                        type="button"
                                        onClick={() => setIsModalOpen(false)}
                                        className="flex-1 rounded-lg bg-slate-100 py-3 font-bold text-slate-700 transition-all hover:bg-slate-200"
                                    >
                                        إلغاء
                                    </button>
                                </div>
                            </form>
                        </div>
                    </div>
                </div>
            )}

            {freezeDialog && (
                <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/50 p-4 backdrop-blur-sm">
                    <div className="w-full max-w-md overflow-hidden rounded-2xl bg-white shadow-xl">
                        <div className="border-b border-slate-100 p-6">
                            <h3 className="text-xl font-bold text-slate-800">
                                {freezeDialog.mode === 'freeze' ? 'تجميد المبدع' : 'إلغاء تجميد المبدع'}
                            </h3>
                            <p className="mt-1 text-sm text-slate-500">
                                {freezeDialog.user.name}
                            </p>
                        </div>

                        <form onSubmit={submitFreezeAction} className="space-y-4 p-6">
                            {freezeDialog.mode === 'freeze' ? (
                                <div>
                                    <label className="mb-1 block text-sm font-medium text-slate-700">
                                        كم عدد الأيام لتجميد هذا المبدع؟
                                    </label>
                                    <input
                                        type="number"
                                        min={1}
                                        max={365}
                                        value={freezeDaysInput}
                                        onChange={(e) => setFreezeDaysInput(e.target.value)}
                                        className="w-full rounded-lg border-2 border-slate-200 p-2.5 transition-all focus:border-amber-500 focus:outline-none focus:ring-4 focus:ring-amber-500/10"
                                    />
                                </div>
                            ) : (
                                <p className="text-sm text-slate-700">
                                    هل تريد إلغاء تجميد هذا المبدع الآن؟
                                </p>
                            )}

                            {freezeActionError && (
                                <div className="rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">
                                    {freezeActionError}
                                </div>
                            )}

                            <div className="mt-6 flex gap-3">
                                <button
                                    type="submit"
                                    disabled={isFreezeActionLoading}
                                    className={`flex-1 rounded-lg py-3 font-bold text-white shadow-md transition-all ${freezeDialog.mode === 'freeze'
                                        ? 'bg-amber-600 shadow-amber-500/20 hover:bg-amber-700'
                                        : 'bg-emerald-600 shadow-emerald-500/20 hover:bg-emerald-700'
                                        } disabled:cursor-not-allowed disabled:opacity-60`}
                                >
                                    {isFreezeActionLoading
                                        ? 'جاري المعالجة...'
                                        : (freezeDialog.mode === 'freeze' ? 'تأكيد التجميد' : 'تأكيد إلغاء التجميد')}
                                </button>
                                <button
                                    type="button"
                                    onClick={closeFreezeDialog}
                                    disabled={isFreezeActionLoading}
                                    className="flex-1 rounded-lg bg-slate-100 py-3 font-bold text-slate-700 transition-all hover:bg-slate-200 disabled:cursor-not-allowed disabled:opacity-60"
                                >
                                    إلغاء
                                </button>
                            </div>
                        </form>
                    </div>
                </div>
            )}

            {deleteDialogUser && (
                <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/50 p-4 backdrop-blur-sm">
                    <div className="w-full max-w-md overflow-hidden rounded-2xl bg-white shadow-xl">
                        <div className="border-b border-slate-100 p-6">
                            <h3 className="text-xl font-bold text-red-700">تأكيد حذف المستخدم</h3>
                            <p className="mt-1 text-sm text-slate-500">{deleteDialogUser.name}</p>
                        </div>

                        <form onSubmit={submitDeleteAction} className="space-y-4 p-6">
                            <p className="text-sm text-slate-700">
                                هل أنت متأكد من حذف هذا المستخدم؟ لا يمكن التراجع عن هذه العملية.
                            </p>

                            {deleteActionError && (
                                <div className="rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">
                                    {deleteActionError}
                                </div>
                            )}

                            <div className="mt-6 flex gap-3">
                                <button
                                    type="submit"
                                    disabled={isDeleteActionLoading}
                                    className="flex-1 rounded-lg bg-red-600 py-3 font-bold text-white shadow-md shadow-red-500/20 transition-all hover:bg-red-700 disabled:cursor-not-allowed disabled:opacity-60"
                                >
                                    {isDeleteActionLoading ? 'جاري الحذف...' : 'تأكيد الحذف'}
                                </button>
                                <button
                                    type="button"
                                    onClick={closeDeleteDialog}
                                    disabled={isDeleteActionLoading}
                                    className="flex-1 rounded-lg bg-slate-100 py-3 font-bold text-slate-700 transition-all hover:bg-slate-200 disabled:cursor-not-allowed disabled:opacity-60"
                                >
                                    إلغاء
                                </button>
                            </div>
                        </form>
                    </div>
                </div>
            )}
        </div>
    );
}
