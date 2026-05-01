import UsersTable from '@/components/admin/UsersTable';

export default function AdminUsersPage() {
    return (
        <div>
            <h2 className="text-2xl font-bold mb-4 text-right">إدارة المستخدمين (Manage Users)</h2>
            <div className="bg-white p-6 rounded shadow">
                <UsersTable />
            </div>
        </div>
    );
}
