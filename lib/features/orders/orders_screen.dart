import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/auth/auth_service.dart';
import '../../core/network/api_client.dart';
import '../../core/services/cart_service.dart';
import '../../core/services/media_service.dart';
import '../../models/offer.dart';

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
  String _paymentMethod = 'online';
  String _paymentPortion = 'full';
  List<_PaymentMethodOption> _paymentMethods = const [
    _PaymentMethodOption.onlineDefault,
  ];
  int _selectedTabIndex = 0;
  List<_QuoteHistoryItem> _quotes = const [];
  List<_PaymentHistoryItem> _payments = const [];
  List<_ProjectHistoryItem> _projects = const [];
  String? _onlineActionPaymentId;

  DateTime? _parseEventDate(dynamic raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString())?.toLocal();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String? _statusForDay(DateTime day, List<dynamic> events) {
    bool hasBusy = false;
    for (final raw in events) {
      if (raw is! Map) continue;
      final eventDate = _parseEventDate(raw['date_time']);
      if (eventDate == null || !_isSameDay(day, eventDate)) continue;
      final status = raw['calendar_status']?.toString().toLowerCase();
      if (status == 'booked') return 'booked';
      if (status == 'busy') hasBusy = true;
    }
    return hasBusy ? 'busy' : null;
  }

  String _availabilityLabel(String? status) {
    if (status == 'booked') return 'محجوز';
    if (status == 'busy') return 'مشغول';
    return 'متاح';
  }

  Color _availabilityColor(String? status) {
    if (status == 'booked') return const Color(0xFFFF4DA6);
    if (status == 'busy') return Colors.orangeAccent;
    return Colors.greenAccent;
  }

  Color _availabilityBackground(String? status) {
    if (status == 'booked') return const Color(0x33FF4DA6);
    if (status == 'busy') return const Color(0x33FFB547);
    return const Color(0x3323D18B);
  }

  String _timeLabel(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _bookingDateTimeLabel(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month/$year - $hour:$minute';
  }

  DateTime _dayOnly(DateTime value) =>
      DateTime.utc(value.year, value.month, value.day);

  DateTime _startOfWeek(DateTime value) {
    final normalized = _dayOnly(value);
    return normalized.subtract(
      Duration(days: normalized.weekday - DateTime.monday),
    );
  }

  int _isoWeekNumber(DateTime date) {
    final normalized = _dayOnly(date);
    final thursday = normalized.add(Duration(days: 4 - normalized.weekday));
    final firstDayOfYear = DateTime.utc(thursday.year, 1, 1);
    final firstThursday = firstDayOfYear.add(
      Duration(days: (DateTime.thursday - firstDayOfYear.weekday + 7) % 7),
    );
    return 1 + (thursday.difference(firstThursday).inDays ~/ 7);
  }

  String _monthLabel(DateTime month) {
    const labels = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    return '${labels[month.month - 1]} ${month.year}';
  }

  String _weekRangeLabel(DateTime weekStart) {
    final weekEnd = weekStart.add(const Duration(days: 6));
    final startDay = weekStart.day.toString().padLeft(2, '0');
    final endDay = weekEnd.day.toString().padLeft(2, '0');
    final startMonth = _monthLabel(DateTime(weekStart.year, weekStart.month));
    final endMonth = _monthLabel(DateTime(weekEnd.year, weekEnd.month));

    if (weekStart.month == weekEnd.month && weekStart.year == weekEnd.year) {
      return '$startDay - $endDay $startMonth';
    }
    return '$startDay $startMonth - $endDay $endMonth';
  }

  String _weekdayShortLabel(int weekday) {
    const labels = ['اث', 'ثل', 'أر', 'خم', 'جم', 'سب', 'أح'];
    return labels[weekday - 1];
  }

  String _fullDateLabel(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    return '$day/$month/$year';
  }

  List<Map<String, dynamic>> _eventsForDay(DateTime day, List<dynamic> events) {
    final normalized = _dayOnly(day);
    final matches = <Map<String, dynamic>>[];
    for (final raw in events) {
      if (raw is! Map) continue;
      final eventDate = _parseEventDate(raw['date_time']);
      if (eventDate == null) continue;
      if (_dayOnly(eventDate) == normalized) {
        matches.add(Map<String, dynamic>.from(raw));
      }
    }
    matches.sort((a, b) {
      final first = _parseEventDate(a['date_time']);
      final second = _parseEventDate(b['date_time']);
      if (first == null || second == null) return 0;
      return first.compareTo(second);
    });
    return matches;
  }

  Widget _buildCustomerCalendarDayCell({
    required DateTime day,
    required bool isSelected,
    required bool isToday,
    required String? status,
    required bool isPast,
    required VoidCallback onTap,
  }) {
    final color = isPast ? Colors.white30 : _availabilityColor(status);
    final hasStatus = status != null;
    final isAvailable = !isPast && status == null;

    return Expanded(
      child: AspectRatio(
        aspectRatio: 0.86,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF2A2039)
                      : const Color(0xFF161B27),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFFFF4DA6)
                        : hasStatus
                            ? color.withValues(alpha: 0.45)
                            : Colors.white10,
                    width: isSelected ? 1.4 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color:
                                const Color(0xFFFF4DA6).withValues(alpha: 0.24),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ]
                      : null,
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 20,
                        height: 20,
                        alignment: Alignment.center,
                        decoration: isToday
                            ? BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFF4DA6), Color(0xFF7A3EED)],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFF4DA6)
                                        .withValues(alpha: 0.24),
                                    blurRadius: 14,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              )
                            : null,
                        child: Text(
                          '${day.day}',
                          style: TextStyle(
                            color: isPast ? Colors.white54 : Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: isPast
                              ? Colors.white10
                              : isAvailable
                                  ? Colors.greenAccent
                                  : color,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerSelectedDayPanel({
    required Offer item,
    required DateTime selectedDay,
    required DateTime? selectedDateTime,
    required List<Map<String, dynamic>> dayEvents,
    required VoidCallback onPickTime,
  }) {
    final status = _statusForDay(selectedDay, dayEvents);
    final isAvailable = status == null;
    final selectedTime = selectedDateTime != null &&
            _dayOnly(selectedDateTime) == _dayOnly(selectedDay)
        ? selectedDateTime
        : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF141A26),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'تفاصيل اليوم',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _fullDateLabel(selectedDay),
                      style: const TextStyle(
                        color: Colors.white60,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _availabilityBackground(status),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: _availabilityColor(status).withValues(alpha: 0.34),
                  ),
                ),
                child: Text(
                  _availabilityLabel(status),
                  style: TextStyle(
                    color: _availabilityColor(status),
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (dayEvents.isNotEmpty) ...[
            for (final event in dayEvents.take(2))
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B2030),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color:
                        _availabilityColor(event['calendar_status']?.toString())
                            .withValues(alpha: 0.28),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      event['calendar_status']?.toString().toLowerCase() ==
                              'busy'
                          ? Icons.block_rounded
                          : Icons.event_busy_rounded,
                      color:
                          _availabilityColor(event['calendar_status']?.toString()),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_availabilityLabel(event['calendar_status']?.toString())} ${_timeLabel(TimeOfDay.fromDateTime(_parseEventDate(event['date_time']) ?? selectedDay.toLocal()))}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ] else
            const Text(
              'هذا اليوم متاح حالياً للحجز.',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 12,
              ),
            ),
          const SizedBox(height: 12),
          if (isAvailable)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onPickTime,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF4DA6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.schedule_rounded),
                label: Text(
                  selectedTime == null
                      ? 'اختر الوقت لهذا اليوم'
                      : 'الوقت المختار: ${_timeLabel(TimeOfDay.fromDateTime(selectedTime))}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            )
          else
            const Text(
              'هذا اليوم غير متاح. اختر يوماً آخر من الجدول.',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
          if (selectedTime != null) ...[
            const SizedBox(height: 10),
            Text(
              'موعد الحجز: ${_bookingDateTimeLabel(selectedTime)}',
              style: const TextStyle(
                color: Colors.greenAccent,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }

  double _calculatePaymentAmountForOffer(Offer offer, String portion) {
    return offer.paymentAmountFor(portion);
  }

  double _calculatePaymentAmountForItems(List<Offer> items, String portion) {
    return items.fold<double>(
      0,
      (sum, offer) => sum + _calculatePaymentAmountForOffer(offer, portion),
    );
  }

  String _paymentPortionLabel(String portion) {
    switch (portion) {
      case 'partial':
        return 'جزء من المبلغ';
      case 'full':
      default:
        return 'المبلغ الكامل';
    }
  }

  String _paymentPortionHint(String portion) {
    switch (portion) {
      case 'partial':
        return 'يتم الآن دفع مبلغ الدفعة الجزئية الذي حدده صاحب العرض، ثم يُستكمل الباقي لاحقاً.';
      case 'full':
      default:
        return 'يتم الآن دفع مبلغ العمل الكامل المحدد لهذا العرض ثم المتابعة إلى بوابة الدفع.';
    }
  }

  Future<String?> _showPaymentPortionSheet(List<Offer> items) async {
    String selected = _paymentPortion;
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141824),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: StatefulBuilder(
            builder: (sheetContext, setSheetState) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'اختر طريقة دفع المبلغ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'بعد اختيار الجزء المطلوب من المبلغ، سيتم تحويلك إلى بوابة الدفع الإلكترونية.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 16),
                    for (final portion in const ['partial', 'full']) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              setSheetState(() {
                                selected = portion;
                              });
                            },
                            borderRadius: BorderRadius.circular(18),
                            child: Ink(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: selected == portion
                                    ? const Color(0xFF2A2039)
                                    : const Color(0xFF1B2030),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: selected == portion
                                      ? const Color(0xFFFF4DA6)
                                      : Colors.white12,
                                ),
                                boxShadow: selected == portion
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFFFF4DA6)
                                              .withValues(alpha: 0.24),
                                          blurRadius: 16,
                                          offset: const Offset(0, 8),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    selected == portion
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_off,
                                    color: selected == portion
                                        ? const Color(0xFFFF4DA6)
                                        : Colors.white38,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _paymentPortionLabel(portion),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          _paymentPortionHint(portion),
                                          style: const TextStyle(
                                            color: Colors.white60,
                                            fontSize: 12,
                                            height: 1.45,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '${_calculatePaymentAmountForItems(items, portion).toStringAsFixed(0)} IQD',
                                    style: const TextStyle(
                                      color: Color(0xFFBC83FF),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white24),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'رجوع',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () =>
                                Navigator.of(sheetContext).pop(selected),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: const Color(0xFFFF4DA6),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'المتابعة إلى الدفع',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<Map<String, List<dynamic>>> _loadAvailabilityForOffers(
      List<Offer> items) async {
    final mediaService = context.read<MediaService>();
    final creatorIds = items
        .map((item) => item.creatorId.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final entries = await Future.wait(
      creatorIds.map((creatorId) async {
        final events = await mediaService.fetchEvents(creatorId);
        return MapEntry(creatorId, events);
      }),
    );

    return Map<String, List<dynamic>>.fromEntries(entries);
  }

  Future<Map<String, DateTime>?> _showCalendarReviewBeforeSubmit(
      List<Offer> items) async {
    if (items.isEmpty) return null;

    final offersWithCreator =
        items.where((item) => item.creatorId.trim().isNotEmpty).toList();
    final offersWithoutCreator =
        items.where((item) => item.creatorId.trim().isEmpty).toList();

    final selectedByOfferId = <String, DateTime>{};
    final selectedDayByOfferId = <String, DateTime>{};
    final visibleWeekStartByOfferId = <String, DateTime>{};
    final today = _dayOnly(DateTime.now());

    final result = await showModalBottomSheet<Map<String, DateTime>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141824),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: StatefulBuilder(
            builder: (sheetContext, setSheetState) {
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  18,
                  18,
                  18,
                  18 + MediaQuery.of(sheetContext).viewInsets.bottom,
                ),
                child: FutureBuilder<Map<String, List<dynamic>>>(
                  future: _loadAvailabilityForOffers(offersWithCreator),
                  builder: (context, snapshot) {
                    final availability =
                        snapshot.data ?? const <String, List<dynamic>>{};
                    final allSelected = offersWithCreator.every(
                      (item) => selectedByOfferId.containsKey(item.id),
                    );

                    Future<void> pickDateTimeForOffer(
                        Offer item, DateTime day) async {
                      final pickedTime = await showTimePicker(
                        context: sheetContext,
                        initialTime: const TimeOfDay(hour: 12, minute: 0),
                        helpText: 'اختر وقت الحجز',
                      );
                      if (pickedTime == null) return;
                      setSheetState(() {
                        selectedDayByOfferId[item.id] = _dayOnly(day);
                        selectedByOfferId[item.id] = DateTime(
                          day.year,
                          day.month,
                          day.day,
                          pickedTime.hour,
                          pickedTime.minute,
                        );
                      });
                    }

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 44,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'اختر موعد الحجز أولاً',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'راجع جدول صاحب العرض، اختر يوماً متاحاً، ثم حدّد الوقت قبل متابعة الدفع.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (snapshot.connectionState == ConnectionState.waiting)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 28),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else
                          Flexible(
                            child: SingleChildScrollView(
                              child: Column(
                                children: [
                                  for (final item in offersWithCreator) ...[
                                    Builder(
                                      builder: (_) {
                                        final selected =
                                            selectedByOfferId[item.id];
                                        final creatorEvents =
                                            availability[item.creatorId] ??
                                                const [];
                                        final initialSelectedDay = selected !=
                                                null
                                            ? _dayOnly(selected)
                                            : today;
                                        final selectedDay =
                                            selectedDayByOfferId.putIfAbsent(
                                          item.id,
                                          () => initialSelectedDay,
                                        );
                                        final visibleWeekStart =
                                            visibleWeekStartByOfferId
                                                .putIfAbsent(
                                          item.id,
                                          () => _startOfWeek(selectedDay),
                                        );
                                        final weekDays = List.generate(
                                          7,
                                          (index) => visibleWeekStart.add(
                                            Duration(days: index),
                                          ),
                                        );
                                        final weekNumber =
                                            _isoWeekNumber(visibleWeekStart);
                                        final selectedDayEvents = _eventsForDay(
                                          selectedDay,
                                          creatorEvents,
                                        );

                                        return Container(
                                          width: double.infinity,
                                          margin:
                                              const EdgeInsets.only(bottom: 12),
                                          padding: const EdgeInsets.all(14),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF1B2030),
                                            borderRadius:
                                                BorderRadius.circular(18),
                                            border: Border.all(
                                              color: Colors.white12,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.title,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              const Text(
                                                'اختر يوماً متاحاً من جدول المبدع',
                                                style: TextStyle(
                                                  color: Colors.white60,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(14),
                                                decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFF141A26),
                                                  borderRadius:
                                                      BorderRadius.circular(18),
                                                  border: Border.all(
                                                    color: Colors.white12,
                                                  ),
                                                ),
                                                child: Column(
                                                  children: [
                                                    Row(
                                                      children: [
                                                        IconButton(
                                                          onPressed: () {
                                                            final newWeek =
                                                                visibleWeekStart
                                                                    .subtract(
                                                              const Duration(
                                                                  days: 7),
                                                            );
                                                            setSheetState(() {
                                                              visibleWeekStartByOfferId[
                                                                      item.id] =
                                                                  newWeek;
                                                              selectedDayByOfferId[
                                                                      item.id] =
                                                                  newWeek;
                                                              if (selected !=
                                                                      null &&
                                                                  !_isSameDay(
                                                                    selected,
                                                                    newWeek,
                                                                  )) {
                                                                selectedByOfferId
                                                                    .remove(
                                                                  item.id,
                                                                );
                                                              }
                                                            });
                                                          },
                                                          icon: const Icon(
                                                            Icons.chevron_left,
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                        Expanded(
                                                          child: Column(
                                                            children: [
                                                              Text(
                                                                'الأسبوع $weekNumber',
                                                                style:
                                                                    const TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontSize: 17,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w800,
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                  height: 3),
                                                              Text(
                                                                _weekRangeLabel(
                                                                  visibleWeekStart,
                                                                ),
                                                                style:
                                                                    const TextStyle(
                                                                  color: Colors
                                                                      .white60,
                                                                  fontSize: 12,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        IconButton(
                                                          onPressed: () {
                                                            final newWeek =
                                                                visibleWeekStart
                                                                    .add(
                                                              const Duration(
                                                                  days: 7),
                                                            );
                                                            setSheetState(() {
                                                              visibleWeekStartByOfferId[
                                                                      item.id] =
                                                                  newWeek;
                                                              selectedDayByOfferId[
                                                                      item.id] =
                                                                  newWeek;
                                                              if (selected !=
                                                                      null &&
                                                                  !_isSameDay(
                                                                    selected,
                                                                    newWeek,
                                                                  )) {
                                                                selectedByOfferId
                                                                    .remove(
                                                                  item.id,
                                                                );
                                                              }
                                                            });
                                                          },
                                                          icon: const Icon(
                                                            Icons.chevron_right,
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 12),
                                                    Row(
                                                      children: [
                                                        Container(
                                                          width: 34,
                                                          alignment:
                                                              Alignment.center,
                                                          child: Text(
                                                            '$weekNumber',
                                                            style:
                                                                const TextStyle(
                                                              color: Color(
                                                                  0xFFBC83FF),
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w800,
                                                            ),
                                                          ),
                                                        ),
                                                        for (final day
                                                            in weekDays)
                                                          Expanded(
                                                            child: Center(
                                                              child: Text(
                                                                _weekdayShortLabel(
                                                                  day.weekday,
                                                                ),
                                                                style:
                                                                    const TextStyle(
                                                                  color: Colors
                                                                      .white54,
                                                                  fontSize: 11,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 10),
                                                    Row(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        const SizedBox(
                                                            width: 34),
                                                        for (final day
                                                            in weekDays)
                                                          _buildCustomerCalendarDayCell(
                                                            day: day,
                                                            isSelected:
                                                                _isSameDay(
                                                              day,
                                                              selectedDay,
                                                            ),
                                                            isToday:
                                                                _isSameDay(
                                                              day,
                                                              today,
                                                            ),
                                                            status:
                                                                _statusForDay(
                                                              day,
                                                              creatorEvents,
                                                            ),
                                                            isPast: _dayOnly(
                                                              day,
                                                            ).isBefore(today),
                                                            onTap: () {
                                                              setSheetState(() {
                                                                selectedDayByOfferId[
                                                                        item.id] =
                                                                    _dayOnly(
                                                                  day,
                                                                );
                                                                if (selected !=
                                                                        null &&
                                                                    !_isSameDay(
                                                                      selected,
                                                                      day,
                                                                    )) {
                                                                  selectedByOfferId
                                                                      .remove(
                                                                    item.id,
                                                                  );
                                                                }
                                                              });
                                                            },
                                                          ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              _buildCustomerSelectedDayPanel(
                                                item: item,
                                                selectedDay: selectedDay,
                                                selectedDateTime: selected,
                                                dayEvents: selectedDayEvents,
                                                onPickTime: () =>
                                                    pickDateTimeForOffer(
                                                  item,
                                                  selectedDay,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                  for (final item in offersWithoutCreator) ...[
                                    Container(
                                      width: double.infinity,
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1B2030),
                                        borderRadius: BorderRadius.circular(18),
                                        border:
                                            Border.all(color: Colors.white12),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.title,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          const Text(
                                            'لا توجد بيانات جدول مرتبطة بهذا العرض حالياً.',
                                            style: TextStyle(
                                              color: Colors.white60,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () =>
                                    Navigator.of(sheetContext).pop(),
                                style: OutlinedButton.styleFrom(
                                  side:
                                      const BorderSide(color: Colors.white24),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text(
                                  'رجوع',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: snapshot.connectionState ==
                                            ConnectionState.waiting ||
                                        !allSelected
                                    ? null
                                    : () => Navigator.of(sheetContext).pop(
                                          Map<String, DateTime>.from(
                                            selectedByOfferId,
                                          ),
                                        ),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                  backgroundColor:
                                      const Color(0xFFFF4DA6),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text(
                                  'تأكيد الموعد ثم الدفع',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              );
            },
          ),
        );
      },
    );

    return result;
  }

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
      return const [_PaymentMethodOption.onlineDefault];
    }

    final rawMethods = payload['methods'];
    if (rawMethods is! List) {
      return const [_PaymentMethodOption.onlineDefault];
    }

    final options = rawMethods
        .whereType<Map>()
        .map((item) =>
            _PaymentMethodOption.fromJson(Map<String, dynamic>.from(item)))
        .where((item) => item.value.isNotEmpty && item.label.isNotEmpty)
        .toList();

    if (options.isEmpty) {
      return const [_PaymentMethodOption.onlineDefault];
    }

    final onlineOnly = options.where((item) => item.value == 'online').toList();
    return onlineOnly.isNotEmpty
        ? onlineOnly
        : const [_PaymentMethodOption.onlineDefault];
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
      return 'https://sawrly.com$value';
    }
    if (value.startsWith('http://sawrly.com')) {
      return value.replaceFirst('http://', 'https://');
    }
    return value;
  }

  Map<String, dynamic>? _asJsonMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  String? _extractGatewayCheckoutUrl(dynamic payload) {
    final parsedPayload = _asJsonMap(payload);
    if (parsedPayload == null) {
      return null;
    }

    final directUrl =
        _normalizeOptionalText(parsedPayload['gatewayCheckoutUrl']);
    if (directUrl != null) {
      return directUrl;
    }

    final rawItems = parsedPayload['items'];
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

  String? _extractFirstPaymentId(dynamic payload) {
    final parsedPayload = _asJsonMap(payload);
    if (parsedPayload == null) {
      return null;
    }

    final rawItems = parsedPayload['items'];
    if (rawItems is! List) {
      return null;
    }

    for (final item in rawItems.whereType<Map>()) {
      final parsed = Map<String, dynamic>.from(item);
      final paymentId = _normalizeOptionalText(parsed['paymentId']);
      if (paymentId != null) {
        return paymentId;
      }
    }

    return null;
  }

  Future<bool> _openExternalUrl(String url) async {
    final normalized = url.trim();
    if (normalized.isEmpty) {
      return false;
    }

    final withScheme = normalized.startsWith('http://') ||
            normalized.startsWith('https://')
        ? normalized
        : 'https://$normalized';

    final uri = Uri.tryParse(withScheme) ?? Uri.tryParse(Uri.encodeFull(withScheme));
    if (uri == null) {
      return false;
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return false;
    }

    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
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
    return _createOnlineCheckoutUrlByPaymentId(item.id);
  }

  Future<String?> _createOnlineCheckoutUrlByPaymentId(String paymentId) async {
    if (!mounted) {
      return null;
    }

    setState(() {
      _onlineActionPaymentId = paymentId;
    });

    try {
      final apiClient = context.read<ApiClient>();
      final response =
          await apiClient.client.post('/payments/$paymentId/online-checkout');
      final payload = _asJsonMap(response.data);

      final checkoutUrl = payload == null
          ? null
          : _normalizeOptionalText(
              payload['gatewayCheckoutUrl'] ?? payload['checkoutUrl']);
      final gatewayStatus = payload == null
          ? 'pending'
          : _normalizeOptionalText(payload['gatewayStatus']) ?? 'pending';

      if (checkoutUrl == null || checkoutUrl.isEmpty) {
        return null;
      }

      if (!mounted) {
        return checkoutUrl;
      }

      setState(() {
        _payments = _payments
            .map(
              (payment) => payment.id == paymentId
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
      final errorMessage = _asJsonMap(responseData)?['error']?.toString();

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
            ? const [_PaymentMethodOption.onlineDefault]
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
        _paymentMethod = 'online';
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

  Future<void> _submitOrders(
    BuildContext context, {
    required Map<String, DateTime> bookingSelections,
    required String paymentPortion,
  }) async {
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
        'paymentPortion': paymentPortion,
        'scheduledForByOfferId': bookingSelections.map(
          (key, value) => MapEntry(key, value.toUtc().toIso8601String()),
        ),
      });

      final data = response.data;
      final parsedData = _asJsonMap(data);
      final createdCount =
          (parsedData?['quotesCount'] as num?)?.toInt() ?? items.length;
      final nextStep = parsedData?['nextStep']?.toString();
      String? gatewayCheckoutUrl = _extractGatewayCheckoutUrl(parsedData);
      final firstPaymentId = _extractFirstPaymentId(parsedData);

      cart.clear();
      await _refreshHistory();
      if (!mounted) {
        return;
      }

      if (_paymentMethod == 'online' &&
          (gatewayCheckoutUrl == null || gatewayCheckoutUrl.isEmpty) &&
          firstPaymentId != null &&
          firstPaymentId.isNotEmpty) {
        gatewayCheckoutUrl =
            await _createOnlineCheckoutUrlByPaymentId(firstPaymentId);
      }

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
                  Text('تعذر فتح بوابة الدفع، تأكد من وجود متصفح ثم حاول مرة أخرى'),
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
      final errorMessage = _asJsonMap(responseData)?['error']?.toString();

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
    return const [_OrdersTab.cart];
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
    if (tabs.length <= 1) {
      return const SizedBox.shrink();
    }
    final safeIndex = _selectedTabIndex >= tabs.length ? 0 : _selectedTabIndex;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 54,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF232838)
                        : Colors.white12,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0x66FF4DA6)
                          : Colors.white24,
                    ),
                    boxShadow: isSelected
                        ? [
                            const BoxShadow(
                              color: Color(0x66FF4DA6),
                              blurRadius: 12,
                              offset: Offset(0, 6),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      _tabLabel(tab),
                      style: TextStyle(
                        color: isSelected
                            ? const Color(0xFFFF8AD4)
                            : Colors.white70,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemCount: tabs.length,
          ),
        ),
        Container(
          height: 1,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                Color(0x33FF4DA6),
                Color(0x147A3EED),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ],
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
              final dpr = MediaQuery.devicePixelRatioOf(context);
              final cacheSize = (60 * dpr).round();
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF222734),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
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
                        cacheWidth: cacheSize,
                        cacheHeight: cacheSize,
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
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${item.price.toStringAsFixed(0)} IQD',
                            style: const TextStyle(
                              color: Color(0xFFBC83FF),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () => cart.remove(item.id),
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.red.withValues(alpha: 0.28),
                          ),
                        ),
                        child: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Color(0xFF1B1F2A),
            boxShadow: [
              BoxShadow(
                color: Color(0x8C7A3EED),
                blurRadius: 24,
                offset: Offset(0, -4),
              ),
            ],
            border: Border(
              top: BorderSide(color: Colors.white12),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'المبلغ المطلوب الآن:',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${_calculatePaymentAmountForItems(List.of(cart.items), _paymentPortion).toStringAsFixed(0)} IQD',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFBC83FF),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF232838),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0x66FF4DA6)),
                    boxShadow: [
                      const BoxShadow(
                        color: Color(0x66FF4DA6),
                        blurRadius: 14,
                        offset: Offset(0, 8),
                      ),
                      BoxShadow(
                        color: const Color(0xFF7A3EED)
                            .withValues(alpha: 0.18),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _paymentMethodLabel(_paymentMethod),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.lock_outline_rounded,
                        color: Colors.white54,
                        size: 18,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _paymentMethodHint(_paymentMethod),
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F2432),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'نوع المبلغ',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            _paymentPortionLabel(_paymentPortion),
                            style: const TextStyle(
                              color: Color(0xFFFF8AD4),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _paymentPortionHint(_paymentPortion),
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Color(0xFFFF4DA6),
                          Color(0xFF7A3EED),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFFFF4DA6).withValues(alpha: 0.38),
                          blurRadius: 22,
                          offset: const Offset(0, 12),
                        ),
                        BoxShadow(
                          color:
                              const Color(0xFF7A3EED).withValues(alpha: 0.20),
                          blurRadius: 30,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isSubmitting
                          ? null
                          : () async {
                              final cart = context.read<CartService>();
                              final bookingSelections =
                                  await _showCalendarReviewBeforeSubmit(
                                List.of(cart.items),
                              );
                              if (!mounted || bookingSelections == null) {
                                return;
                              }
                              final paymentPortion =
                                  await _showPaymentPortionSheet(
                                List.of(cart.items),
                              );
                              if (!mounted || paymentPortion == null) {
                                return;
                              }
                              setState(() {
                                _paymentPortion = paymentPortion;
                              });
                              await _submitOrders(
                                context,
                                bookingSelections: bookingSelections,
                                paymentPortion: paymentPortion,
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        _isSubmitting
                            ? 'جاري إرسال الطلب...'
                            : 'اختيار الموعد ثم نوع الدفع',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
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
        if (item.scheduledFor != null)
          'موعد الحجز: ${_formatDate(item.scheduledFor!)}',
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
        'نوع الدفع: ${_paymentPortionLabel(item.paymentPortion)}',
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
            child: _buildTabBody(activeTab, isCreator),
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
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheThumbSize = (76 * dpr).round();
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
                    cacheWidth: cacheThumbSize,
                    cacheHeight: cacheThumbSize,
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

  static const _PaymentMethodOption onlineDefault = _PaymentMethodOption(
    value: 'online',
    label: 'دفع إلكتروني',
    requiresProof: false,
    hint: 'أكمل الدفع من بوابة الدفع الإلكترونية.',
  );
}

class _QuoteHistoryItem {
  final String id;
  final String offerTitle;
  final String? offerImageUrl;
  final String creatorName;
  final double price;
  final DateTime createdAt;
  final DateTime? scheduledFor;
  final String? latestPaymentStatus;
  final String? projectStatus;

  const _QuoteHistoryItem({
    required this.id,
    required this.offerTitle,
    required this.offerImageUrl,
    required this.creatorName,
    required this.price,
    required this.createdAt,
    required this.scheduledFor,
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
      scheduledFor:
          DateTime.tryParse(json['scheduled_for']?.toString() ?? '')?.toLocal(),
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
  final String paymentPortion;
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
    required this.paymentPortion,
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
      paymentPortion: json['payment_portion']?.toString() ?? 'full',
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
      paymentPortion: paymentPortion,
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
