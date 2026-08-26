import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme_service.dart';
import '../../core/localization/app_locale_service.dart';

class CreatorSubscriptionScreen extends StatefulWidget {
  const CreatorSubscriptionScreen({super.key});

  @override
  State<CreatorSubscriptionScreen> createState() =>
      _CreatorSubscriptionScreenState();
}

class _CreatorSubscriptionScreenState extends State<CreatorSubscriptionScreen> {
  List<Map<String, dynamic>> _plans = [];
  bool _loading = true;
  bool _paying = false;
  String _cycle = 'monthly';

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    try {
      final api = context.read<ApiClient>();
      final response = await api.client.get('/config/subscription-plans');
      final raw = response.data is Map ? response.data['plans'] : null;
      if (raw is List) {
        setState(() => _plans = raw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList());
      }
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr('تعذر تحميل الخطط', 'Unable to load plans'))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pay(Map<String, dynamic> plan) async {
    final id = plan['id']?.toString() ?? '';
    if (id.isEmpty || plan['is_enterprise'] == true || _paying) return;
    setState(() => _paying = true);
    try {
      final response = await context
          .read<ApiClient>()
          .client
          .post('/subscriptions/checkout', data: {
        'planId': id,
        'billingCycle': _cycle,
      });
      final url = response.data is Map
          ? response.data['checkoutUrl']?.toString()
          : null;
      if (url == null ||
          url.isEmpty ||
          !await launchUrl(Uri.parse(url),
              mode: LaunchMode.externalApplication)) {
        throw Exception(
            tr('تعذر فتح بوابة الدفع', 'Unable to open the payment gateway'));
      }
    } on DioException catch (e) {
      final message = e.response?.data is Map
          ? e.response?.data['error']?.toString()
          : null;
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                message ?? tr('تعذر بدء الدفع', 'Unable to start payment'))));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  String _price(Map<String, dynamic> plan) {
    final value =
        _cycle == 'yearly' ? plan['price_yearly'] : plan['price_monthly'];
    final n = double.tryParse(value?.toString() ?? '') ?? 0;
    return n == 0
        ? tr('مجاني', 'Free')
        : '${n.toStringAsFixed(0)} ${plan['currency'] ?? 'IQD'}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<AppThemeService>().colors;
    final locale = context.watch<AppLocaleService>();
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
          title: Text(tr('خطط الاشتراك', 'Subscription plans')),
          centerTitle: true),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadPlans,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    SegmentedButton<String>(
                      segments: [
                        ButtonSegment(
                            value: 'monthly',
                            label: Text(tr('شهرياً', 'Monthly'))),
                        ButtonSegment(
                            value: 'yearly',
                            label: Text(tr('سنوياً', 'Yearly'))),
                      ],
                      selected: {_cycle},
                      onSelectionChanged: (v) =>
                          setState(() => _cycle = v.first),
                    ),
                    const SizedBox(height: 16),
                    ..._plans.map((plan) => Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      (locale.isEnglish
                                                  ? plan['name_en']
                                                  : plan['name_ar'])
                                              ?.toString() ??
                                          '',
                                      style: const TextStyle(
                                          fontSize: 19,
                                          fontWeight: FontWeight.bold)),
                                  if (((locale.isEnglish
                                              ? plan['description_en']
                                              : plan['description_ar']) ??
                                          '')
                                      .toString()
                                      .isNotEmpty)
                                    Text((locale.isEnglish
                                            ? plan['description_en']
                                            : plan['description_ar'])
                                        .toString()),
                                  const SizedBox(height: 8),
                                  Text(_price(plan),
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: colors.primary)),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                      width: double.infinity,
                                      child: FilledButton(
                                          onPressed: _paying ||
                                                  plan['is_enterprise'] == true
                                              ? null
                                              : () => _pay(plan),
                                          child: Text(plan['is_enterprise'] ==
                                                  true
                                              ? tr('تواصل معنا', 'Contact us')
                                              : tr('اختيار الخطة',
                                                  'Choose plan')))),
                                ]),
                          ),
                        )),
                  ],
                ),
              ),
      ),
    );
  }
}
