import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/media_service.dart';

class CreateOfferScreen extends StatefulWidget {
  final Map<String, dynamic>? initialItem;

  const CreateOfferScreen({super.key, this.initialItem});

  @override
  State<CreateOfferScreen> createState() => _CreateOfferScreenState();
}

class _CreateOfferScreenState extends State<CreateOfferScreen> {
  static const double _minimumOfferPrice = 1200;
  static const Color _bg = Color(0xFF161921);
  static const Color _surface = Color(0xFF222734);
  static const Color _surfaceAlt = Color(0xFF1B1F2A);
  static const Color _accentPink = Color(0xFFFF4DA6);
  static const Color _accentPurple = Color(0xFF7A3EED);

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
    final selection = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image, color: Colors.blue),
              title: const Text("رفع صورة"),
              onTap: () => Navigator.pop(context, "image"),
            ),
            ListTile(
              leading: const Icon(Icons.videocam, color: Colors.red),
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
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [_accentPink, _accentPurple],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: _accentPink.withValues(alpha: 0.30),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: _accentPurple.withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: InkWell(
          onTap: _publishOffer,
          child: Center(
            child: Text(
              isEditing ? "حفظ" : "نشر",
              style: const TextStyle(
                color: Colors.white,
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
    final bool isEditing = widget.initialItem != null;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: _bg,
        elevation: 0,
        centerTitle: true,
        title: Text(isEditing ? "تعديل العرض" : "قائمة العروض",
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        leading: Padding(
          padding: const EdgeInsets.only(left: 10, top: 6, bottom: 6),
          child: SizedBox.expand(
            child: _buildSaveButton(isEditing),
          ),
        ),
        leadingWidth: 98,
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
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
                  hint: const Align(
                      alignment: Alignment.centerRight,
                      child: Text("اختر ...",
                          style:
                              TextStyle(color: Colors.white54))), // "Choose..."
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  isExpanded: true,
                  items: _offerTypes
                      .map((e) => DropdownMenuItem(
                            value: e,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                e,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ))
                      .toList(),
                  onChanged: (val) => setState(() => _offerType = val),
                  dropdownColor: _surface,
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
                color: _surfaceAlt,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: const Text(
                "يمكنك تحديد مبلغ الدفعة الجزئية ومبلغ الدفع الكامل كما يظهر للعميل. إذا تركت الحقول فارغة سيتم اعتماد 30% للدفعة الجزئية وسعر العرض الحالي للدفع الكامل.",
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: Colors.white70,
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
                  hint: const Align(
                      alignment: Alignment.centerRight,
                      child: Text("اختر نسبة الخصم ...",
                          style: TextStyle(
                              color: Colors.white54))), // "Choose Discount..."
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  isExpanded: true,
                  menuMaxHeight: 280,
                  items: _discounts
                      .map((e) => DropdownMenuItem(
                            value: e,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                e,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ))
                      .toList(),
                  onChanged: (val) => setState(() => _discountPercentage = val),
                  dropdownColor: _surface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownContainer({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
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
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Colors.white54,
        fontSize: 15,
        height: 1.5,
      ),
      filled: true,
      fillColor: _surface,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Colors.white12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _accentPink, width: 1.2),
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
    final field = TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textAlign: TextAlign.right,
      textDirection: TextDirection.rtl,
      textAlignVertical:
          maxLines > 1 ? TextAlignVertical.top : TextAlignVertical.center,
      cursorColor: _accentPink,
      style: const TextStyle(
        color: Colors.white,
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
        color: _surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
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
                color: Colors.black54,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.close, size: 16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocalVideoTile() {
    return Stack(
      children: [
        _buildTileFrame(
          child: Container(
            color: Colors.black87,
            child: const Center(
              child:
                  Icon(Icons.videocam_rounded, color: Colors.white, size: 30),
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
                color: Colors.black54,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.close, size: 16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRemoteTile(String rawUrl, bool isVideo) {
    final url = rawUrl.startsWith('/') ? "https://sawrly.com$rawUrl" : rawUrl;
    if (isVideo) {
      return _buildTileFrame(
        child: Container(
          color: Colors.black87,
          child: const Center(
            child: Icon(Icons.videocam_rounded, color: Colors.white, size: 30),
          ),
        ),
      );
    }
    return _buildTileFrame(
      child: Image.network(url, fit: BoxFit.cover),
    );
  }

  Widget _buildAddTile() {
    final canAddImage = _selectedImages.length < 3;
    final canAddVideo = _selectedVideo == null;
    final enabled = canAddImage || canAddVideo;
    return InkWell(
      onTap: enabled ? _pickMedia : null,
      child: _buildTileFrame(
        child: Container(
          decoration: BoxDecoration(
            color: enabled ? _surface : _surfaceAlt,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: enabled ? _accentPink.withValues(alpha: 0.35) : Colors.white12,
            ),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: _accentPink.withValues(alpha: 0.22),
                      blurRadius: 16,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, color: Colors.white70),
                SizedBox(height: 4),
                Text(
                  "اضافة",
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _publishOffer() async {
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

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final mediaService = context.read<MediaService>();
    final bool isEditing = widget.initialItem != null;

    try {
      String description = _descriptionController.text;
      if (_offerType != null) description = "Type: $_offerType\n$description";

      String? error;
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

      if (mounted) Navigator.pop(context); // Dismiss loading

      if (error == null && mounted) {
        Navigator.pop(context, true); // Return true to indicate refresh needed
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(isEditing ? "تم التحديث بنjاج!" : "تم النشر بنjاج!")));
      } else if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("فشل: $error")));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("خطأ: $e")));
      }
    }
  }
}
