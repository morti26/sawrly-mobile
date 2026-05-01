"use client";

import { useEffect, useRef, useState } from 'react';
import { Send } from 'lucide-react';

interface ChatUser {
    user_id: string;
    user_name: string;
    user_phone: string;
    user_role: string;
    last_message_time: string;
    message_count: string;
}

interface SupportMessage {
    id: string;
    user_id: string;
    sender_type: 'user' | 'admin';
    content: string;
    created_at: string;
}

export default function SupportChatPage() {
    const [users, setUsers] = useState<ChatUser[]>([]);
    const [selectedUser, setSelectedUser] = useState<ChatUser | null>(null);
    const [messages, setMessages] = useState<SupportMessage[]>([]);
    const [newMessage, setNewMessage] = useState('');
    const [isLoadingUsers, setIsLoadingUsers] = useState(true);
    const [isLoadingMessages, setIsLoadingMessages] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const messagesEndRef = useRef<HTMLDivElement>(null);

    const scrollToBottom = () => {
        setTimeout(() => {
            messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
        }, 100);
    };

    const fetchJson = async <T,>(url: string): Promise<T> => {
        const token = localStorage.getItem('token');
        const res = await fetch(url, {
            headers: {
                Authorization: `Bearer ${token}`,
                Accept: 'application/json',
            },
            cache: 'no-store',
        });

        if (!res.ok) {
            const data = await res.json().catch(() => ({}));
            throw new Error(data?.error || 'تعذر تحميل بيانات الدعم');
        }

        return (await res.json()) as T;
    };

    useEffect(() => {
        let isMounted = true;
        setError(null);
        setIsLoadingUsers(true);

        const loadUsers = async () => {
            try {
                const data = await fetchJson<ChatUser[]>('/api/admin/support');
                if (!isMounted) {
                    return;
                }
                setUsers(Array.isArray(data) ? data : []);
                setIsLoadingUsers(false);
            } catch (streamError) {
                if (!isMounted) {
                    return;
                }
                setError(streamError instanceof Error ? streamError.message : 'تعذر تحميل المحادثات');
                setIsLoadingUsers(false);
            }
        };

        void loadUsers();
        const interval = setInterval(() => {
            void loadUsers();
        }, 3000);

        return () => {
            isMounted = false;
            clearInterval(interval);
        };
    }, []);

    useEffect(() => {
        if (!selectedUser) {
            setMessages([]);
            setIsLoadingMessages(false);
            return undefined;
        }

        let isMounted = true;
        setError(null);
        setIsLoadingMessages(true);

        const loadMessages = async () => {
            try {
                const data = await fetchJson<SupportMessage[]>(
                    `/api/admin/support?userId=${selectedUser.user_id}`
                );
                if (!isMounted) {
                    return;
                }
                setMessages(Array.isArray(data) ? data : []);
                setIsLoadingMessages(false);
            } catch (streamError) {
                if (!isMounted) {
                    return;
                }
                setError(streamError instanceof Error ? streamError.message : 'تعذر تحميل الرسائل');
                setIsLoadingMessages(false);
            }
        };

        void loadMessages();
        const interval = setInterval(() => {
            void loadMessages();
        }, 3000);

        return () => {
            isMounted = false;
            clearInterval(interval);
        };
    }, [selectedUser]);

    useEffect(() => {
        if (messages.length > 0) {
            scrollToBottom();
        }
    }, [messages.length]);

    const handleSendMessage = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!newMessage.trim() || !selectedUser) {
            return;
        }

        try {
            setError(null);
            const token = localStorage.getItem('token');
            const res = await fetch('/api/admin/support', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    Authorization: `Bearer ${token}`,
                },
                body: JSON.stringify({
                    userId: selectedUser.user_id,
                    content: newMessage,
                }),
            });

            if (!res.ok) {
                const data = await res.json().catch(() => ({}));
                throw new Error(data?.error || 'تعذر إرسال الرسالة');
            }

            const msg = await res.json();
            setMessages((prev) => [...prev, msg]);
            setNewMessage('');
            scrollToBottom();
        } catch (sendError) {
            setError(sendError instanceof Error ? sendError.message : 'تعذر إرسال الرسالة');
        }
    };

    return (
        <div className="flex h-full bg-white rounded-lg shadow overflow-hidden">
            <div className="w-1/3 border-l border-gray-200 flex flex-col">
                <div className="p-4 border-b border-gray-200 bg-gray-50">
                    <h2 className="text-lg font-semibold text-gray-800">المحادثات</h2>
                </div>
                <div className="flex-1 overflow-y-auto">
                    {isLoadingUsers ? (
                        <div className="p-4 text-center text-gray-500">جاري تحميل المحادثات...</div>
                    ) : users.length === 0 ? (
                        <div className="p-4 text-center text-gray-500">لا توجد رسائل دعم حالياً</div>
                    ) : (
                        users.map((user) => (
                            <button
                                key={user.user_id}
                                onClick={() => setSelectedUser(user)}
                                className={`w-full text-right p-4 border-b border-gray-100 hover:bg-blue-50 transition-colors ${selectedUser?.user_id === user.user_id ? 'bg-blue-100 border-r-4 border-blue-600' : ''
                                    }`}
                            >
                                <div className="font-semibold text-gray-800">{user.user_name}</div>
                                <div className="text-sm text-gray-500 mt-1">{user.user_phone || 'بدون رقم'}</div>
                                <div className="flex justify-between items-center mt-2">
                                    <span className="text-xs bg-gray-200 text-gray-700 px-2 py-1 rounded">
                                        {user.user_role === 'creator' ? 'مبدع' : 'عميل'}
                                    </span>
                                    <span className="text-xs text-gray-400">
                                        {new Date(user.last_message_time).toLocaleDateString('ar-IQ')}
                                    </span>
                                </div>
                            </button>
                        ))
                    )}
                </div>
            </div>

            <div className="flex-1 flex flex-col bg-gray-50">
                {error && (
                    <div className="mx-4 mt-4 rounded border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
                        {error}
                    </div>
                )}
                {selectedUser ? (
                    <>
                        <div className="p-4 border-b border-gray-200 bg-white flex justify-between items-center">
                            <h3 className="text-lg font-semibold text-gray-800">{selectedUser.user_name}</h3>
                            <span className="text-sm text-gray-500 font-mono" dir="ltr">{selectedUser.user_phone || '-'}</span>
                        </div>

                        <div className="flex-1 overflow-y-auto p-4 space-y-4">
                            {isLoadingMessages && messages.length === 0 ? (
                                <div className="text-center text-gray-500">جاري تحميل الرسائل...</div>
                            ) : (
                                messages.map((msg) => {
                                    const isAdmin = msg.sender_type === 'admin';
                                    return (
                                        <div key={msg.id} className={`flex flex-col ${isAdmin ? 'items-end' : 'items-start'}`}>
                                            <div className={`max-w-[70%] rounded-lg p-3 ${isAdmin ? 'bg-blue-600 text-white rounded-tl-none' : 'bg-white text-gray-800 rounded-tr-none shadow-sm'}`}>
                                                <p className="text-sm">{msg.content}</p>
                                            </div>
                                            <span className="text-xs text-gray-400 mt-1">
                                                {new Date(msg.created_at).toLocaleTimeString('ar-IQ', { hour: '2-digit', minute: '2-digit' })}
                                            </span>
                                        </div>
                                    );
                                })
                            )}
                            <div ref={messagesEndRef} />
                        </div>

                        <div className="p-4 bg-white border-t border-gray-200">
                            <form onSubmit={handleSendMessage} className="flex gap-2">
                                <input
                                    type="text"
                                    value={newMessage}
                                    onChange={(e) => setNewMessage(e.target.value)}
                                    placeholder="اكتب رسالة للمستخدم..."
                                    className="flex-1 p-3 border border-gray-300 rounded-lg focus:outline-none focus:border-blue-500"
                                    dir="rtl"
                                />
                                <button
                                    type="submit"
                                    disabled={!newMessage.trim()}
                                    className="bg-blue-600 text-white p-3 rounded-lg hover:bg-blue-700 disabled:opacity-50 transition-colors"
                                >
                                    <Send size={20} className="transform rotate-180" />
                                </button>
                            </form>
                        </div>
                    </>
                ) : (
                    <div className="flex-1 flex items-center justify-center text-gray-500 flex-col gap-4">
                        <svg className="w-16 h-16 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
                        </svg>
                        <p className="text-lg">اختر محادثة لبدء الدردشة</p>
                    </div>
                )}
            </div>
        </div>
    );
}
