import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_service.dart';
import '../../core/design/design_tokens.dart';
import '../../core/theme/app_theme_service.dart';
import '../../core/services/media_service.dart';

// Punkt 7: Status för varje uppladdningsfil (laddningslista)
enum _StepStatus { waiting, uploading, success, error }

class CreateOfferScreen extends StatefulWidget {
  final Map<String, dynamic>? initialItem;

  const CreateOfferScreen({super.key, this.initialItem});

  @override
  State<CreateOfferScreen> createState() => _CreateOfferScreenState();
}

class _CreateOfferScreenState extends State<CreateOfferScreen> {
  static const double _minimumOfferPrice = 1200;

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  late final TextEditingController _partialPaymentController;
  late final TextEditingController _fullPaymentController;

  String? _offerType;
  final List<String> _offerTypes = [
    "عرض شامل",
    "عرض خصم"
  ]; // Comprehensive, Discount

  String? _discountPercentage;
  final List<String> _discounts =
      List<String>.generate(20, (index) => "${(index + 1) * 5}%");

  final List<File> _selectedImages = [];
  File? _selectedVideo;
  List<dynamic>? _initialMediaItems;
  String? _initialImageUrl;
  bool _isPublishing = false;

  List<Map<String, dynamic>> _publishQueue = [];
  String _publishStage = '';

  void _preparePublishQueue() {
    _publishQueue = [];
    int sortOrder = 0;
    for (final img in _selectedImages) {
      final len = img.lengthSync();
      _publishQueue.add({
        'name': img.path.split(Platform.pathSeparator).last,
        'type': 'image',
        'sizeBytes': len,
        'sizeMb': (len / (1024 * 1024)).toStringAsFixed(2),
        'status': _StepStatus.waiting,
        'order': sortOrder++,
      });
    }
    final vid = _selectedVideo;
    if (vid != null) {
      final len = vid.lengthSync();
      _publishQueue.add({
        'name': vid.path.split(Platform.pathSeparator).last,
        'type': 'video',
        'sizeBytes': len,
        'sizeMb': (len / (1024 * 1024)).toStringAsFixed(2),
        'status': _StepStatus.waiting,
        'order': sortOrder++,
      });
    }
    _publishQueue.sort((a, b) => (a['order'] as int).compareTo(b['order'] as int));
  }

  // Punkt 7: Uppdatera status för kö-poster
  void _setQueueItemStatusAt(int order, _StepStatus status) {
    if (order < 0 || order >= _publishQueue.length) return;
    _publishQueue[order]['status'] = status;
    if (mounted) setState(() {});
  }

  void _setAllQueueStatus(String type, _StepStatus status) {
    for (int i = 0; i < _publishQueue.length; i++) {
      if (_publishQueue[i]['type'] == type) {
        _publishQueue[i]['status'] = status;
      }
    }
    if (mounted) setState(() {});
  }

  void _updatePublishStage(String text) {
    _publishStage = text;
    if (mounted) setState(() {});
  }

  // Punkt 7: Bygg widget för varje rad i laddningslistan
  Widget _buildQueueRow(Map<String, dynamic> item) {
    final theme = context.watch<AppThemeService>();
    final colors = theme.colors;
    final config = theme.config;
    final _StepStatus status = item['status'] as _StepStatus;
    final bool isImage = item['type'] == 'image';
    Color bg = colors.textTertiary.withValues(alpha: 0.10);
    IconData icon = Icons.help_outline;
    String statusText = "-";
    Color iconColor = colors.textTertiary;
    final bool isUploading = status == _StepStatus.uploading;
    if (status == _StepStatus.waiting) {
      bg = colors.warning.withValues(alpha: 0.12);
      icon = Icons.hourglass_empty;
      statusText = "في الانتظار";
      iconColor = colors.warning;
    } else if (status == _StepStatus.uploading) {
      bg = colors.info.withValues(alpha: 0.14);
      icon = Icons.upload_file_rounded;
      statusText = "جاري الرفع...";
      iconColor = colors.primary;
    } else if (status == _StepStatus.success) {
      bg = colors.success.withValues(alpha: 0.12);
      icon = Icons.check_circle;
      statusText = "تم";
      iconColor = colors.success;
    } else if (status == _StepStatus.error) {
      bg = colors.error.withValues(alpha: 0.12);
      icon = Icons.error_outline;
      statusText = "فشل";
      iconColor = colors.error;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.borderLight),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isImage
                  ? colors.info.withValues(alpha: 0.20)
                  : colors.error.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isImage ? Icons.image : Icons.videocam_rounded,
              size: 18,
              color: isImage ? colors.primary : colors.error,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  "${isImage ? 'صورة' : 'فيديو'} • ${item['sizeMb']} MB • $statusText",
                  style: TextStyle(
                    color: colors.textSecondary.withValues(alpha: 0.85),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            icon,
            color: iconColor,
            size: 22,
          ),
          if (isUploading) ...[
            const SizedBox(width: 6),
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Punkt 7: Dialog med lista över alla uppladdningsfiler
  Widget _buildPublishQueueDialog() {
    final theme = context.watch<AppThemeService>();
    final colors = theme.colors;
    final config = theme.config;
    return Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [colors.accentPink, colors.primaryDark],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.cloud_upload_rounded,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "جاري النشر",
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "يرجى عدم إغلاق الشاشة",
                        style: TextStyle(
                          color: colors.textSecondary.withValues(alpha: 0.85),
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (_publishQueue.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator(color: colors.textSecondary)),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _publishQueue.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 9),
                  itemBuilder: (ctx, idx) => _buildQueueRow(_publishQueue[idx]),
                ),
              ),
            if (_publishStage.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.borderLight),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.accentPink,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _publishStage,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.initialItem?['title']);
    _descriptionController =
        TextEditingController(text: widget.initialItem?['description']);
    _priceController = TextEditingController(
        text: widget.initialItem?['price_iqd']?.toString());
    _partialPaymentController = TextEditingController(
      text: _formatAmountText(widget.initialItem?['partial_payment_iqd']),
    );
    _fullPaymentController = TextEditingController(
      text: _formatAmountText(
        widget.initialItem?['full_payment_iqd'] ?? widget.initialItem?['price_iqd'],
      ),
    );
    _initialImageUrl = widget.initialItem?['image_url'];
    final rawMediaItems = widget.initialItem?['media_items'];
    if (rawMediaItems is List) {
      _initialMediaItems = rawMediaItems;
    } else if (_initialImageUrl != null &&
        _initialImageUrl!.trim().isNotEmpty) {
      _initialMediaItems = [
        {
          'url': _initialImageUrl,
          'type': _isVideoUrl(_initialImageUrl) ? 'video' : 'image'
        }
      ];
    }
    final initialDiscount = widget.initialItem?['discount_percent'];
    if (initialDiscount is num && initialDiscount > 0) {
      _discountPercentage = "${initialDiscount.toInt()}%";
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _partialPaymentController.dispose();
    _fullPaymentController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    final theme = context.read<AppThemeService>();
    final colors = theme.colors;
    final config = theme.config;
    final selection = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.image, color: colors.info),
              title: const Text("رفع صورة"),
              onTap: () => Navigator.pop(context, "image"),
            ),
            ListTile(
              leading: Icon(Icons.videocam, color: colors.error),
              title: const Text("رفع فيديو"),
              onTap: () => Navigator.pop(context, "video"),
            ),
          ],
        ),
      ),
    );
    if (!mounted || selection == null) return;

    final mediaService = context.read<MediaService>();
    if (selection == "video") {
      if (_selectedVideo != null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("يمكنك رفع فيديو واحد فقط")));
        return;
      }
      final file = await mediaService.pickVideo();
      if (file != null) {
        setState(() {
          _selectedVideo = file;
        });
      }
      return;
    }

    if (_selectedImages.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("يمكنك رفع 3 صور كحد أقصى")));
      return;
    }
    final file = await mediaService.pickImage();
    if (file != null) {
      setState(() {
        _selectedImages.add(file);
      });
    }
  }

  bool _isVideoUrl(String? value) {
    if (value == null || value.trim().isEmpty) return false;
    final lower = value.toLowerCase();
    if (lower.contains('/videos/')) return true;
    const videoExt = ['.mp4', '.mov', '.webm', '.mkv', '.m3u8'];
    return videoExt
        .any((ext) => lower.contains('$ext?') || lower.endsWith(ext));
  }

  double _parsePriceValue(String raw) {
    if (raw.trim().isEmpty) return 0.0;

    const arabicDigits = {
      '٠': '0',
      '١': '1',
      '٢': '2',
      '٣': '3',
      '٤': '4',
      '٥': '5',
      '٦': '6',
      '٧': '7',
      '٨': '8',
      '٩': '9',
      '٫': '.',
      '٬': '',
      ',': '.',
    };

    var normalized = raw.trim();
    arabicDigits.forEach((from, to) {
      normalized = normalized.replaceAll(from, to);
    });
    normalized = normalized.replaceAll(RegExp(r'[^0-9.]'), '');

    return double.tryParse(normalized) ?? 0.0;
  }

  String _formatAmountText(dynamic value) {
    if (value == null) return '';
    final parsed = _parsePriceValue(value.toString());
    if (parsed <= 0) return '';
    if (parsed == parsed.roundToDouble()) {
      return parsed.toStringAsFixed(0);
    }
    return parsed.toStringAsFixed(2);
  }

  int? _parseDiscountPercent() {
    if (_offerType != "عرض خصم" || _discountPercentage == null) return null;
    final raw = _discountPercentage!.replaceAll('%', '').trim();
    return int.tryParse(raw);
  }

  Widget _buildSaveButton(bool isEditing) {
    final theme = context.watch<AppThemeService>();
    final colors = theme.colors;
    final config = theme.config;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [colors.accentPink, colors.primaryDark],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: colors.accentPink.withValues(alpha: 0.30),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: colors.primaryDark.withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: InkWell(
          onTap: _isPublishing ? null : _publishOffer,
          child: Center(
            child: _isPublishing
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.textPrimary,
                    ),
                  )
                : Text(
                    isEditing ? "حفظ" : "نشر",
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppThemeService>();
    final colors = theme.colors;
    final config = theme.config;
    final bool isEditing = widget.initialItem != null;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: colors.background,
        elevation: 0,
        centerTitle: true,
        title: Text(isEditing ? "تعديل العرض" : "قائمة العروض",
            style: TextStyle(
                color: colors.textPrimary, fontWeight: FontWeight.bold)),
        leading: Padding(
          padding: const EdgeInsets.only(left: 10, top: 6, bottom: 6),
          child: SizedBox.expand(
            child: _buildSaveButton(isEditing),
          ),
        ),
        leadingWidth: 98,
        actions: [
          IconButton(
            icon: Icon(Icons.close, color: colors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 1. Offer Type Dropdown
            _buildDropdownContainer(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _offerType,
                  hint: Align(
                      alignment: Alignment.centerRight,
                      child: Text("اختر ...",
                          style:
                              TextStyle(color: colors.textTertiary))), // "Choose..."
                  icon: Icon(Icons.arrow_drop_down, color: colors.textSecondary),
                  style: TextStyle(color: colors.textPrimary, fontSize: 15),
                  isExpanded: true,
                  items: _offerTypes
                      .map((e) => DropdownMenuItem(
                            value: e,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                e,
                                style: TextStyle(color: colors.textPrimary),
                              ),
                            ),
                          ))
                      .toList(),
                  onChanged: (val) => setState(() => _offerType = val),
                  dropdownColor: colors.surface,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 2. Title Field
            _buildTextField(
              hint: "عنوان العرض", // "Offer Title"
              controller: _titleController,
            ),
            const SizedBox(height: 20),

            // 3. Description Field
            _buildTextField(
              hint: "وصف او شرح حول العرض", // "Description..."
              controller: _descriptionController,
              maxLines: 5,
              height: 150,
            ),
            const SizedBox(height: 20),

            // Price Field
            _buildTextField(
              hint: "السعر (د.ع)", // Price
              controller: _priceController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),

            _buildTextField(
              hint: "مبلغ الدفعة الجزئية للعميل (د.ع)",
              controller: _partialPaymentController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              hint: "مبلغ الدفع الكامل للعميل (د.ع)",
              controller: _fullPaymentController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Color.lerp(colors.background, colors.surface, 0.78)!,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.borderLight),
              ),
              child: Text(
                "يمكنك تحديد مبلغ الدفعة الجزئية ومبلغ الدفع الكامل كما يظهر للعميل. إذا تركت الحقول فارغة سيتم اعتماد 30% للدفعة الجزئية وسعر العرض الحالي للدفع الكامل.",
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 12,
                  height: 1.55,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Media Upload Section
            _buildMediaPicker(),
            const SizedBox(height: 20),

            // 4. Discount Dropdown
            _buildDropdownContainer(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _discountPercentage,
                  hint: Align(
                      alignment: Alignment.centerRight,
                      child: Text("اختر نسبة الخصم ...",
                          style: TextStyle(
                              color: colors.textTertiary))), // "Choose Discount..."
                  icon: Icon(Icons.arrow_drop_down, color: colors.textSecondary),
                  style: TextStyle(color: colors.textPrimary, fontSize: 15),
                  isExpanded: true,
                  menuMaxHeight: 280,
                  items: _discounts
                      .map((e) => DropdownMenuItem(
                            value: e,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                e,
                                style: TextStyle(color: colors.textPrimary),
                              ),
                            ),
                          ))
                      .toList(),
                  onChanged: (val) => setState(() => _discountPercentage = val),
                  dropdownColor: colors.surface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownContainer({required Widget child}) {
    final theme = context.watch<AppThemeService>();
    final colors = theme.colors;
    final config = theme.config;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  InputDecoration _buildInputDecoration(String hint) {
    final theme = context.watch<AppThemeService>();
    final colors = theme.colors;
    final config = theme.config;
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: colors.textTertiary,
        fontSize: 15,
        height: 1.5,
      ),
      filled: true,
      fillColor: colors.surface,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: colors.borderLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: colors.accentPink, width: 1.2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _buildTextField({
    required String hint,
    required TextEditingController controller,
    int maxLines = 1,
    double? height,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final theme = context.watch<AppThemeService>();
    final colors = theme.colors;
    final config = theme.config;
    final field = TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textAlign: TextAlign.right,
      textDirection: TextDirection.rtl,
      textAlignVertical:
          maxLines > 1 ? TextAlignVertical.top : TextAlignVertical.center,
      cursorColor: colors.accentPink,
      style: TextStyle(
        color: colors.textPrimary,
        fontSize: 15,
        height: 1.5,
      ),
      decoration: _buildInputDecoration(hint),
    );

    if (height == null) {
      return field;
    }

    return SizedBox(height: height, child: field);
  }

  Widget _buildMediaPicker() {
    final theme = context.watch<AppThemeService>();
    final colors = theme.colors;
    final config = theme.config;
    final selectedTiles = <Widget>[];
    for (int i = 0; i < _selectedImages.length; i++) {
      selectedTiles.add(_buildLocalImageTile(_selectedImages[i], i));
    }
    if (_selectedVideo != null) {
      selectedTiles.add(_buildLocalVideoTile());
    }

    final initialTiles = <Widget>[];
    if (selectedTiles.isEmpty && (_initialMediaItems?.isNotEmpty ?? false)) {
      for (final item in _initialMediaItems!) {
        if (item is! Map) continue;
        final rawUrl = item['url']?.toString() ?? '';
        if (rawUrl.trim().isEmpty) continue;
        final isVideo =
            (item['type']?.toString() == 'video') || _isVideoUrl(rawUrl);
        initialTiles.add(_buildRemoteTile(rawUrl, isVideo));
      }
    }

    final tiles = selectedTiles.isNotEmpty ? selectedTiles : initialTiles;

    tiles.add(_buildAddTile());

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color.lerp(colors.background, colors.surface, 0.78)!,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        alignment: WrapAlignment.end,
        children: tiles,
      ),
    );
  }

  Widget _buildTileFrame({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(width: 110, height: 80, child: child),
    );
  }

  Widget _buildLocalImageTile(File file, int index) {
    final theme = context.watch<AppThemeService>();
    final colors = theme.colors;
    final config = theme.config;
    return Stack(
      children: [
        _buildTileFrame(
          child: Image.file(file, fit: BoxFit.cover),
        ),
        Positioned(
          top: 4,
          left: 4,
          child: InkWell(
            onTap: () {
              setState(() {
                _selectedImages.removeAt(index);
              });
            },
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: colors.textTertiary.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.close, size: 16, color: colors.textPrimary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocalVideoTile() {
    final theme = context.watch<AppThemeService>();
    final colors = theme.colors;
    final config = theme.config;
    return Stack(
      children: [
        _buildTileFrame(
          child: Container(
            color: Colors.black87,
            child: Center(
              child:
                  Icon(Icons.videocam_rounded, color: colors.textPrimary, size: 30),
            ),
          ),
        ),
        Positioned(
          top: 4,
          left: 4,
          child: InkWell(
            onTap: () {
              setState(() {
                _selectedVideo = null;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: colors.textTertiary.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.close, size: 16, color: colors.textPrimary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRemoteTile(String rawUrl, bool isVideo) {
    final theme = context.watch<AppThemeService>();
    final colors = theme.colors;
    final config = theme.config;
    final url = rawUrl.startsWith('/') ? "https://sawrly.com$rawUrl" : rawUrl;
    if (isVideo) {
      return _buildTileFrame(
        child: Container(
          color: Colors.black87,
          child: Center(
            child: Icon(Icons.videocam_rounded, color: colors.textPrimary, size: 30),
          ),
        ),
      );
    }
    return _buildTileFrame(
      child: Image.network(url, fit: BoxFit.cover),
    );
  }

  Widget _buildAddTile() {
    final theme = context.watch<AppThemeService>();
    final colors = theme.colors;
    final config = theme.config;
    final canAddImage = _selectedImages.length < 3;
    final canAddVideo = _selectedVideo == null;
    final enabled = canAddImage || canAddVideo;
    return InkWell(
      onTap: enabled ? _pickMedia : null,
      child: _buildTileFrame(
        child: Container(
          decoration: BoxDecoration(
            color: enabled ? colors.surface : Color.lerp(colors.background, colors.surface, 0.78)!,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: enabled ? colors.accentPink.withValues(alpha: 0.35) : colors.borderLight,
            ),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: colors.accentPink.withValues(alpha: 0.22),
                      blurRadius: 16,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, color: colors.textSecondary),
                const SizedBox(height: 4),
                Text(
                  "اضافة",
                  style: TextStyle(color: colors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _publishOffer() async {
    if (_isPublishing) return;
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("العنوان مطلوب")));
      return;
    }
    final parsedPrice = _parsePriceValue(_priceController.text);
    if (parsedPrice < _minimumOfferPrice) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("أقل سعر للعرض هو 1200 دينار عراقي"),
        ),
      );
      return;
    }

    final discountPercent = _parseDiscountPercent();
    final originalPrice =
        (discountPercent != null && discountPercent > 0) ? parsedPrice : null;
    final finalPrice = (discountPercent != null && discountPercent > 0)
        ? double.parse(
            (parsedPrice * (1 - (discountPercent / 100))).toStringAsFixed(2),
          )
        : parsedPrice;
    if (finalPrice < _minimumOfferPrice) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("السعر النهائي بعد الخصم يجب أن يكون 1200 دينار عراقي أو أكثر"),
        ),
      );
      return;
    }
    final typedFullPayment = _parsePriceValue(_fullPaymentController.text);
    final fullPaymentAmount =
        typedFullPayment > 0 ? typedFullPayment : finalPrice;
    if (fullPaymentAmount < _minimumOfferPrice) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("مبلغ الدفع الكامل يجب أن يكون 1200 دينار عراقي أو أكثر"),
        ),
      );
      return;
    }
    final typedPartialPayment = _parsePriceValue(_partialPaymentController.text);
    final partialPaymentAmount = typedPartialPayment > 0
        ? typedPartialPayment
        : (fullPaymentAmount * 0.30).ceilToDouble();
    if (partialPaymentAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("مبلغ الدفعة الجزئية يجب أن يكون أكبر من صفر"),
        ),
      );
      return;
    }
    if (partialPaymentAmount >= fullPaymentAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("مبلغ الدفعة الجزئية يجب أن يكون أقل من مبلغ الدفع الكامل"),
        ),
      );
      return;
    }

    final bool isEditing = widget.initialItem != null;
    if (!isEditing) {
      final currentUser = context.read<AuthService>().currentUser;
      if (currentUser != null) {
        final existingOffers =
            await context.read<MediaService>().fetchOffers(currentUser.id);
        if (existingOffers.length >= 2) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("يمكنك نشر عرضين فقط كحد أقصى"),
            ),
          );
          return;
        }
      }
    }

    if (!mounted) return;
    final dialogContext = context;
    final mediaService = dialogContext.read<MediaService>();

    setState(() => _isPublishing = true);

    // Punkt 7: Förbered kön och visa laddningslista
    _preparePublishQueue();
    _updatePublishStage("جاري التحضير...");
    showDialog(
      context: dialogContext,
      barrierDismissible: false,
      builder: (context) => _buildPublishQueueDialog(),
    );

    try {
      String description = _descriptionController.text;
      if (_offerType != null) description = "Type: $_offerType\n$description";

      // Punkt 7: Markera bilder som laddas upp (om det finns några)
      if (_selectedImages.isNotEmpty) {
        _setAllQueueStatus('image', _StepStatus.uploading);
        _updatePublishStage("جاري رفع الصور...");
        await Future.delayed(const Duration(milliseconds: 250));
      }

      // Punkt 7: Markera video som laddas upp
      if (_selectedVideo != null) {
        _setAllQueueStatus('video', _StepStatus.uploading);
        _updatePublishStage(_selectedImages.isNotEmpty
            ? "جاري رفع الفيديو..."
            : "جاري رفع الفيديو...");
        await Future.delayed(const Duration(milliseconds: 200));
      }

      String? error;
      _updatePublishStage(isEditing ? "جاري تحديث العرض..." : "جاري إرسال العرض إلى السيرفر...");

      if (isEditing) {
        error = await mediaService.updateOffer(
          id: widget.initialItem!['id'].toString(),
          title: _titleController.text,
          description: description,
          price: finalPrice,
          images: _selectedImages.isNotEmpty
              ? List<File>.from(_selectedImages)
              : null,
          video: _selectedVideo,
          discountPercent: discountPercent,
          originalPrice: originalPrice,
          partialPaymentAmount: partialPaymentAmount,
          fullPaymentAmount: fullPaymentAmount,
        );
      } else {
        error = await mediaService.createOffer(
          _titleController.text,
          description,
          finalPrice,
          List<File>.from(_selectedImages),
          _selectedVideo,
          discountPercent: discountPercent,
          originalPrice: originalPrice,
          partialPaymentAmount: partialPaymentAmount,
          fullPaymentAmount: fullPaymentAmount,
        );
      }

      // Punkt 7: Uppdatera slutlig status
      if (error == null) {
        _setAllQueueStatus('image', _StepStatus.success);
        _setAllQueueStatus('video', _StepStatus.success);
        _updatePublishStage("اكتمل بنجاح");
        await Future.delayed(const Duration(milliseconds: 400));
      } else {
        _setAllQueueStatus('image', _StepStatus.error);
        _setAllQueueStatus('video', _StepStatus.error);
      }

      if (mounted) Navigator.pop(context); // Dismiss loading

      if (error == null && mounted) {
        Navigator.pop(context, true); // Return true to indicate refresh needed
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(isEditing ? "تم التحديث بنجاح!" : "تم النشر بنجاح!")));
      } else if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("فشل: $error")));
      }
    } catch (e) {
      // Punkt 7: Markera som error
      _setAllQueueStatus('image', _StepStatus.error);
      _setAllQueueStatus('video', _StepStatus.error);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("خطأ: $e")));
      }
    } finally {
      if (mounted) {
        setState(() => _isPublishing = false);
      }
    }
  }
}
