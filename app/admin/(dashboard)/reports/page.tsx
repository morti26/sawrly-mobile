"use client";

import NextImage from 'next/image';
import { useEffect, useMemo, useState } from "react";

type ReportStatus = "pending" | "in_review" | "resolved" | "rejected";

interface MediaReport {
    id: string;
    media_id: string | null;
    reason: string;
    details: string | null;
    status: ReportStatus;
    admin_note: string | null;
    handled_at: string | null;
    created_at: string;
    updated_at: string;
    media_url: string | null;
    media_type: "image" | "video" | null;
    media_caption: string | null;
    creator_id: string | null;
    creator_name: string | null;
    reporter_name: string;
    reporter_role: string;
    handled_by_name: string | null;
}

const statusLabels: Record<ReportStatus, string> = {
    pending: "قيد الانتظار",
    in_review: "قيد المراجعة",
    resolved: "تم الحل",
    rejected: "مرفوض",
};

const statusClasses: Record<ReportStatus, string> = {
    pending: "bg-amber-100 text-amber-800 border-amber-300",
    in_review: "bg-blue-100 text-blue-800 border-blue-300",
    resolved: "bg-green-100 text-green-800 border-green-300",
    rejected: "bg-red-100 text-red-800 border-red-300",
};

export default function AdminReportsPage() {
    const [reports, setReports] = useState<MediaReport[]>([]);
    const [loading, setLoading] = useState(true);
    const [updatingId, setUpdatingId] = useState<string | null>(null);
    const [filter, setFilter] = useState<"all" | ReportStatus>("all");
    const [notes, setNotes] = useState<Record<string, string>>({});
    const [error, setError] = useState<string | null>(null);

    const counts = useMemo(() => {
        const data = { all: reports.length, pending: 0, in_review: 0, resolved: 0, rejected: 0 };
        for (const report of reports) {
            data[report.status] += 1;
        }
        return data;
    }, [reports]);

    const fetchReports = async () => {
        setLoading(true);
        setError(null);
        try {
            const token = localStorage.getItem("token");
            const query = filter === "all" ? "" : `?status=${filter}`;
            const res = await fetch(`/api/admin/reports${query}`, {
                headers: { Authorization: `Bearer ${token}` },
            });
            if (!res.ok) {
                const data = await res.json().catch(() => ({}));
                throw new Error(data?.error || "تعذر تحميل البلاغات");
            }
            const data = await res.json();
            setReports(data);
            setNotes((prev) => {
                const next = { ...prev };
                for (const report of data as MediaReport[]) {
                    if (next[report.id] === undefined && report.admin_note) {
                        next[report.id] = report.admin_note;
                    }
                }
                return next;
            });
        } catch (e: any) {
            setError(e?.message || "تعذر تحميل البلاغات");
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        void fetchReports();
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [filter]);

    const updateStatus = async (
        report: MediaReport,
        status: ReportStatus,
        removeMedia = false,
    ) => {
        try {
            setUpdatingId(report.id);
            setError(null);
            const token = localStorage.getItem("token");
            const res = await fetch("/api/admin/reports", {
                method: "PUT",
                headers: {
                    "Content-Type": "application/json",
                    Authorization: `Bearer ${token}`,
                },
                body: JSON.stringify({
                    id: report.id,
                    status,
                    adminNote: (notes[report.id] || "").trim(),
                    removeMedia,
                }),
            });
            if (!res.ok) {
                const data = await res.json().catch(() => ({}));
                throw new Error(data?.error || "تعذر تحديث البلاغ");
            }
            await fetchReports();
        } catch (e: any) {
            setError(e?.message || "تعذر تحديث البلاغ");
        } finally {
            setUpdatingId(null);
        }
    };

    return (
        <div className="space-y-6" dir="rtl">
            <div className="flex items-center justify-between">
                <div>
                    <h1 className="text-3xl font-bold text-gray-900">بلاغات الوسائط</h1>
                    <p className="text-gray-600">راجع بلاغات المستخدمين على صور وفيديوهات المبدعين من هنا.</p>
                </div>
                <button
                    onClick={fetchReports}
                    className="px-4 py-2 rounded bg-black text-white hover:bg-gray-800"
                >
                    تحديث
                </button>
            </div>

            <div className="grid grid-cols-2 md:grid-cols-5 gap-3">
                <button
                    onClick={() => setFilter("all")}
                    className={`rounded border px-3 py-2 text-sm ${filter === "all" ? "bg-black text-white border-black" : "bg-white text-gray-700 border-gray-300"}`}
                >
                    الكل ({counts.all})
                </button>
                {(["pending", "in_review", "resolved", "rejected"] as ReportStatus[]).map((status) => (
                    <button
                        key={status}
                        onClick={() => setFilter(status)}
                        className={`rounded border px-3 py-2 text-sm ${filter === status ? "bg-black text-white border-black" : "bg-white text-gray-700 border-gray-300"}`}
                    >
                        {statusLabels[status]} ({counts[status]})
                    </button>
                ))}
            </div>

            {error && (
                <div className="rounded border border-red-300 bg-red-50 text-red-700 px-4 py-3">
                    {error}
                </div>
            )}

            {loading ? (
                <div className="rounded border bg-white p-8 text-center text-gray-500">جاري تحميل البلاغات...</div>
            ) : reports.length === 0 ? (
                <div className="rounded border bg-white p-8 text-center text-gray-500">لا توجد بلاغات حالياً.</div>
            ) : (
                <div className="space-y-4">
                    {reports.map((report) => {
                        const isUpdating = updatingId === report.id;
                        return (
                            <div key={report.id} className="rounded-lg border bg-white p-4 shadow-sm">
                                <div className="flex items-start justify-between gap-4">
                                    <div className="flex items-center gap-3">
                                        <span className={`text-xs px-2 py-1 rounded border ${statusClasses[report.status]}`}>
                                            {statusLabels[report.status]}
                                        </span>
                                        <span className="text-xs text-gray-500">
                                            {new Date(report.created_at).toLocaleString("ar-IQ")}
                                        </span>
                                    </div>
                                    <span className="text-xs text-gray-400 font-mono" dir="ltr">{report.id}</span>
                                </div>

                                <div className="mt-4 grid grid-cols-1 lg:grid-cols-3 gap-4">
                                    <div className="rounded border bg-gray-50 overflow-hidden min-h-[180px]">
                                        {!report.media_url ? (
                                            <div className="h-full flex items-center justify-center text-sm text-gray-500 p-4">
                                                الوسائط غير متاحة حالياً
                                            </div>
                                        ) : report.media_type === "video" ? (
                                            <video src={report.media_url} controls className="w-full h-full object-cover" />
                                        ) : (
                                            <NextImage
                                                src={report.media_url}
                                                alt="الوسائط المبلغ عنها"
                                                width={640}
                                                height={360}
                                                className="h-full w-full object-cover"
                                                unoptimized
                                            />
                                        )}
                                    </div>

                                    <div className="lg:col-span-2 space-y-3">
                                        <div className="grid grid-cols-1 md:grid-cols-2 gap-3 text-sm">
                                            <div className="rounded border p-3 bg-gray-50">
                                                <div className="text-gray-500 text-xs mb-1">المبلِّغ</div>
                                                <div className="font-semibold">{report.reporter_name}</div>
                                                <div className="text-gray-600">{report.reporter_role}</div>
                                            </div>
                                            <div className="rounded border p-3 bg-gray-50">
                                                <div className="text-gray-500 text-xs mb-1">المبدع</div>
                                                <div className="font-semibold">{report.creator_name || "غير معروف"}</div>
                                                <div className="text-gray-600">
                                                    {report.media_type === "video" ? "منشور فيديو" : "منشور صورة"}
                                                </div>
                                            </div>
                                        </div>

                                        <div className="rounded border p-3">
                                            <div className="text-xs text-gray-500 mb-1">سبب البلاغ</div>
                                            <div className="font-medium text-gray-900">{report.reason}</div>
                                            {report.details && (
                                                <div className="mt-2 text-sm text-gray-700 whitespace-pre-wrap">{report.details}</div>
                                            )}
                                            {report.media_caption && (
                                                <div className="mt-2 text-xs text-gray-500">الوصف: {report.media_caption}</div>
                                            )}
                                        </div>

                                        <textarea
                                            value={notes[report.id] ?? ""}
                                            onChange={(e) => setNotes((prev) => ({ ...prev, [report.id]: e.target.value }))}
                                            placeholder="ملاحظة الإدارة..."
                                            className="w-full border rounded p-2 text-sm"
                                            rows={2}
                                        />

                                        <div className="flex flex-wrap gap-2">
                                            <button
                                                disabled={isUpdating}
                                                onClick={() => updateStatus(report, "in_review")}
                                                className="px-3 py-2 rounded bg-blue-600 text-white text-sm disabled:opacity-50"
                                            >
                                                قيد المراجعة
                                            </button>
                                            <button
                                                disabled={isUpdating}
                                                onClick={() => updateStatus(report, "resolved")}
                                                className="px-3 py-2 rounded bg-green-600 text-white text-sm disabled:opacity-50"
                                            >
                                                حل البلاغ
                                            </button>
                                            <button
                                                disabled={isUpdating}
                                                onClick={() => updateStatus(report, "rejected")}
                                                className="px-3 py-2 rounded bg-gray-700 text-white text-sm disabled:opacity-50"
                                            >
                                                رفض البلاغ
                                            </button>
                                            <button
                                                disabled={isUpdating || !report.media_id}
                                                onClick={() => {
                                                    const ok = window.confirm("هل تريد حذف الوسائط وإنهاء البلاغ؟");
                                                    if (ok) {
                                                        void updateStatus(report, "resolved", true);
                                                    }
                                                }}
                                                className="px-3 py-2 rounded bg-red-600 text-white text-sm disabled:opacity-50"
                                            >
                                                حل + حذف الوسائط
                                            </button>
                                        </div>

                                        {(report.handled_by_name || report.handled_at) && (
                                            <div className="text-xs text-gray-500">
                                                تمت المعالجة بواسطة {report.handled_by_name || "الإدارة"} بتاريخ{" "}
                                                {report.handled_at ? new Date(report.handled_at).toLocaleString("ar-IQ") : "-"}
                                            </div>
                                        )}
                                    </div>
                                </div>
                            </div>
                        );
                    })}
                </div>
            )}
        </div>
    );
}
