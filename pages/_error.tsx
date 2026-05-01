import type { NextPageContext } from 'next';

type ErrorPageProps = {
    statusCode?: number;
};

function ErrorPage({ statusCode }: ErrorPageProps) {
    return (
        <div
            style={{
                minHeight: '100vh',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                fontFamily: 'sans-serif',
                background: '#f8fafc',
                color: '#111827',
            }}
        >
            <div style={{ textAlign: 'center' }}>
                <h1 style={{ fontSize: 28, marginBottom: 8 }}>حدث خطأ</h1>
                <p style={{ fontSize: 14, opacity: 0.8 }}>
                    {statusCode ? `Error ${statusCode}` : 'Unexpected error'}
                </p>
            </div>
        </div>
    );
}

ErrorPage.getInitialProps = ({ res, err }: NextPageContext) => {
    const statusCode = res?.statusCode ?? err?.statusCode ?? 500;
    return { statusCode };
};

export default ErrorPage;
