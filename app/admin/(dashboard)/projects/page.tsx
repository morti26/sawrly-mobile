import ProjectsTable from '@/components/admin/ProjectsTable';

export default function AdminProjectsPage() {
    return (
        <div>
            <h2 className="text-2xl font-bold mb-4 text-right">إدارة المشاريع</h2>
            <div className="bg-white p-6 rounded shadow">
                <ProjectsTable />
            </div>
        </div>
    );
}
