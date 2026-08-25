import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../core/auth/auth_service.dart';
import '../../core/services/support_service.dart';
import '../../core/theme/app_theme_service.dart';
import '../../core/localization/app_locale_service.dart';

class SupportChatScreen extends StatefulWidget {
  const SupportChatScreen({super.key});

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _connectSupportStream();
  }

  void _connectSupportStream() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<SupportService>().connectMessageStream().then((_) {
          _scrollToBottom();
        });
      }
    });
  }

  @override
  void dispose() {
    context.read<SupportService>().disconnectMessageStream();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    final success = await context.read<SupportService>().sendMessage(text);
    if (success) {
      _scrollToBottom();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(tr('فشل إرسال الرسالة', 'Failed to send message'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final supportService = context.watch<SupportService>();
    context.watch<AppLocaleService>();
    final isGuest = context.watch<AuthService>().currentUser == null;

    if (isGuest) {
      return Scaffold(
        appBar: AppBar(title: Text(tr('الدعم', 'Support'))),
        body: Center(
            child: Text(tr('يرجى تسجيل الدخول للتحدث مع الدعم',
                'Please log in to chat with support'))),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('الدعم', 'Support')),
        elevation: 1,
      ),
      body: supportService.isLoading && supportService.messages.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: supportService.messages.length,
                    itemBuilder: (context, index) {
                      final message = supportService.messages[index];
                      final isMe = message.senderType == 'user';

                      return _buildMessageBubble(message, isMe);
                    },
                  ),
                ),
                _buildMessageInput(),
              ],
            ),
    );
  }

  Widget _buildMessageBubble(SupportMessage message, bool isMe) {
    final colors = context.watch<AppThemeService>().colors;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? colors.primary : colors.surfaceLight,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(16),
          ),
        ),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message.content,
              style: TextStyle(
                color: isMe ? colors.textPrimary : colors.textPrimary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('HH:mm').format(message.createdAt),
              style: TextStyle(
                color: isMe
                    ? colors.textPrimary.withValues(alpha: 0.72)
                    : colors.textSecondary,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    final colors = context.watch<AppThemeService>().colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: colors.background.withValues(alpha: 0.12),
            offset: const Offset(0, -2),
            blurRadius: 4,
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                textDirection: TextDirection.rtl,
                decoration: InputDecoration(
                  hintText: tr('اكتب رسالتك...', 'Type your message...'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: colors.surfaceLight.withValues(alpha: 0.45),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: colors.primary,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(Icons.send, color: colors.textPrimary),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
