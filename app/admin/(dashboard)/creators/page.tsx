import UsersTable from '@/components/admin/UsersTable';

export default function AdminCreatorsPage() {
    return (
        <div dir="rtl" className="space-y-6">
            <div className="flex justify-between items-center bg-white p-6 rounded-2xl shadow-sm border border-slate-100">
                <div>
                    <h1 className="text-3xl font-black text-slate-800 tracking-tight">إدارة المبدعين</h1>
                    <p className="text-slate-500 font-medium mt-1">إضافة، تعديل، وحذف حسابات المصورين والمبدعين</p>
                </div>
            </div>
            <div className="bg-white p-6 rounded-2xl shadow-sm border border-slate-100">
                <UsersTable role="creator" />
            </div>
        </div>
    );
}
