import OffersTable from '@/components/admin/OffersTable';

export default function AdminOffersPage() {
    return (
        <div>
            <h2 className="text-2xl font-bold mb-4 text-right">إدارة العروض</h2>
            <div className="bg-white p-6 rounded shadow">
                <OffersTable />
            </div>
        </div>
    );
}
