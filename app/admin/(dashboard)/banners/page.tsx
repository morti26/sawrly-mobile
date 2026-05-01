"use client";

import NextImage from 'next/image';
import { useState, useEffect, useRef } from 'react';
import { Upload, Plus, Trash2, CheckCircle2, XCircle, Film, Image as ImageIcon, GripVertical } from 'lucide-react';

interface MediaItem {
    url: string;
    type: 'image' | 'video';
    // local-only: for preview before upload
    _previewUrl?: string;
    _file?: File;
}

interface Banner {
    id: number;
    image_url: string;
    link_url: string;
    title: string;
    is_active: boolean;
    media_items: MediaItem[];
    created_at: string;
}

export default function BannersManagementPage() {
    const maxMediaItems = 10;
    const [banners, setBanners] = useState<Banner[]>([]);
    const [isLoading, setIsLoading] = useState(true);
    const [isSubmitting, setIsSubmitting] = useState(false);

    // Form state
    const [showForm, setShowForm] = useState(false);
    const [title, setTitle] = useState('');
    const [linkUrl, setLinkUrl] = useState('');
    const [isActive, setIsActive] = useState(false);
    const [mediaItems, setMediaItems] = useState<MediaItem[]>([]);
    const fileInputRef = useRef<HTMLInputElement>(null);

    const fetchBanners = async () => {
        setIsLoading(true);
        try {
            const token = localStorage.getItem('token');
            const res = await fetch('/api/admin/banners', {
                headers: { 'Authorization': `Bearer ${token}` }
            });
            if (res.ok) {
                const data = await res.json();
                setBanners(data.map((b: Banner) => ({
                    ...b,
                    media_items: Array.isArray(b.media_items) && b.media_items.length > 0
                        ? b.media_items
                        : [{ url: b.image_url, type: 'image' }]
                })));
            }
        } catch (error) {
            console.error('Failed to fetch banners', error);
        } finally {
            setIsLoading(false);
        }
    };

    useEffect(() => { fetchBanners(); }, []);

    const handleFilesChange = (e: React.ChangeEvent<HTMLInputElement>) => {
        if (!e.target.files) return;
        const remainingSlots = Math.max(0, maxMediaItems - mediaItems.length);
        const selectedFiles = Array.from(e.target.files).slice(0, remainingSlots);
        const newItems: MediaItem[] = selectedFiles.map((file) => {
            const isVideo = file.type.startsWith('video/');
            return {
                url: '',
                type: isVideo ? 'video' : 'image',
                _previewUrl: URL.createObjectURL(file),
                _file: file,
            };
        });
        setMediaItems(prev => [...prev, ...newItems]);
        // Reset input so same file can be added again if needed
        e.target.value = '';
    };

    const removeMediaItem = (index: number) => {
        setMediaItems(prev => prev.filter((_, i) => i !== index));
    };

    const resetForm = () => {
        setShowForm(false);
        setTitle('');
        setLinkUrl('');
        setIsActive(false);
        setMediaItems([]);
    };

    const uploadFile = async (file: File, token: string): Promise<string> => {
        const formData = new FormData();
        formData.append('file', file);
        const uploadRes = await fetch('/api/upload?subDir=banners', {
            method: 'POST',
            headers: { 'Authorization': `Bearer ${token}` },
            body: formData,
        });
        if (!uploadRes.ok) throw new Error('Upload failed: ' + await uploadRes.text());
        const data = await uploadRes.json();
        return data.url as string;
    };

    const handleCreateBanner = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!title || mediaItems.length === 0) return;

        setIsSubmitting(true);
        try {
            const token = localStorage.getItem('token') ?? '';

            // Upload all pending files
            const resolvedItems: MediaItem[] = await Promise.all(
                mediaItems.map(async (item) => {
                    if (item._file) {
                        const url = await uploadFile(item._file, token);
                        return { url, type: item.type };
                    }
                    return { url: item.url, type: item.type };
                })
            );

            const res = await fetch('/api/admin/banners', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${token}`,
                },
                body: JSON.stringify({ title, link_url: linkUrl, is_active: isActive, media_items: resolvedItems }),
            });

            if (res.ok) {
                resetForm();
                fetchBanners();
            } else {
                alert('حدث خطأ أثناء حفظ الإعلان');
            }
        } catch (err) {
            console.error(err);
            alert('فشل رفع الملف أو حفظ الإعلان');
        } finally {
            setIsSubmitting(false);
        }
    };

    const toggleActiveStatus = async (bannerId: number, currentStatus: boolean) => {
        try {
            const token = localStorage.getItem('token');
            const res = await fetch('/api/admin/banners', {
                method: 'PUT',
                headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
                body: JSON.stringify({ id: bannerId, is_active: !currentStatus }),
            });
            if (res.ok) fetchBanners();
        } catch (error) {
            console.error('Failed to update banner status', error);
        }
    };

    const deleteBanner = async (bannerId: number) => {
        if (!confirm('هل أنت متأكد من حذف هذا الإعلان؟')) return;
        try {
            const token = localStorage.getItem('token');
            const res = await fetch(`/api/admin/banners?id=${bannerId}`, {
                method: 'DELETE',
                headers: { 'Authorization': `Bearer ${token}` },
            });
            if (res.ok) fetchBanners();
        } catch (error) {
            console.error('Failed to delete banner', error);
        }
    };

    return (
        <div className="space-y-6" dir="rtl">
            {/* Header */}
            <div className="flex justify-between items-center">
                <h1 className="text-2xl font-bold text-gray-800">إدارة الإعلانات (Banners)</h1>
                <button
                    onClick={() => { setShowForm(!showForm); if (showForm) resetForm(); }}
                    className="flex items-center gap-2 bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition"
                >
                    {showForm ? 'إلغاء' : (<><Plus size={20} />إضافة إعلان جديد</>)}
                </button>
            </div>

            {/* ── Create Form ── */}
            {showForm && (
                <div className="bg-white p-6 rounded-xl shadow-sm border border-gray-100">
                    <h2 className="text-lg font-semibold mb-4 border-b pb-2">تفاصيل الإعلان الجديد</h2>
                    <form onSubmit={handleCreateBanner} className="space-y-5 max-w-2xl">

                        {/* Title */}
                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-1">عنوان الإعلان (داخلي)</label>
                            <input
                                type="text" required value={title} onChange={e => setTitle(e.target.value)}
                                className="w-full p-2 border rounded-md"
                                placeholder="مثال: خصم 50% على جلسات التصوير"
                            />
                        </div>

                        {/* Link */}
                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-1">الرابط (اختياري)</label>
                            <input
                                type="url" value={linkUrl} onChange={e => setLinkUrl(e.target.value)}
                                className="w-full p-2 border rounded-md text-left"
                                placeholder="https://example.com/offer" dir="ltr"
                            />
                        </div>

                        {/* Media Items */}
                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-2">
                                الوسائط (صور وفيديوهات) — يمكن إضافة حتى {maxMediaItems} عناصر
                            </label>

                            {/* Added items preview */}
                            {mediaItems.length > 0 && (
                                <div className="grid grid-cols-3 gap-3 mb-3">
                                    {mediaItems.map((item, i) => (
                                        <div key={i} className="relative rounded-lg overflow-hidden border border-gray-200 bg-gray-50 aspect-video flex items-center justify-center">
                                            {item.type === 'video' ? (
                                                <div className="flex flex-col items-center gap-1 text-gray-500">
                                                    <Film size={28} />
                                                    <span className="text-xs">فيديو</span>
                                                    {item._previewUrl && (
                                                        <video src={item._previewUrl} className="absolute inset-0 w-full h-full object-cover opacity-40" muted />
                                                    )}
                                                </div>
                                            ) : (
                                                <NextImage
                                                    src={item._previewUrl || item.url}
                                                    alt={`slide ${i + 1}`}
                                                    fill
                                                    className="object-cover"
                                                    unoptimized
                                                />
                                            )}
                                            {/* Order badge */}
                                            <span className="absolute top-1 right-1 bg-black/60 text-white text-xs rounded-full w-5 h-5 flex items-center justify-center font-bold">
                                                {i + 1}
                                            </span>
                                            {/* Remove */}
                                            <button
                                                type="button"
                                                onClick={() => removeMediaItem(i)}
                                                className="absolute top-1 left-1 bg-red-500 text-white rounded-full p-0.5 hover:bg-red-600"
                                            >
                                                <XCircle size={16} />
                                            </button>
                                        </div>
                                    ))}
                                </div>
                            )}

                            {/* Upload button */}
                            {mediaItems.length < maxMediaItems && (
                                <div
                                    className="border-2 border-dashed border-blue-300 bg-blue-50 hover:bg-blue-100 rounded-lg p-6 text-center cursor-pointer transition"
                                    onClick={() => fileInputRef.current?.click()}
                                >
                                    <div className="flex flex-col items-center gap-1">
                                        <Upload className="text-blue-500" size={28} />
                                        <span className="text-sm font-medium text-blue-600">اختر صور أو فيديوهات</span>
                                        <span className="text-xs text-gray-500">JPG، PNG، MP4، MOV — حتى {maxMediaItems} عناصر</span>
                                    </div>
                                    <input
                                        type="file" ref={fileInputRef} multiple accept="image/*,video/*"
                                        onChange={handleFilesChange} className="hidden"
                                    />
                                </div>
                            )}
                        </div>

                        {/* Active checkbox */}
                        <div className="flex items-center gap-2">
                            <input type="checkbox" id="isActive" checked={isActive}
                                onChange={e => setIsActive(e.target.checked)}
                                className="w-5 h-5 text-blue-600 rounded"
                            />
                            <label htmlFor="isActive" className="text-gray-700 font-medium cursor-pointer">
                                تفعيل ونشر الآن (يمكن تفعيل عدة إعلانات كشرائح)
                            </label>
                        </div>

                        <div className="pt-4 border-t">
                            <button
                                type="submit"
                                disabled={isSubmitting || !title || mediaItems.length === 0}
                                className="bg-green-600 text-white px-6 py-2 rounded-lg hover:bg-green-700 disabled:opacity-50 transition"
                            >
                                {isSubmitting ? 'جاري الحفظ...' : 'حفظ ونشر'}
                            </button>
                        </div>
                    </form>
                </div>
            )}

            {/* ── Banner List ── */}
            <div className="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
                <div className="p-4 bg-gray-50 border-b">
                    <h3 className="font-semibold text-gray-700">الإعلانات</h3>
                </div>

                {isLoading ? (
                    <div className="p-8 text-center text-gray-500">جاري التحميل...</div>
                ) : banners.length === 0 ? (
                    <div className="p-8 text-center text-gray-500">لا توجد إعلانات حالياً</div>
                ) : (
                    <div className="divide-y divide-gray-100">
                        {banners.map((banner) => (
                            <div key={banner.id} className={`p-4 flex gap-4 ${banner.is_active ? 'bg-blue-50/50' : ''}`}>

                                {/* Slide thumbnails */}
                                <div className="flex gap-2 shrink-0">
                                    {(banner.media_items ?? []).slice(0, 3).map((item, i) => (
                                        <div key={i} className="w-20 h-14 rounded-lg overflow-hidden border border-gray-200 bg-gray-100 relative flex items-center justify-center">
                                            {item.type === 'video' ? (
                                                <div className="flex flex-col items-center text-gray-400">
                                                    <Film size={20} />
                                                    <span className="text-xs">فيديو</span>
                                                </div>
                                            ) : (
                                                <NextImage
                                                    src={item.url}
                                                    alt={banner.title}
                                                    fill
                                                    className="object-cover"
                                                    unoptimized
                                                />
                                            )}
                                            <span className="absolute bottom-0.5 right-0.5 bg-black/50 text-white text-[10px] rounded px-1">{i + 1}</span>
                                        </div>
                                    ))}
                                </div>

                                {/* Info */}
                                <div className="flex-1 flex flex-col justify-center min-w-0">
                                    <h4 className="text-base font-bold text-gray-800 truncate">{banner.title}</h4>
                                    <div className="flex items-center gap-2 mt-1 flex-wrap">
                                        <span className="text-xs text-gray-400 bg-gray-100 px-2 py-0.5 rounded-full">
                                            {(banner.media_items ?? []).length} عنصر
                                        </span>
                                        {(banner.media_items ?? []).some(m => m.type === 'video') && (
                                            <span className="text-xs text-purple-600 bg-purple-50 px-2 py-0.5 rounded-full flex items-center gap-1">
                                                <Film size={10} />فيديو
                                            </span>
                                        )}
                                    </div>
                                    {banner.link_url && (
                                        <a href={banner.link_url} target="_blank" rel="noreferrer"
                                            className="text-xs text-blue-500 hover:underline mt-1 truncate" dir="ltr">
                                            {banner.link_url}
                                        </a>
                                    )}
                                    <span className="text-xs text-gray-400 mt-1">
                                        {new Date(banner.created_at).toLocaleDateString('ar-IQ')}
                                    </span>
                                </div>

                                {/* Actions */}
                                <div className="flex flex-col items-center justify-center gap-2 shrink-0">
                                    {/* Toggle active */}
                                    <button
                                        onClick={() => toggleActiveStatus(banner.id, banner.is_active)}
                                        className={`flex flex-col items-center justify-center p-2 rounded-xl transition text-xs font-bold w-20 ${banner.is_active
                                            ? 'bg-green-100 text-green-700 hover:bg-green-200'
                                            : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
                                            }`}
                                    >
                                        {banner.is_active
                                            ? <><CheckCircle2 size={20} className="mb-0.5" /><span>نشط</span></>
                                            : <><XCircle size={20} className="mb-0.5" /><span>غير نشط</span></>
                                        }
                                    </button>

                                    {/* Delete */}
                                    <button
                                        onClick={() => deleteBanner(banner.id)}
                                        className="flex flex-col items-center justify-center p-2 rounded-xl bg-red-50 text-red-500 hover:bg-red-100 transition text-xs w-20"
                                    >
                                        <Trash2 size={18} className="mb-0.5" />
                                        <span>حذف</span>
                                    </button>
                                </div>
                            </div>
                        ))}
                    </div>
                )}
            </div>
        </div>
    );
}
