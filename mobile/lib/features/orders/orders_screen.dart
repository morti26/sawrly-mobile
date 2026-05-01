import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/auth/auth_service.dart';
import '../../core/network/api_client.dart';
import '../../core/services/cart_service.dart';

enum _OrdersTab { cart, quotes, payments, projects }

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  bool _isSubmitting = false;
  bool _isLoadingHistory = true;
  String? _historyError;
  String _paymentMethod = 'cash';
  List<_PaymentMethodOption> _paymentMethods = _PaymentMethodOption.defaults;
  int _selectedTabIndex = 0;
  List<_QuoteHistoryItem> _quotes = const [];
  List<_PaymentHistoryItem> _payments = const [];
  List<_ProjectHistoryItem> _projects = const [];
  String? _onlineActionPaymentId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _refreshHistory();
      }
    });
  }

  String _paymentMethodLabel(String method) {
    for (final option in _paymentMethods) {
      if (option.value == method) {
        return option.label;
      }
    }

    switch (method) {
      case 'bank_transfer':
        return 'تحويل بنكي';
      case 'wallet':
        return 'محفظة';
      case 'online':
        return 'دفع إلكتروني';
      case 'cash':
      default:
        return 'نقدي';
    }
  }

  String _paymentMethodHint(String method) {
    for (final option in _paymentMethods) {
      if (option.value == method) {
        return option.hint;
      }
    }
    return 'سيتم إنشاء الدفع المعلق، ثم يؤكده المبدع أو الأدمن لاحقاً.';
  }

  List<_PaymentMethodOption> _parsePaymentOptions(dynamic payload) {
    if (payload is! Map<String, dynamic>) {
      return _PaymentMethodOption.defaults;
    }

    final rawMethods = payload['methods'];
    if (rawMethods is! List) {
      return _PaymentMethodOption.defaults;
    }

    final options = rawMethods
        .whereType<Map>()
        .map((item) =>
            _PaymentMethodOption.fromJson(Map<String, dynamic>.from(item)))
        .where((item) => item.value.isNotEmpty && item.label.isNotEmpty)
        .toList();

    if (options.isEmpty) {
      return _PaymentMethodOption.defaults;
    }

    return options;
  }

  String _paymentStatusLabel(String status) {
    switch (status) {
      case 'confirmed':
        return 'مؤكد';
      case 'rejected':
        return 'مرفوض';
      case 'pending':
      default:
        return 'قيد المراجعة';
    }
  }

  String _gatewayStatusLabel(String status) {
    switch (status) {
      case 'confirmed':
      case 'success':
      case 'succeeded':
      case 'paid':
        return 'مكتمل';
      case 'rejected':
      case 'failed':
      case 'cancelled':
      case 'canceled':
        return 'فشل';
      case 'pending':
      case 'processing':
      default:
        return 'بانتظار الدفع';
    }
  }

  String _projectStatusLabel(String status) {
    switch (status) {
      case 'completed':
        return 'مكتمل';
      case 'cancelled':
        return 'ملغي';
      case 'in_progress':
      default:
        return 'قيد التنفيذ';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed':
      case 'completed':
        return Colors.green;
      case 'rejected':
      case 'cancelled':
        return Colors.red;
      case 'in_progress':
        return Colors.blue;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$year/$month/$day - $hour:$minute';
  }

  String _normalizeImageUrl(String? url) {
    final value = (url ?? '').trim();
    if (value.isEmpty) {
      return '';
    }
    if (value.startsWith('/')) {
      return 'https://ph.sitely24.com$value';
    }
    if (value.startsWith('http://ph.sitely24.com')) {
      return value.replaceFirst('http://', 'https://');
    }
    return value;
  }

  String? _extractGatewayCheckoutUrl(dynamic payload) {
    if (payload is! Map<String, dynamic>) {
      return null;
    }

    final directUrl = _normalizeOptionalText(payload['gatewayCheckoutUrl']);
    if (directUrl != null) {
      return directUrl;
    }

    final rawItems = payload['items'];
    if (rawItems is! List) {
      return null;
    }

    for (final item in rawItems.whereType<Map>()) {
      final parsed = Map<String, dynamic>.from(item);
      final itemUrl = _normalizeOptionalText(parsed['checkoutUrl']);
      if (itemUrl != null) {
        return itemUrl;
      }
    }

    return null;
  }

  Future<bool> _openExternalUrl(String url) async {
    final normalized = url.trim();
    if (normalized.isEmpty) {
      return false;
    }

    final uri = Uri.tryParse(normalized);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return false;
    }

    if (!await canLaunchUrl(uri)) {
      return false;
    }

    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _resumeOnlinePayment(_PaymentHistoryItem item) async {
    final messenger = ScaffoldMessenger.of(context);
    String? checkoutUrl = item.gatewayCheckoutUrl;
    if (checkoutUrl == null || checkoutUrl.isEmpty) {
      checkoutUrl = await _createOnlineCheckoutUrl(item);
      if (!mounted) {
        return;
      }
      if (checkoutUrl == null || checkoutUrl.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Unable to prepare online payment link'),
          ),
        );
        return;
      }
    }

    final launched = await _openExternalUrl(checkoutUrl);
    if (!mounted) {
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          launched
              ? 'تم فتح بوابة الدفع الإلكترونية'
              : 'تعذر فتح بوابة الدفع، حاول مرة أخرى',
        ),
      ),
    );
  }

  Future<String?> _createOnlineCheckoutUrl(_PaymentHistoryItem item) async {
    if (!mounted) {
      return null;
    }

    setState(() {
      _onlineActionPaymentId = item.id;
    });

    try {
      final apiClient = context.read<ApiClient>();
      final response =
          await apiClient.client.post('/payments/${item.id}/online-checkout');
      final payload = response.data;

      final checkoutUrl = payload is Map<String, dynamic>
          ? _normalizeOptionalText(
              payload['gatewayCheckoutUrl'] ?? payload['checkoutUrl'])
          : null;
      final gatewayStatus = payload is Map<String, dynamic>
          ? _normalizeOptionalText(payload['gatewayStatus']) ?? 'pending'
          : 'pending';

      if (checkoutUrl == null || checkoutUrl.isEmpty) {
        return null;
      }

      if (!mounted) {
        return checkoutUrl;
      }

      setState(() {
        _payments = _payments
            .map(
              (payment) => payment.id == item.id
                  ? payment.copyWith(
                      gatewayCheckoutUrl: checkoutUrl,
                      gatewayStatus: gatewayStatus,
                    )
                  : payment,
            )
            .toList();
      });

      return checkoutUrl;
    } on DioException catch (e) {
      if (!mounted) {
        return null;
      }

      final responseData = e.response?.data;
      final errorMessage = responseData is Map<String, dynamic>
          ? responseData['error']?.toString()
          : null;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage ?? 'Unable to prepare online payment link'),
        ),
      );
      return null;
    } catch (_) {
      return null;
    } finally {
      if (mounted) {
        setState(() {
          _onlineActionPaymentId = null;
        });
      }
    }
  }

  Future<void> _refreshHistory() async {
    final auth = context.read<AuthService>();
    if (!auth.isAuthenticated) {
      return;
    }

    final apiClient = context.read<ApiClient>();
    setState(() {
      _isLoadingHistory = true;
      _historyError = null;
    });

    try {
      final results = await Future.wait([
        apiClient.client.get('/quotes'),
        apiClient.client.get('/payments'),
        apiClient.client.get('/projects'),
      ]);

      List<_PaymentMethodOption> paymentMethods = _paymentMethods;
      try {
        final optionsRes = await apiClient.client.get('/payments/options');
        paymentMethods = _parsePaymentOptions(optionsRes.data);
      } catch (_) {
        paymentMethods = _paymentMethods.isEmpty
            ? _PaymentMethodOption.defaults
            : _paymentMethods;
      }

      final quotePayload = results[0].data;
      final paymentPayload = results[1].data;
      final projectPayload = results[2].data;

      final rawQuotes = quotePayload is Map<String, dynamic>
          ? (quotePayload['quotes'] as List<dynamic>? ?? const [])
          : const <dynamic>[];
      final rawPayments = paymentPayload is Map<String, dynamic>
          ? (paymentPayload['payments'] as List<dynamic>? ?? const [])
          : const <dynamic>[];
      final rawProjects = projectPayload is Map<String, dynamic>
          ? (projectPayload['projects'] as List<dynamic>? ?? const [])
          : const <dynamic>[];

      if (!mounted) {
        return;
      }

      setState(() {
        _quotes = rawQuotes
            .whereType<Map>()
            .map((item) =>
                _QuoteHistoryItem.fromJson(Map<String, dynamic>.from(item)))
            .toList();
        _payments = rawPayments
            .whereType<Map>()
            .map((item) =>
                _PaymentHistoryItem.fromJson(Map<String, dynamic>.from(item)))
            .toList();
        _projects = rawProjects
            .whereType<Map>()
            .map((item) =>
                _ProjectHistoryItem.fromJson(Map<String, dynamic>.from(item)))
            .toList();
        _paymentMethods = paymentMethods;
        if (!_paymentMethods.any((item) => item.value == _paymentMethod)) {
          _paymentMethod = _paymentMethods.first.value;
        }
        _isLoadingHistory = false;
      });
    } on DioException catch (e) {
      final responseData = e.response?.data;
      final errorMessage = responseData is Map<String, dynamic>
          ? responseData['error']?.toString()
          : null;

      if (!mounted) {
        return;
      }

      setState(() {
        _historyError = errorMessage ?? 'تعذر تحميل السجل الحالي';
        _isLoadingHistory = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _historyError = 'حدث خطأ غير متوقع أثناء تحميل السجل';
        _isLoadingHistory = false;
      });
    }
  }

  Future<void> _submitOrders(BuildContext context) async {
    final auth = context.read<AuthService>();
    final cart = context.read<CartService>();
    final apiClient = context.read<ApiClient>();
    final messenger = ScaffoldMessenger.of(context);
    final items = List.of(cart.items);

    if (items.isEmpty || _isSubmitting) {
      return;
    }

    if (!auth.isAuthenticated) {
      messenger.showSnackBar(
        const SnackBar(content: Text('يرجى تسجيل الدخول أولاً')),
      );
      return;
    }

    if (auth.isCreator) {
      messenger.showSnackBar(
        const SnackBar(content: Text('هذه الصفحة متاحة للعملاء فقط')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final response = await apiClient.client.post('/checkout', data: {
        'offerIds': items.map((item) => item.id).toList(),
        'paymentMethod': _paymentMethod,
      });

      final data = response.data;
      final createdCount = data is Map<String, dynamic>
          ? (data['quotesCount'] as num?)?.toInt() ?? items.length
          : items.length;
      final nextStep =
          data is Map<String, dynamic> ? data['nextStep']?.toString() : null;
      final gatewayCheckoutUrl = _extractGatewayCheckoutUrl(data);

      cart.clear();
      await _refreshHistory();
      if (!mounted) {
        return;
      }

      setState(() {
        _selectedTabIndex = _paymentMethod == 'online' ? 2 : 1;
      });

      if (_paymentMethod == 'online' &&
          gatewayCheckoutUrl != null &&
          gatewayCheckoutUrl.isNotEmpty) {
        final launched = await _openExternalUrl(gatewayCheckoutUrl);
        if (!mounted) {
          return;
        }
        if (!launched) {
          messenger.showSnackBar(
            const SnackBar(
              content:
                  Text('تعذر فتح بوابة الدفع، يمكن المحاولة من صفحة المدفوعات'),
            ),
          );
        }
      }

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            (nextStep != null && nextStep.trim().isNotEmpty)
                ? nextStep
                : 'تم إنشاء $createdCount طلب ودفع معلق بطريقة ${_paymentMethodLabel(_paymentMethod)}',
          ),
        ),
      );
    } on DioException catch (e) {
      final responseData = e.response?.data;
      final errorMessage = responseData is Map<String, dynamic>
          ? responseData['error']?.toString()
          : null;

      if (!mounted) {
        return;
      }

      messenger.showSnackBar(
        SnackBar(content: Text(errorMessage ?? 'فشل إرسال الطلبات')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      messenger.showSnackBar(
        const SnackBar(
          content: Text('حدث خطأ غير متوقع أثناء إرسال الطلبات'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _submitPaymentProof(_PaymentHistoryItem item) async {
    final auth = context.read<AuthService>();
    if (!auth.isAuthenticated || auth.isCreator) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final apiClient = context.read<ApiClient>();

    if (item.quoteId.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('لا يمكن إرسال الإثبات لهذا الدفع')),
      );
      return;
    }

    final controller = TextEditingController(text: item.proofUrl ?? '');
    try {
      final result = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('إثبات الدفع'),
            content: TextField(
              controller: controller,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'رابط الإثبات',
                hintText: 'https://...',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () =>
                    Navigator.of(dialogContext).pop(controller.text.trim()),
                child: const Text('حفظ'),
              ),
            ],
          );
        },
      );

      if (result == null) {
        return;
      }

      final proofUrl = result.trim();
      if (proofUrl.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('يرجى إدخال رابط إثبات الدفع')),
        );
        return;
      }

      await apiClient.client.post('/payments', data: {
        'quoteId': item.quoteId,
        'amount': item.amount,
        'method': item.method,
        'proofUrl': proofUrl,
      });

      await _refreshHistory();
      if (!mounted) {
        return;
      }

      messenger.showSnackBar(
        const SnackBar(content: Text('تم إرسال إثبات الدفع بنجاح')),
      );
    } on DioException catch (e) {
      final responseData = e.response?.data;
      final errorMessage = responseData is Map<String, dynamic>
          ? responseData['error']?.toString()
          : null;
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text(errorMessage ?? 'فشل إرسال إثبات الدفع')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('حدث خطأ غير متوقع أثناء إرسال الإثبات')),
      );
    } finally {
      controller.dispose();
    }
  }

  List<_OrdersTab> _availableTabs(bool isCreator) {
    if (isCreator) {
      return const [
        _OrdersTab.quotes,
        _OrdersTab.payments,
        _OrdersTab.projects,
      ];
    }
    return const [
      _OrdersTab.cart,
      _OrdersTab.quotes,
      _OrdersTab.payments,
      _OrdersTab.projects,
    ];
  }

  String _tabLabel(_OrdersTab tab) {
    switch (tab) {
      case _OrdersTab.cart:
        return 'السلة';
      case _OrdersTab.quotes:
        return 'الطلبات';
      case _OrdersTab.payments:
        return 'المدفوعات';
      case _OrdersTab.projects:
        return 'المشاريع';
    }
  }

  Widget _buildTabSelector(List<_OrdersTab> tabs) {
    final safeIndex = _selectedTabIndex >= tabs.length ? 0 : _selectedTabIndex;

    return SizedBox(
      height: 50,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final tab = tabs[index];
          final isSelected = index == safeIndex;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedTabIndex = index;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.white12,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.white24,
                ),
              ),
              child: Center(
                child: Text(
                  _tabLabel(tab),
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemCount: tabs.length,
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: 360,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 62, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey[400]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCartView() {
    final cart = context.watch<CartService>();
    final items = cart.items;

    if (items.isEmpty) {
      return _buildEmptyState(
        icon: Icons.shopping_cart_outlined,
        title: 'السلة فارغة',
        subtitle: 'أضف عرضاً أولاً ثم أرسل الطلب والدفع المعلق من هنا.',
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        item.imageUrl,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 60,
                          height: 60,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${item.price.toStringAsFixed(0)} IQD',
                            style: const TextStyle(color: Colors.blue),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.red,
                      ),
                      onPressed: () => cart.remove(item.id),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'الإجمالي:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${cart.totalAmount.toStringAsFixed(0)} IQD',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _paymentMethod,
                  decoration: const InputDecoration(
                    labelText: 'طريقة الدفع',
                    border: OutlineInputBorder(),
                  ),
                  items: _paymentMethods
                      .map(
                        (method) => DropdownMenuItem(
                          value: method.value,
                          child: Text(method.label),
                        ),
                      )
                      .toList(),
                  onChanged: _isSubmitting
                      ? null
                      : (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _paymentMethod = value;
                          });
                        },
                ),
                const SizedBox(height: 8),
                Text(
                  _paymentMethodHint(_paymentMethod),
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed:
                        _isSubmitting ? null : () => _submitOrders(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _isSubmitting
                          ? 'جاري إرسال الطلب...'
                          : 'إرسال الطلب والدفع',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryList({
    required List<Widget> children,
    required String emptyTitle,
    required String emptySubtitle,
    required IconData emptyIcon,
  }) {
    if (_isLoadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_historyError != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.withValues(alpha: 0.20)),
            ),
            child: Text(
              _historyError!,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      );
    }

    if (children.isEmpty) {
      return _buildEmptyState(
        icon: emptyIcon,
        title: emptyTitle,
        subtitle: emptySubtitle,
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: children,
    );
  }

  Widget _buildQuoteCard(_QuoteHistoryItem item) {
    return _HistoryCard(
      imageUrl: _normalizeImageUrl(item.offerImageUrl),
      title: item.offerTitle,
      lines: [
        'السعر المثبت: ${item.price.toStringAsFixed(0)} IQD',
        'المبدع: ${item.creatorName}',
        'حالة الدفع: ${_paymentStatusLabel(item.latestPaymentStatus ?? 'pending')}',
        if (item.projectStatus != null)
          'حالة المشروع: ${_projectStatusLabel(item.projectStatus!)}',
      ],
      statusText: 'الطلب نشط',
      statusColor: Colors.blue,
      metaText: _formatDate(item.createdAt),
    );
  }

  Widget _buildPaymentCard(_PaymentHistoryItem item,
      {required bool canUploadProof}) {
    final showProofAction =
        canUploadProof && item.status == 'pending' && item.quoteId.isNotEmpty;
    final showOnlinePaymentAction =
        item.method == 'online' && item.status == 'pending';
    final isPreparingOnlineAction = _onlineActionPaymentId == item.id;

    Widget? footer;
    if (showProofAction || showOnlinePaymentAction) {
      footer = Align(
        alignment: Alignment.centerRight,
        child: Wrap(
          spacing: 8,
          children: [
            if (showProofAction)
              TextButton.icon(
                onPressed: () => _submitPaymentProof(item),
                icon: const Icon(Icons.upload_file, size: 18),
                label: Text(
                  item.proofUrl != null && item.proofUrl!.isNotEmpty
                      ? 'تحديث إثبات الدفع'
                      : 'رفع إثبات الدفع',
                ),
              ),
            if (showOnlinePaymentAction)
              TextButton.icon(
                onPressed: isPreparingOnlineAction
                    ? null
                    : () => _resumeOnlinePayment(item),
                icon: isPreparingOnlineAction
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.open_in_new, size: 18),
                label: const Text('إكمال الدفع الإلكتروني'),
              ),
          ],
        ),
      );
    }

    return _HistoryCard(
      imageUrl: _normalizeImageUrl(item.offerImageUrl),
      title: item.offerTitle,
      lines: [
        'المبلغ: ${item.amount.toStringAsFixed(0)} IQD',
        'طريقة الدفع: ${_paymentMethodLabel(item.method)}',
        if (item.method == 'online')
          'حالة البوابة: ${_gatewayStatusLabel(item.gatewayStatus ?? 'pending')}',
        item.proofUrl != null && item.proofUrl!.isNotEmpty
            ? 'إثبات الدفع: تم الرفع'
            : 'إثبات الدفع: غير مرفوع',
        'المبدع: ${item.creatorName}',
        if (item.projectStatus != null)
          'حالة المشروع: ${_projectStatusLabel(item.projectStatus!)}',
      ],
      statusText: _paymentStatusLabel(item.status),
      statusColor: _statusColor(item.status),
      metaText: _formatDate(item.createdAt),
      footer: footer,
    );
  }

  Widget _buildProjectCard(_ProjectHistoryItem item) {
    return _HistoryCard(
      imageUrl: _normalizeImageUrl(item.offerImageUrl),
      title: item.offerTitle,
      lines: [
        'المبدع: ${item.creatorName}',
        'المدفوعات المؤكدة: ${item.confirmedPaymentCount}',
        if (item.latestDeliveryStatus != null)
          'آخر تسليم: ${item.latestDeliveryStatus}',
      ],
      statusText: _projectStatusLabel(item.status),
      statusColor: _statusColor(item.status),
      metaText: _formatDate(item.startedAt),
    );
  }

  Widget _buildTabBody(_OrdersTab activeTab, bool isCreator) {
    switch (activeTab) {
      case _OrdersTab.cart:
        return _buildCartView();
      case _OrdersTab.quotes:
        return _buildHistoryList(
          emptyTitle: 'لا توجد طلبات بعد',
          emptySubtitle: 'عند إرسال أي طلب جديد سيظهر هنا مباشرة.',
          emptyIcon: Icons.receipt_long_outlined,
          children: _quotes.map(_buildQuoteCard).toList(),
        );
      case _OrdersTab.payments:
        return _buildHistoryList(
          emptyTitle: 'لا توجد مدفوعات بعد',
          emptySubtitle: 'كل دفعة معلقة أو مؤكدة ستظهر هنا.',
          emptyIcon: Icons.payments_outlined,
          children: _payments
              .map(
                  (item) => _buildPaymentCard(item, canUploadProof: !isCreator))
              .toList(),
        );
      case _OrdersTab.projects:
        return _buildHistoryList(
          emptyTitle: 'لا توجد مشاريع بعد',
          emptySubtitle: 'بعد تأكيد الدفع سيظهر المشروع هنا.',
          emptyIcon: Icons.work_outline_rounded,
          children: _projects.map(_buildProjectCard).toList(),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final isCreator = auth.isCreator;
    final availableTabs = _availableTabs(isCreator);
    final safeIndex =
        _selectedTabIndex >= availableTabs.length ? 0 : _selectedTabIndex;
    final activeTab = availableTabs[safeIndex];

    return Scaffold(
      backgroundColor: const Color(0xFF161921),
      appBar: AppBar(
        title: const Text(
          'حجوزاتي',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF161921),
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildTabSelector(availableTabs),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshHistory,
              child: _buildTabBody(activeTab, isCreator),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final String imageUrl;
  final String title;
  final List<String> lines;
  final String statusText;
  final Color statusColor;
  final String metaText;
  final Widget? footer;

  const _HistoryCard({
    required this.imageUrl,
    required this.title,
    required this.lines,
    required this.statusText,
    required this.statusColor,
    required this.metaText,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF222734),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: imageUrl.isEmpty
                ? Container(
                    width: 76,
                    height: 76,
                    color: Colors.black26,
                    child: const Icon(Icons.image_not_supported_outlined,
                        color: Colors.white54),
                  )
                : Image.network(
                    imageUrl,
                    width: 76,
                    height: 76,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 76,
                      height: 76,
                      color: Colors.black26,
                      child: const Icon(Icons.broken_image_outlined,
                          color: Colors.white54),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final line in lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      line,
                      style: TextStyle(
                        color: Colors.grey[300],
                        fontSize: 12,
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                Text(
                  metaText,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 11,
                  ),
                ),
                if (footer != null) ...[
                  const SizedBox(height: 6),
                  footer!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodOption {
  final String value;
  final String label;
  final bool requiresProof;
  final String hint;

  const _PaymentMethodOption({
    required this.value,
    required this.label,
    required this.requiresProof,
    required this.hint,
  });

  factory _PaymentMethodOption.fromJson(Map<String, dynamic> json) {
    return _PaymentMethodOption(
      value: json['value']?.toString().trim() ?? '',
      label: json['label']?.toString().trim() ?? '',
      requiresProof: json['requiresProof'] == true,
      hint: json['hint']?.toString().trim().isNotEmpty == true
          ? json['hint'].toString().trim()
          : 'سيتم إنشاء الدفع المعلق، ثم يؤكده المبدع أو الأدمن لاحقاً.',
    );
  }

  static const List<_PaymentMethodOption> defaults = [
    _PaymentMethodOption(
      value: 'cash',
      label: 'نقدي',
      requiresProof: false,
      hint:
          'تم إنشاء الطلب والدفع المعلق. يمكن للمبدع أو الأدمن تأكيد الدفع لبدء المشروع.',
    ),
    _PaymentMethodOption(
      value: 'bank_transfer',
      label: 'تحويل بنكي',
      requiresProof: true,
      hint: 'تم إنشاء الطلب. ارفع إثبات التحويل من صفحة المدفوعات ليتم تأكيده.',
    ),
    _PaymentMethodOption(
      value: 'wallet',
      label: 'محفظة',
      requiresProof: true,
      hint:
          'تم إنشاء الطلب. ارفع إثبات الدفع من المحفظة من صفحة المدفوعات ليتم تأكيده.',
    ),
  ];
}

class _QuoteHistoryItem {
  final String id;
  final String offerTitle;
  final String? offerImageUrl;
  final String creatorName;
  final double price;
  final DateTime createdAt;
  final String? latestPaymentStatus;
  final String? projectStatus;

  const _QuoteHistoryItem({
    required this.id,
    required this.offerTitle,
    required this.offerImageUrl,
    required this.creatorName,
    required this.price,
    required this.createdAt,
    required this.latestPaymentStatus,
    required this.projectStatus,
  });

  factory _QuoteHistoryItem.fromJson(Map<String, dynamic> json) {
    return _QuoteHistoryItem(
      id: json['id']?.toString() ?? '',
      offerTitle: json['offer_title']?.toString() ?? 'بدون عنوان',
      offerImageUrl: json['offer_image_url']?.toString(),
      creatorName: json['creator_name']?.toString() ?? '-',
      price: _parseDouble(json['price_snapshot']),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      latestPaymentStatus: json['latest_payment_status']?.toString(),
      projectStatus: json['project_status']?.toString(),
    );
  }
}

class _PaymentHistoryItem {
  final String id;
  final String quoteId;
  final String offerTitle;
  final String? offerImageUrl;
  final String? proofUrl;
  final String? gatewayCheckoutUrl;
  final String? gatewayStatus;
  final String creatorName;
  final double amount;
  final String method;
  final String status;
  final String? projectStatus;
  final DateTime createdAt;

  const _PaymentHistoryItem({
    required this.id,
    required this.quoteId,
    required this.offerTitle,
    required this.offerImageUrl,
    required this.proofUrl,
    required this.gatewayCheckoutUrl,
    required this.gatewayStatus,
    required this.creatorName,
    required this.amount,
    required this.method,
    required this.status,
    required this.projectStatus,
    required this.createdAt,
  });

  factory _PaymentHistoryItem.fromJson(Map<String, dynamic> json) {
    return _PaymentHistoryItem(
      id: json['id']?.toString() ?? '',
      quoteId: json['quote_id']?.toString() ?? '',
      offerTitle: json['offer_title']?.toString() ?? 'بدون عنوان',
      offerImageUrl: json['offer_image_url']?.toString(),
      proofUrl: _normalizeOptionalText(json['proof_url']),
      gatewayCheckoutUrl: _normalizeOptionalText(json['gateway_checkout_url']),
      gatewayStatus: _normalizeOptionalText(json['gateway_status']),
      creatorName: json['creator_name']?.toString() ?? '-',
      amount: _parseDouble(json['amount']),
      method: json['method']?.toString() ?? 'cash',
      status: json['status']?.toString() ?? 'pending',
      projectStatus: json['project_status']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  _PaymentHistoryItem copyWith({
    String? gatewayCheckoutUrl,
    String? gatewayStatus,
  }) {
    return _PaymentHistoryItem(
      id: id,
      quoteId: quoteId,
      offerTitle: offerTitle,
      offerImageUrl: offerImageUrl,
      proofUrl: proofUrl,
      gatewayCheckoutUrl: gatewayCheckoutUrl ?? this.gatewayCheckoutUrl,
      gatewayStatus: gatewayStatus ?? this.gatewayStatus,
      creatorName: creatorName,
      amount: amount,
      method: method,
      status: status,
      projectStatus: projectStatus,
      createdAt: createdAt,
    );
  }
}

class _ProjectHistoryItem {
  final String id;
  final String offerTitle;
  final String? offerImageUrl;
  final String creatorName;
  final String status;
  final int confirmedPaymentCount;
  final String? latestDeliveryStatus;
  final DateTime startedAt;

  const _ProjectHistoryItem({
    required this.id,
    required this.offerTitle,
    required this.offerImageUrl,
    required this.creatorName,
    required this.status,
    required this.confirmedPaymentCount,
    required this.latestDeliveryStatus,
    required this.startedAt,
  });

  factory _ProjectHistoryItem.fromJson(Map<String, dynamic> json) {
    return _ProjectHistoryItem(
      id: json['id']?.toString() ?? '',
      offerTitle: json['offer_title']?.toString() ?? 'بدون عنوان',
      offerImageUrl: json['offer_image_url']?.toString(),
      creatorName: json['creator_name']?.toString() ?? '-',
      status: json['status']?.toString() ?? 'in_progress',
      confirmedPaymentCount: _parseInt(json['confirmed_payment_count']),
      latestDeliveryStatus: json['latest_delivery_status']?.toString(),
      startedAt: DateTime.tryParse(json['started_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

double _parseDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value) ?? 0;
  }
  return 0;
}

int _parseInt(dynamic value) {
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? 0;
  }
  return 0;
}

String? _normalizeOptionalText(dynamic value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) {
    return null;
  }
  return text;
}
