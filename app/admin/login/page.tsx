"use client";

import { useState } from "react";

export default function AdminLogin() {
    const [email, setEmail] = useState("");
    const [password, setPassword] = useState("");
    const [error, setError] = useState("");

    const handleLogin = async (e: React.FormEvent) => {
        e.preventDefault();
        setError("");

        const form = e.currentTarget as HTMLFormElement;
        const formData = new FormData(form);
        const submittedEmail = String(formData.get("email") ?? "").trim();
        const submittedPassword = String(formData.get("password") ?? "");

        setEmail(submittedEmail);
        setPassword(submittedPassword);

        try {
            const res = await fetch("/api/auth/login", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                credentials: "same-origin",
                body: JSON.stringify({
                    email: submittedEmail,
                    password: submittedPassword,
                }),
            });

            const raw = await res.text();
            let data: any = {};

            try {
                data = raw ? JSON.parse(raw) : {};
            } catch {
                data = {
                    error:
                        res.status === 401
                            ? "Invalid credentials"
                            : res.status === 403
                                ? "Access denied"
                                : "Login failed",
                };
            }

            if (!res.ok) {
                throw new Error(data.error || "Login failed");
            }

            if (!["admin", "moderator"].includes(data.user.role)) {
                throw new Error("Access denied. Admin or moderator only.");
            }

            // Also store in LS if needed for API calls
            localStorage.setItem("token", data.token);
            localStorage.setItem("user", JSON.stringify(data.user));

            window.location.assign("/admin/dashboard");
        } catch (err: any) {
            setError(err.message);
        }
    };

    return (
        <div className="min-h-screen flex items-center justify-center bg-gray-100 text-gray-900">
            <div className="bg-white p-8 rounded shadow-md w-96">
                <h1 className="text-2xl font-bold mb-6 text-center text-gray-900">تسجيل دخول صورلي</h1>
                {error && <div className="bg-red-100 text-red-700 p-2 mb-4 rounded text-sm">{error}</div>}
                <form onSubmit={handleLogin} method="post" className="space-y-4">
                    <div>
                        <label className="block text-sm font-medium mb-1 text-gray-700">البريد الإلكتروني</label>
                        <input
                            className="w-full p-2 border border-gray-300 rounded text-right text-gray-900 bg-white"
                            type="email"
                            name="email"
                            autoComplete="email"
                            value={email}
                            onChange={(e) => setEmail(e.target.value)}
                            required
                        />
                    </div>
                    <div>
                        <label className="block text-sm font-medium mb-1 text-gray-700">كلمة المرور</label>
                        <input
                            className="w-full p-2 border border-gray-300 rounded text-right text-gray-900 bg-white"
                            type="password"
                            name="password"
                            autoComplete="current-password"
                            value={password}
                            onChange={(e) => setPassword(e.target.value)}
                            required
                        />
                    </div>
                    <button
                        type="submit"
                        className="w-full bg-black text-white p-2 rounded hover:bg-gray-800 transition shadow-sm"
                    >
                        دخول
                    </button>
                </form>
            </div>
        </div>
    );
}
