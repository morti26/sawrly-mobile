import AuditLogsTable from '@/components/admin/AuditLogsTable';

export default function AdminAuditLogsPage() {
    return (
        <div>
            <h2 className="mb-4 text-right text-2xl font-bold">سجل التدقيق</h2>
            <div className="rounded bg-white p-6 shadow">
                <AuditLogsTable />
            </div>
        </div>
    );
}
