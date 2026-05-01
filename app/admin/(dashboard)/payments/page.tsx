import PaymentsTable from '@/components/admin/PaymentsTable';

export default function AdminPaymentsPage() {
    return (
        <div>
            <h2 className="text-2xl font-bold mb-4 text-right">إدارة المدفوعات</h2>
            <div className="bg-white p-6 rounded shadow">
                <PaymentsTable />
            </div>
        </div>
    );
}
