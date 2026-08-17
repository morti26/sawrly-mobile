import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/theme/app_theme_service.dart';
import 'package:provider/provider.dart';

class PaymentGatewayScreen extends StatefulWidget {
  final String checkoutUrl;

  const PaymentGatewayScreen({
    super.key,
    required this.checkoutUrl,
  });

  @override
  State<PaymentGatewayScreen> createState() => _PaymentGatewayScreenState();
}

class _PaymentGatewayScreenState extends State<PaymentGatewayScreen> {
  late final WebViewController _controller;
  int _loadingProgress = 0;
  bool _pageFailed = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0F1320))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (!mounted) return;
            setState(() {
              _loadingProgress = progress;
            });
          },
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _pageFailed = false;
              _errorText = null;
              _loadingProgress = 0;
            });
          },
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() {
              _loadingProgress = 100;
            });
          },
          onWebResourceError: (error) {
            if (!mounted) return;
            setState(() {
              _pageFailed = true;
              _errorText = error.description.trim().isEmpty
                  ? 'تعذر تحميل بوابة الدفع'
                  : error.description;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.checkoutUrl));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<AppThemeService>().colors;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: context.watch<AppThemeService>().colors.background,
        foregroundColor: context.watch<AppThemeService>().colors.textPrimary,
        centerTitle: true,
        title: const Text('بوابة الدفع'),
        actions: [
          IconButton(
            onPressed: () {
              _controller.reload();
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_loadingProgress < 100 && !_pageFailed)
            LinearProgressIndicator(
              value: _loadingProgress / 100,
              minHeight: 3,
              backgroundColor: colors.border.withValues(alpha: 0.18),
              color: colors.primary,
            ),
          Expanded(
            child: _pageFailed
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 56,
                            color: colors.textSecondary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _errorText ?? 'تعذر تحميل بوابة الدفع',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _pageFailed = false;
                                  _errorText = null;
                                  _loadingProgress = 0;
                                });
                                _controller.loadRequest(
                                  Uri.parse(widget.checkoutUrl),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colors.primary,
                                foregroundColor: colors.textPrimary,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: const Text('إعادة المحاولة'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : WebViewWidget(controller: _controller),
          ),
        ],
      ),
    );
  }
}
