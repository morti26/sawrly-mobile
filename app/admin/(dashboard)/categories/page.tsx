"use client";

import NextImage from 'next/image';
import { useState, useEffect } from 'react';

interface Category {
    id: string;
    title: string;
    image_url: string;
    is_active: boolean;
    sort_order: number;
    created_at: string;
}

export default function CategoriesPage() {
    const [categories, setCategories] = useState<Category[]>([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState('');

    // Form states
    const [isEditing, setIsEditing] = useState(false);
    const [currentId, setCurrentId] = useState<string | null>(null);
    const [title, setTitle] = useState('');
    const [imageUrl, setImageUrl] = useState('');
    const [isActive, setIsActive] = useState(true);
    const [sortOrder, setSortOrder] = useState('0');

    // Upload state
    const [uploading, setUploading] = useState(false);

    useEffect(() => {
        fetchCategories();
    }, []);

    const fetchCategories = async () => {
        try {
            setLoading(true);
            const token = localStorage.getItem('token');
            const res = await fetch('/api/categories', {
                headers: { Authorization: `Bearer ${token}` }
            });
            if (res.ok) {
                const data = await res.json();
                setCategories(data);
            } else {
                setError('Failed to load categories');
            }
        } catch (err) {
            setError('Error loading categories');
        } finally {
            setLoading(false);
        }
    };

    const handleUploadImage = async (e: React.ChangeEvent<HTMLInputElement>) => {
        if (!e.target.files || e.target.files.length === 0) return;

        try {
            setUploading(true);
            const file = e.target.files[0];
            const formData = new FormData();
            formData.append('file', file);

            const token = localStorage.getItem('token');
            const res = await fetch('/api/upload', {
                method: 'POST',
                headers: { Authorization: `Bearer ${token}` },
                body: formData,
            });

            if (res.ok) {
                const data = await res.json();
                setImageUrl(data.url);
            } else {
                alert('Upload failed');
            }
        } catch (err) {
            console.error('Upload error', err);
            alert('Upload error');
        } finally {
            setUploading(false);
        }
    };

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        try {
            const token = localStorage.getItem('token');
            const method = isEditing ? 'PUT' : 'POST';
            const url = isEditing ? `/api/categories/${currentId}` : '/api/categories';

            const res = await fetch(url, {
                method,
                headers: {
                    'Content-Type': 'application/json',
                    Authorization: `Bearer ${token}`
                },
                body: JSON.stringify({
                    title,
                    image_url: imageUrl,
                    is_active: isActive,
                    sort_order: parseInt(sortOrder) || 0
                })
            });

            if (res.ok) {
                resetForm();
                fetchCategories();
            } else {
                alert('Failed to save category');
            }
        } catch (err) {
            console.error('Save error', err);
            alert('Save error');
        }
    };

    const handleEdit = (cat: Category) => {
        setIsEditing(true);
        setCurrentId(cat.id);
        setTitle(cat.title);
        setImageUrl(cat.image_url);
        setIsActive(cat.is_active);
        setSortOrder(cat.sort_order.toString());
    };

    const handleDelete = async (id: string) => {
        if (!confirm('Are you sure you want to delete this category?')) return;
        try {
            const token = localStorage.getItem('token');
            const res = await fetch(`/api/categories/${id}`, {
                method: 'DELETE',
                headers: { Authorization: `Bearer ${token}` }
            });
            if (res.ok) {
                fetchCategories();
            } else {
                alert('Failed to delete category');
            }
        } catch (err) {
            console.error('Delete error', err);
            alert('Delete error');
        }
    };

    const resetForm = () => {
        setIsEditing(false);
        setCurrentId(null);
        setTitle('');
        setImageUrl('');
        setIsActive(true);
        setSortOrder('0');
    };

    if (loading) return <div>Loading...</div>;

    return (
        <div dir="rtl" className="space-y-8 pb-12">
            <div className="flex justify-between items-center bg-white p-6 rounded-2xl shadow-sm border border-slate-100">
                <h1 className="text-3xl font-black text-slate-800 tracking-tight">المتجر</h1>
                <p className="text-slate-500 font-medium">أضف ونظم عناصر المتجر بكل سهولة</p>
            </div>

            {error && <div className="bg-red-50 text-red-600 p-4 border border-red-200 rounded-xl font-medium shadow-sm">{error}</div>}

            <div className="bg-white p-8 rounded-2xl shadow-sm border border-slate-100">
                <h2 className="text-2xl font-bold mb-6 text-slate-800 border-b border-slate-100 pb-4">
                    {isEditing ? 'تعديل قسم' : 'إضافة قسم جديد'}
                </h2>
                <form onSubmit={handleSubmit} className="space-y-6">
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
                        <div>
                            <label className="block mb-2 font-medium text-slate-700">عنوان القسم</label>
                            <input
                                type="text"
                                required
                                value={title}
                                onChange={(e) => setTitle(e.target.value)}
                                className="w-full border-2 border-slate-200 focus:border-blue-500 focus:ring-4 focus:ring-blue-500/10 transition-all p-3 rounded-xl bg-slate-50 focus:bg-white outline-none"
                            />
                        </div>
                        <div>
                            <label className="block mb-2 font-medium text-slate-700">الترتيب</label>
                            <input
                                type="number"
                                value={sortOrder}
                                onChange={(e) => setSortOrder(e.target.value)}
                                className="w-full border-2 border-slate-200 focus:border-blue-500 focus:ring-4 focus:ring-blue-500/10 transition-all p-3 rounded-xl bg-slate-50 focus:bg-white outline-none"
                            />
                        </div>
                        <div className="col-span-1 md:col-span-2">
                            <label className="block mb-2 font-medium text-slate-700">الصورة</label>
                            <div className="flex gap-3">
                                <label className="bg-slate-900 text-white px-6 py-3 rounded-xl cursor-pointer hover:bg-slate-800 transition-colors shadow-md hover:shadow-lg flex items-center gap-2 font-medium shrink-0">
                                    {uploading ? (
                                        <span className="flex items-center gap-2">
                                            <svg className="animate-spin h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24"><circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle><path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path></svg>
                                            جاري الرفع...
                                        </span>
                                    ) : (
                                        <>صورة جديدة (+)</>
                                    )}
                                    <input
                                        type="file"
                                        accept="image/*"
                                        onChange={handleUploadImage}
                                        className="hidden"
                                    />
                                </label>
                                <input
                                    type="text"
                                    readOnly
                                    value={imageUrl}
                                    placeholder="سيظهر الرابط هنا بعد الرفع..." // Image URL
                                    className="w-full border-2 border-slate-200 p-3 rounded-xl bg-slate-100 text-slate-500 outline-none"
                                />
                            </div>
                            {imageUrl && (
                                <div className="mt-4 p-2 bg-slate-50 rounded-xl border border-slate-100 inline-block shadow-sm">
                                    <NextImage
                                        src={imageUrl}
                                        alt="preview"
                                        width={112}
                                        height={112}
                                        className="h-28 w-28 rounded-lg object-contain bg-white"
                                        unoptimized
                                    />
                                </div>
                            )}
                        </div>
                        <div className="flex items-center pt-2">
                            <label className="flex items-center gap-3 cursor-pointer group">
                                <div className="relative flex items-center justify-center">
                                    <input
                                        type="checkbox"
                                        checked={isActive}
                                        onChange={(e) => setIsActive(e.target.checked)}
                                        className="peer sr-only"
                                    />
                                    <div className="w-12 h-6 bg-slate-300 peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-blue-300 rounded-full peer peer-checked:after:-translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:right-[2px] after:bg-white after:border-slate-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-blue-600"></div>
                                </div>
                                <span className="font-semibold text-slate-700 bg-slate-100 px-3 py-1 rounded-lg">نشط (يظهر في التطبيق)</span>
                            </label>
                        </div>
                    </div>

                    <div className="flex gap-4 pt-6 border-t border-slate-100">
                        <button type="submit" className="bg-green-500 text-white px-8 py-3 rounded-xl hover:bg-green-600 transition-colors shadow-md shadow-green-500/30 hover:shadow-lg font-bold text-lg flex items-center justify-center min-w-[150px]">
                            {isEditing ? 'تحديث القسم' : 'حفظ القسم'}
                        </button>
                        {isEditing && (
                            <button type="button" onClick={resetForm} className="bg-slate-200 text-slate-700 px-8 py-3 rounded-xl hover:bg-slate-300 transition-colors font-bold text-lg min-w-[120px]">
                                إلغاء
                            </button>
                        )}
                    </div>
                </form>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
                {categories.map((cat) => (
                    <div key={cat.id} className={`bg-white rounded-2xl shadow-sm border border-slate-100 overflow-hidden hover:shadow-md transition-shadow group flex flex-col ${!cat.is_active ? 'opacity-60 grayscale-[0.5]' : ''}`}>
                        <div className="h-48 bg-slate-100 relative p-4 flex items-center justify-center">
                            {cat.image_url ? (
                                <NextImage
                                    src={cat.image_url}
                                    alt={cat.title}
                                    fill
                                    className="object-cover rounded-xl shadow-sm"
                                    unoptimized
                                />
                            ) : (
                                <div className="flex flex-col items-center justify-center text-slate-400">
                                    <svg className="w-10 h-10 mb-2 opacity-50" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L28 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"></path></svg>
                                    <span className="text-sm font-medium">بدون صورة</span>
                                </div>
                            )}
                            {!cat.is_active && (
                                <div className="absolute top-4 right-4 bg-red-500/90 backdrop-blur-sm text-white px-3 py-1 rounded-full text-xs font-bold shadow-sm">
                                    غير نشط
                                </div>
                            )}
                        </div>
                        <div className="p-5 flex-1 flex flex-col">
                            <h3 className="font-bold text-xl text-slate-800 mb-1">{cat.title}</h3>
                            <div className="text-sm font-medium text-slate-500 bg-slate-100 inline-block px-2 py-1 rounded-md mb-4 self-start">الترتيب: {cat.sort_order}</div>

                            <div className="flex justify-between items-center mt-auto pt-4 border-t border-slate-100">
                                <button onClick={() => handleEdit(cat)} className="text-blue-600 hover:text-blue-800 hover:bg-blue-50 px-4 py-2 rounded-lg font-bold transition-colors flex items-center gap-2">
                                    تعديل
                                </button>
                                <button onClick={() => handleDelete(cat.id)} className="text-red-500 hover:text-red-700 hover:bg-red-50 px-4 py-2 rounded-lg font-bold transition-colors flex items-center gap-2">
                                    حذف
                                </button>
                            </div>
                        </div>
                    </div>
                ))}
            </div>
        </div>
    );
}
