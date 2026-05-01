'use client';

import { useEffect, useState } from 'react';

interface ProjectRow {
    id: string;
    quote_id: string;
    status: 'in_progress' | 'completed' | 'cancelled';
    started_at: string;
    completed_at: string | null;
    created_at: string;
    offer_title: string | null;
    creator_name: string | null;
    client_name: string | null;
    latest_delivery_status: string | null;
    latest_delivery_url: string | null;
    confirmed_payment_count: number;
}

const statusClassMap: Record<ProjectRow['status'], string> = {
    in_progress: 'bg-blue-100 text-blue-700',
    completed: 'bg-green-100 text-green-700',
    cancelled: 'bg-red-100 text-red-700',
};

export default function ProjectsTable() {
    const [projects, setProjects] = useState<ProjectRow[]>([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);
    const [actionId, setActionId] = useState<string | null>(null);

    const fetchProjects = async () => {
        try {
            setLoading(true);
            setError(null);

            const token = localStorage.getItem('token');
            const res = await fetch('/api/admin/projects', {
                headers: { Authorization: `Bearer ${token}` },
            });

            const data = await res.json();
            if (!res.ok) {
                throw new Error(data?.error || 'Failed to fetch projects');
            }

            setProjects(Array.isArray(data) ? data : []);
        } catch (err) {
            setError(err instanceof Error ? err.message : 'حدث خطأ غير متوقع');
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        fetchProjects();
    }, []);

    const updateProjectStatus = async (projectId: string, newStatus: 'completed' | 'cancelled') => {
        try {
            setActionId(projectId);
            setError(null);

            const token = localStorage.getItem('token');
            const res = await fetch('/api/projects', {
                method: 'PATCH',
                headers: {
                    'Content-Type': 'application/json',
                    Authorization: `Bearer ${token}`,
                },
                body: JSON.stringify({ projectId, newStatus }),
            });
            const data = await res.json();

            if (!res.ok) {
                throw new Error(data?.error || 'فشل تحديث حالة المشروع');
            }

            await fetchProjects();
        } catch (err) {
            setError(err instanceof Error ? err.message : 'حدث خطأ غير متوقع');
        } finally {
            setActionId(null);
        }
    };

    if (loading) {
        return <div className="p-4 text-center">جاري تحميل المشاريع...</div>;
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
                            <th className="py-4 px-4 text-right font-semibold text-slate-600">الحالة</th>
                            <th className="py-4 px-4 text-right font-semibold text-slate-600">الدفعات المؤكدة</th>
                            <th className="py-4 px-4 text-right font-semibold text-slate-600">آخر تسليم</th>
                            <th className="py-4 px-4 text-right font-semibold text-slate-600">البداية</th>
                            <th className="py-4 px-4 text-right font-semibold text-slate-600">الانتهاء</th>
                            <th className="py-4 px-4 text-center font-semibold text-slate-600">الإجراءات</th>
                        </tr>
                    </thead>
                    <tbody className="divide-y divide-slate-100">
                        {projects.map((project) => (
                            <tr key={project.id} className="hover:bg-slate-50 transition-colors">
                                <td className="py-4 px-4 text-right">
                                    <div className="font-medium text-slate-800">{project.offer_title || 'بدون عنوان'}</div>
                                    <div className="text-xs text-slate-400 font-mono" dir="ltr">{project.quote_id}</div>
                                </td>
                                <td className="py-4 px-4 text-right text-slate-700">{project.creator_name || '-'}</td>
                                <td className="py-4 px-4 text-right text-slate-700">{project.client_name || '-'}</td>
                                <td className="py-4 px-4 text-right">
                                    <span className={`inline-flex rounded-full px-3 py-1 text-xs font-bold ${statusClassMap[project.status]}`}>
                                        {project.status}
                                    </span>
                                </td>
                                <td className="py-4 px-4 text-right font-semibold text-slate-700">
                                    {Number(project.confirmed_payment_count || 0)}
                                </td>
                                <td className="py-4 px-4 text-right">
                                    {project.latest_delivery_status ? (
                                        <div>
                                            <div className="font-medium text-slate-700">{project.latest_delivery_status}</div>
                                            {project.latest_delivery_url && (
                                                <a
                                                    href={project.latest_delivery_url}
                                                    target="_blank"
                                                    rel="noreferrer"
                                                    className="text-xs text-blue-600 hover:underline"
                                                >
                                                    فتح التسليم
                                                </a>
                                            )}
                                        </div>
                                    ) : (
                                        <span className="text-slate-400">لا يوجد</span>
                                    )}
                                </td>
                                <td className="py-4 px-4 text-right text-slate-500">
                                    {new Date(project.started_at).toLocaleDateString('ar-IQ')}
                                </td>
                                <td className="py-4 px-4 text-right text-slate-500">
                                    {project.completed_at
                                        ? new Date(project.completed_at).toLocaleDateString('ar-IQ')
                                        : '-'}
                                </td>
                                <td className="py-4 px-4 text-center">
                                    {project.status === 'in_progress' ? (
                                        <div className="flex items-center justify-center gap-2">
                                            <button
                                                onClick={() => updateProjectStatus(project.id, 'completed')}
                                                disabled={actionId === project.id}
                                                className="rounded-md bg-green-600 px-3 py-1.5 text-white hover:bg-green-700 disabled:opacity-50"
                                            >
                                                إنهاء
                                            </button>
                                            <button
                                                onClick={() => updateProjectStatus(project.id, 'cancelled')}
                                                disabled={actionId === project.id}
                                                className="rounded-md bg-red-100 px-3 py-1.5 text-red-700 hover:bg-red-200 disabled:opacity-50"
                                            >
                                                إلغاء
                                            </button>
                                        </div>
                                    ) : (
                                        <span className="text-slate-400">لا يوجد</span>
                                    )}
                                </td>
                            </tr>
                        ))}
                        {projects.length === 0 && (
                            <tr>
                                <td colSpan={9} className="py-12 text-center text-slate-500 font-medium">
                                    لا توجد مشاريع حالياً.
                                </td>
                            </tr>
                        )}
                    </tbody>
                </table>
            </div>
        </div>
    );
}
