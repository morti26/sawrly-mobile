import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:fotgraf_mobile/models/offer.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/auth/auth_service.dart';
import '../../core/design/design_tokens.dart';
import '../../core/network/api_client.dart';
import '../../core/services/cart_service.dart';
import '../../core/services/media_service.dart';
import '../../core/widgets/report_dialog.dart';
import '../navigation/main_navigation.dart';
import '../profile/creator_profile_screen.dart';

class OfferDetailsScreen extends StatefulWidget {
  final Offer offer;

  const OfferDetailsScreen({super.key, required this.offer});

  @override
  State<OfferDetailsScreen> createState() => _OfferDetailsScreenState();
}

class _OfferDetailsScreenState extends State<OfferDetailsScreen> {
  VideoPlayerController? _videoController;
  Future<void>? _videoInitFuture;
  late final List<OfferMediaItem> _mediaItems;
  int _activeIndex = 0;
  late bool _isSaved;
  bool _isSavingFavorite = false;
  bool _isStartingPayment = false;

  String _formatDateTime(DateTime value) {
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    final hh = value.hour.toString().padLeft(2, '0');
    final mm = value.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  int _isoWeekNumber(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final thursday = normalized.add(
      Duration(days: DateTime.thursday - normalized.weekday),
    );
    final firstThursday = DateTime(thursday.year, 1, 4);
    final firstWeekStart = firstThursday.subtract(
      Duration(days: firstThursday.weekday - 1),
    );
    final currentWeekStart = normalized.subtract(
      Duration(days: normalized.weekday - 1),
    );
    return ((currentWeekStart.difference(firstWeekStart).inDays) ~/ 7) + 1;
  }

  DateTime _startOfWeekSaturday(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final delta = (normalized.weekday - DateTime.saturday) % 7;
    return normalized.subtract(Duration(days: delta));
  }

  Future<DateTime?> _pickWeeklySchedule(BuildContext context) async {
    final now = DateTime.now();
    DateTime selectedDate = DateTime(now.year, now.month, now.day);
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(now);
    DateTime weekAnchor = selectedDate;

    return showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161921),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final weekStart = _startOfWeekSaturday(weekAnchor);
          final weekNumber = _isoWeekNumber(selectedDate);
          final days = List.generate(
            7,
            (i) => weekStart.add(Duration(days: i)),
          );

          const weekdayLabel = <int, String>{
            DateTime.saturday: 'س',
            DateTime.sunday: 'ح',
            DateTime.monday: 'ن',
            DateTime.tuesday: 'ث',
            DateTime.wednesday: 'ر',
            DateTime.thursday: 'خ',
            DateTime.friday: 'ج',
          };

          return Directionality(
            textDirection: TextDirection.rtl,
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 12,
                  bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                        const Expanded(
                          child: Text(
                            'اختيار الموعد',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            setModalState(() {
                              weekAnchor = weekAnchor.subtract(
                                const Duration(days: 7),
                              );
                            });
                          },
                          icon: const Icon(
                            Icons.chevron_right,
                            color: Colors.white,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'الأسبوع $weekNumber • ${_formatDateTime(selectedDate).split(' ').first}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setModalState(() {
                              weekAnchor = weekAnchor.add(
                                const Duration(days: 7),
                              );
                            });
                          },
                          icon: const Icon(
                            Icons.chevron_left,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: days.map((day) {
                        final isSelected =
                            day.year == selectedDate.year &&
                            day.month == selectedDate.month &&
                            day.day == selectedDate.day;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                setModalState(() {
                                  selectedDate = day;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF7C3AED)
                                      : const Color(0xFF232838),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      weekdayLabel[day.weekday] ?? '',
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.white70,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      day.day.toString(),
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.white70,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                        );
                        if (picked != null) {
                          setModalState(() {
                            selectedTime = picked;
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF232838),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              color: Colors.white70,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'الوقت: ${selectedTime.format(context)}',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            const Icon(Icons.edit, color: Colors.white70),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white24),
                              minimumSize: const Size.fromHeight(48),
                            ),
                            child: const Text('إلغاء'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              final scheduled = DateTime(
                                selectedDate.year,
                                selectedDate.month,
                                selectedDate.day,
                                selectedTime.hour,
                                selectedTime.minute,
                              );
                              Navigator.pop(context, scheduled);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7C3AED),
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(48),
                            ),
                            child: const Text('حسناً'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<int?> _pickPaymentAmountIqd(
    BuildContext context,
    int maxAmount,
  ) async {
    int selectedAmount = maxAmount;
    final controller = TextEditingController(text: maxAmount.toString());
    bool isPartial = false;

    final result = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161921),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          int? parseController() {
            final raw = controller.text.trim();
            final value = int.tryParse(raw);
            if (value == null) return null;
            return value;
          }

          return Directionality(
            textDirection: TextDirection.rtl,
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 12,
                  bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                        const Expanded(
                          child: Text(
                            'قيمة الدفع',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF232838),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'المبلغ الكامل: $maxAmount IQD',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        setModalState(() {
                          isPartial = false;
                          controller.text = maxAmount.toString();
                          selectedAmount = maxAmount;
                        });
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isPartial
                              ? const Color(0xFF232838)
                              : const Color(0xFF7C3AED),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'دفع كامل المبلغ',
                          style: TextStyle(
                            color: isPartial ? Colors.white70 : Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        setModalState(() {
                          isPartial = true;
                        });
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isPartial
                              ? const Color(0xFF7C3AED)
                              : const Color(0xFF232838),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'دفع جزء من المبلغ',
                          style: TextStyle(
                            color: isPartial ? Colors.white : Colors.white70,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (isPartial)
                      TextField(
                        controller: controller,
                        keyboardType: TextInputType.number,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF232838),
                          labelText: 'المبلغ (IQD)',
                          labelStyle: const TextStyle(color: Colors.white70),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (_) {
                          final parsed = parseController();
                          setModalState(() {
                            if (parsed != null) {
                              selectedAmount = parsed;
                            }
                          });
                        },
                      ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white24),
                              minimumSize: const Size.fromHeight(48),
                            ),
                            child: const Text('إلغاء'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              final amount = isPartial
                                  ? parseController()
                                  : maxAmount;
                              if (amount == null) {
                                return;
                              }
                              if (amount <= 0 || amount > maxAmount) {
                                return;
                              }
                              Navigator.pop(context, amount);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7C3AED),
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(48),
                            ),
                            child: const Text('متابعة'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    controller.dispose();
    return result;
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

  Future<void> _startOnlinePayment() async {
    if (_isStartingPayment) {
      return;
    }

    final auth = context.read<AuthService>();
    final messenger = ScaffoldMessenger.of(context);

    if (!auth.isAuthenticated) {
      messenger.showSnackBar(
        const SnackBar(content: Text('يرجى تسجيل الدخول أولاً')),
      );
      return;
    }

    if (auth.isCreator) {
      messenger.showSnackBar(
        const SnackBar(content: Text('هذه الميزة متاحة للعملاء فقط')),
      );
      return;
    }

    final maxAmount = widget.offer.price.round();
    final scheduledAt = await _pickWeeklySchedule(context);
    if (scheduledAt == null || !mounted) {
      return;
    }

    final amount = await _pickPaymentAmountIqd(context, maxAmount);
    if (amount == null || !mounted) {
      return;
    }

    setState(() {
      _isStartingPayment = true;
    });

    try {
      final apiClient = context.read<ApiClient>();
      final checkoutRes = await apiClient.client.post(
        '/checkout',
        data: {
          'offerIds': [widget.offer.id],
          'paymentMethod': 'cash',
        },
      );

      final payload = checkoutRes.data;
      final items = payload is Map<String, dynamic>
          ? (payload['items'] as List<dynamic>? ?? const [])
          : const [];
      final firstItem = items.isNotEmpty && items.first is Map
          ? Map<String, dynamic>.from(items.first as Map)
          : null;

      final quoteId = firstItem?['quoteId']?.toString().trim() ?? '';
      final paymentId = firstItem?['paymentId']?.toString().trim() ?? '';

      if (quoteId.isEmpty || paymentId.isEmpty) {
        throw Exception('تعذر إنشاء الطلب للدفع الإلكتروني');
      }

      await apiClient.client.post(
        '/payments',
        data: {'quoteId': quoteId, 'amount': amount, 'method': 'online'},
      );

      final onlineRes = await apiClient.client.post(
        '/payments/$paymentId/online-checkout',
      );
      final onlinePayload = onlineRes.data;
      final checkoutUrl = onlinePayload is Map<String, dynamic>
          ? (onlinePayload['gatewayCheckoutUrl'] ??
                    onlinePayload['checkoutUrl'])
                ?.toString()
          : null;

      if (checkoutUrl == null || checkoutUrl.trim().isEmpty) {
        throw Exception('تعذر إنشاء رابط بوابة الدفع');
      }

      final launched = await _openExternalUrl(checkoutUrl);
      if (!mounted) {
        return;
      }

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            launched
                ? 'تم تحديد الموعد: ${_formatDateTime(scheduledAt)} • المبلغ: $amount IQD'
                : 'تعذر فتح بوابة الدفع، حاول من صفحة المدفوعات',
          ),
        ),
      );
    } on DioException catch (e) {
      final responseData = e.response?.data;
      final message = responseData is Map<String, dynamic>
          ? responseData['error']?.toString()
          : null;
      messenger.showSnackBar(
        SnackBar(content: Text(message ?? 'فشل فتح بوابة الدفع')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() {
          _isStartingPayment = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.offer.mediaItems.isNotEmpty) {
      _mediaItems = List<OfferMediaItem>.from(widget.offer.mediaItems)
        ..sort((a, b) {
          final aImg = a.type != 'video' && !_isVideoUrl(a.url);
          final bImg = b.type != 'video' && !_isVideoUrl(b.url);
          if (aImg && !bImg) return -1;
          if (!aImg && bImg) return 1;
          return 0;
        });
    } else if (widget.offer.imageUrl.trim().isNotEmpty) {
      final url = widget.offer.imageUrl.trim();
      _mediaItems = [
        OfferMediaItem(
          rawUrl: url,
          url: normalizePublicMediaUrl(url),
          type: _isVideoUrl(url) ? 'video' : 'image',
        ),
      ];
    } else {
      final primary = widget.offer.primaryMediaUrl.trim();
      if (primary.isNotEmpty) {
        _mediaItems = [
          OfferMediaItem(
            rawUrl: primary,
            url: normalizePublicMediaUrl(primary),
            type: _isVideoUrl(primary) ? 'video' : 'image',
          ),
        ];
      } else {
        _mediaItems = const [];
      }
    }
    if (kDebugMode) {
      debugPrint(
          "DEBUG OfferDetailsScreen [${widget.offer.id}] mediaItems.final.len=${_mediaItems.length}");
      for (int i = 0; i < _mediaItems.length; i++) {
        final m = _mediaItems[i];
        debugPrint(
            "  ... media[$i] final type=${m.type} raw='${m.rawUrl}' normalized='${m.url}'");
      }
    }
    _isSaved = widget.offer.likedByMe;
    _setActiveMedia(0);
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  void _setActiveMedia(int index) {
    if (_mediaItems.isEmpty) {
      setState(() {
        _activeIndex = 0;
      });
      return;
    }

    final boundedIndex = index.clamp(0, _mediaItems.length - 1);
    final rawUrl = _mediaItems[boundedIndex].url;
    final url = _normalizeMediaUrl(rawUrl);
    final isVideo =
        _isVideoUrl(url) || _mediaItems[boundedIndex].type == 'video';

    _videoController?.dispose();
    _videoController = null;
    _videoInitFuture = null;

    setState(() {
      _activeIndex = boundedIndex;
    });

    if (isVideo && url.isNotEmpty) {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(url))
        ..setLooping(true);
      _videoInitFuture = _videoController!.initialize().then((_) {
        if (mounted) {
          setState(() {});
          _videoController!.play();
        }
      });
    }
  }

  String _normalizeMediaUrl(String raw) {
    return normalizePublicMediaUrl(raw);
  }

  bool _isVideoUrl(String url) {
    if (url.isEmpty) return false;
    final lower = url.toLowerCase();
    if (lower.contains('/videos/')) return true;
    final videoExt = ['.mp4', '.mov', '.webm', '.mkv', '.m3u8'];
    return videoExt
        .any((ext) => lower.contains('$ext?') || lower.endsWith(ext));
  }

  Future<void> _toggleSaved() async {
    final auth = context.read<AuthService>();
    final currentUser = auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('سجل الدخول أولاً')),
      );
      return;
    }
    if (currentUser.id.trim() == widget.offer.creatorId.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكنك حفظ عرضك الخاص')),
      );
      return;
    }
    if (_isSavingFavorite) return;

    setState(() => _isSavingFavorite = true);
    try {
      final liked =
          await context.read<MediaService>().toggleOfferLike(widget.offer.id);
      if (!mounted) return;
      setState(() {
        _isSaved = liked;
        _isSavingFavorite = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(liked ? 'تمت الإضافة إلى المحفوظات' : 'تمت الإزالة من المحفوظات'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSavingFavorite = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تحديث المحفوظات')),
      );
    }
  }

  Future<void> _reportOffer() async {
    final auth = context.read<AuthService>();
    final currentUser = auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('سجل الدخول أولاً')),
      );
      return;
    }
    if (currentUser.id.trim() == widget.offer.creatorId.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكنك الإبلاغ عن عرضك الخاص')),
      );
      return;
    }

    await showReportDialog(
      context: context,
      title: 'الإبلاغ عن العرض',
      onSubmit: (reason, details) {
        return context.read<MediaService>().reportContent(
              targetType: 'offer',
              targetId: widget.offer.id,
              reason: reason,
              details: details,
            );
      },
    );
  }

  Widget _buildMediaFor(int index) {
    if (_mediaItems.isEmpty) {
      return Container(
        color: const Color(0x801E1E2D),
        alignment: Alignment.center,
        child: const Icon(Icons.image_not_supported,
            size: 48, color: Colors.white54),
      );
    }

    final item = _mediaItems[index];
    final url = _normalizeMediaUrl(item.url);
    final isVideo = item.type == 'video' || _isVideoUrl(url);

    if (url.isEmpty) {
      return Container(
        color: const Color(0x801E1E2D),
        alignment: Alignment.center,
        child: const Icon(Icons.image_not_supported,
            size: 48, color: Colors.white54),
      );
    }

    if (isVideo) {
      if (index != _activeIndex) {
        final normalized = _normalizeMediaUrl(item.url);
        return Stack(
          fit: StackFit.expand,
          children: [
            if (_videoController != null &&
                _activeIndex == index &&
                _videoController!.value.isInitialized)
              FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: _videoController!.value.size.width,
                  height: _videoController!.value.size.height,
                  child: VideoPlayer(_videoController!),
                ),
              )
            else
              Image.network(
                normalized,
                fit: BoxFit.cover,
                errorBuilder: (context, err, stack) {
                  debugPrint(
                      "❌ OfferDetails VIDEO-THUMB [$index] LOAD ERROR → URL='$normalized' (raw='${item.rawUrl}') ERROR=$err");
                  return Container(
                    color: const Color(0x801E1E2D),
                    alignment: Alignment.center,
                    child: const Icon(Icons.videocam_rounded,
                        color: Colors.white70, size: 56),
                  );
                },
              ),
            Container(
              color: Colors.black12,
              alignment: Alignment.center,
              child: const Icon(
                Icons.play_circle_fill_rounded,
                color: Colors.white,
                size: 64,
                shadows: [
                  BoxShadow(color: Colors.black45, blurRadius: 10, spreadRadius: 2)
                ],
              ),
            ),
          ],
        );
      }
      return FutureBuilder<void>(
        future: _videoInitFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done ||
              _videoController == null ||
              !_videoController!.value.isInitialized) {
            return Container(
              color: Colors.black,
              alignment: Alignment.center,
              child: const CircularProgressIndicator(color: Colors.white),
            );
          }
          return FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: _videoController!.value.size.width,
              height: _videoController!.value.size.height,
              child: VideoPlayer(_videoController!),
            ),
          );
        },
      );
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: const Color(0x801E1E2D),
          alignment: Alignment.center,
          child: const CircularProgressIndicator(color: Colors.white),
        );
      },
      errorBuilder: (context, err, stack) {
        debugPrint(
            "❌ OfferDetails IMAGE [$index] LOAD ERROR → URL='$url' (raw='${item.rawUrl}') ERROR=$err");
        return Container(
          color: const Color(0x801E1E2D),
          alignment: Alignment.center,
          child: const Icon(Icons.image_not_supported,
              size: 48, color: Colors.white60),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartService>();
    final auth = context.watch<AuthService>();
    final currentUser = auth.currentUser;
    final isInCart = cart.contains(widget.offer.id);
    final canSave = currentUser != null &&
        currentUser.id.trim() != widget.offer.creatorId.trim();
    final canReport = canSave;
    final canPay = currentUser != null &&
        !auth.isCreator &&
        currentUser.id.trim() != widget.offer.creatorId.trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل العرض'),
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: Colors.white,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        actions: [
          if (canSave)
            IconButton(
              onPressed: _isSavingFavorite ? null : _toggleSaved,
              icon: _isSavingFavorite
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      _isSaved ? Icons.favorite : Icons.favorite_border,
                      color: _isSaved ? Colors.redAccent : Colors.white,
                    ),
            ),
          if (canReport)
            IconButton(
              onPressed: _reportOffer,
              icon: const Icon(Icons.flag_outlined, color: Colors.white),
            ),
        ],
      ),
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 10,
              child: _mediaItems.length <= 1
                  ? _buildMediaFor(_activeIndex)
                  : PageView.builder(
                      itemCount: _mediaItems.length,
                      onPageChanged: _setActiveMedia,
                      itemBuilder: (_, index) => _buildMediaFor(index),
                    ),
            ),
            if (_mediaItems.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _mediaItems.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: index == _activeIndex ? 18 : 7,
                      height: 7,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: index == _activeIndex
                            ? const LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: AppColors.accentGradient,
                              )
                            : null,
                        color: index == _activeIndex
                            ? null
                            : Colors.white.withValues(alpha: 0.18),
                        boxShadow: index == _activeIndex
                            ? AppShadows.glowAccent
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.offer.title,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  if (widget.offer.creatorName.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        final cid = widget.offer.creatorId.trim();
                        if (cid.isEmpty) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CreatorProfileScreen(userId: cid),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 4, horizontal: 2),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.person_outline_rounded,
                              size: 18,
                              color: Colors.white70,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.offer.creatorName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blueAccent,
                                  decoration: TextDecoration.underline,
                                  decorationColor: Colors.blueAccent,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_forward_ios_rounded,
                                size: 14, color: Colors.white38),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    '${widget.offer.price.toStringAsFixed(0)} IQD',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.offer.displayDescription.isEmpty
                        ? 'لا يوجد وصف متاح.'
                        : widget.offer.displayDescription,
                    style: const TextStyle(fontSize: 15, height: 1.6),
                  ),
                  const SizedBox(height: 24),
                  if (canPay) ...[
                    SizedBox(
                      width: double.infinity,
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: AppColors.accentGradient,
                          ),
                          boxShadow: AppShadows.glowAccent,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: _isStartingPayment
                                ? null
                                : _startOnlinePayment,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _isStartingPayment
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.payment,
                                        color: Colors.white,
                                      ),
                                const SizedBox(width: 10),
                                Text(
                                  _isStartingPayment
                                      ? '...جارٍ التحويل'
                                      : 'متابعة الدفع',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: AppColors.accentGradient,
                        ),
                        boxShadow: AppShadows.glowAccent,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            if (isInCart) {
                              cart.remove(widget.offer.id);
                            } else {
                              cart.add(widget.offer);
                            }

                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (_) => const MainNavigation(
                                  initialIndex: 3,
                                ),
                              ),
                              (route) => false,
                            );
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isInCart
                                    ? Icons.remove_shopping_cart
                                    : Icons.add_shopping_cart,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                isInCart ? 'إزالة من الطلب' : 'إضافة إلى الطلب',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
