import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme_service.dart';
import '../../core/localization/app_locale_service.dart';

class CreatorWalletScreen extends StatefulWidget {
  const CreatorWalletScreen({super.key});
  @override
  State<CreatorWalletScreen> createState() => _CreatorWalletScreenState();
}

class _CreatorWalletScreenState extends State<CreatorWalletScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await context.read<ApiClient>().client.get('/wallet');
      if (mounted) setState(() => _data = Map<String, dynamic>.from(res.data));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _money(dynamic value) =>
      '${(double.tryParse(value?.toString() ?? '') ?? 0).toStringAsFixed(0)} IQD';

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<AppThemeService>().colors;
    context.watch<AppLocaleService>();
    final history = (_data?['history'] as List?) ?? const [];
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: Text(tr('المحفظة', 'Wallet')), centerTitle: true),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(padding: const EdgeInsets.all(16), children: [
                  Card(
                      child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(children: [
                            Text(tr('إجمالي الرصيد', 'Total balance')),
                            const SizedBox(height: 8),
                            Text(_money(_data?['balance']),
                                style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: colors.primary)),
                          ]))),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: _metric(tr('أرسل لنا', 'Sent to us'),
                            _money(_data?['sent']), colors)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _metric(tr('مستحقات معلقة', 'Outstanding'),
                            _money(_data?['outstanding']), colors)),
                  ]),
                  const SizedBox(height: 8),
                  _metric(tr('الأموال المكتسبة', 'Earned money'),
                      _money(_data?['earned']), colors),
                  const SizedBox(height: 20),
                  Text(tr('السجل المالي', 'Financial history'),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...history.map((item) {
                    final row = Map<String, dynamic>.from(item);
                    return Card(
                        child: ListTile(
                            title: Text(row['title']?.toString() ??
                                tr('دخل', 'Income')),
                            subtitle: Text(row['status']?.toString() ?? ''),
                            trailing: Text(_money(row['amount']))));
                  }),
                ]),
              ),
      ),
    );
  }

  Widget _metric(String label, String value, dynamic colors) => Card(
      child: Padding(
          padding: const EdgeInsets.all(12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: colors.primary))
          ])));
}
