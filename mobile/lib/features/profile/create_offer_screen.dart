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
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;

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

  int? _parseDiscountPercent() {
    if (_offerType != "عرض خصم" || _discountPercentage == null) return null;
    final raw = _discountPercentage!.replaceAll('%', '').trim();
    return int.tryParse(raw);
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.initialItem != null;

    return Scaffold(
      backgroundColor: const Color(0xFF161921),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161921),
        elevation: 0,
        centerTitle: true,
        title: Text(isEditing ? "تعديل العرض" : "قائمة العروض",
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        leading: TextButton(
          onPressed: _publishOffer,
          style: TextButton.styleFrom(
            backgroundColor: const Color(0xFF7A3EED),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(isEditing ? "حفظ" : "نشر",
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        leadingWidth: 92,
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
                              TextStyle(color: Colors.black54))), // "Choose..."
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.black),
                  style: const TextStyle(color: Colors.black87, fontSize: 15),
                  isExpanded: true,
                  items: _offerTypes
                      .map((e) => DropdownMenuItem(
                            value: e,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                e,
                                style: const TextStyle(color: Colors.black87),
                              ),
                            ),
                          ))
                      .toList(),
                  onChanged: (val) => setState(() => _offerType = val),
                  dropdownColor: Colors.grey[300],
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
                              color: Colors.black54))), // "Choose Discount..."
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.black),
                  style: const TextStyle(color: Colors.black87, fontSize: 15),
                  isExpanded: true,
                  menuMaxHeight: 280,
                  items: _discounts
                      .map((e) => DropdownMenuItem(
                            value: e,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                e,
                                style: const TextStyle(color: Colors.black87),
                              ),
                            ),
                          ))
                      .toList(),
                  onChanged: (val) => setState(() => _discountPercentage = val),
                  dropdownColor: Colors.grey[300],
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
        color: Colors.grey[400],
        borderRadius: BorderRadius.circular(25),
      ),
      child: child,
    );
  }

  Widget _buildTextField({
    required String hint,
    required TextEditingController controller,
    int maxLines = 1,
    double? height,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[400],
        borderRadius: BorderRadius.circular(25),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        textAlign: TextAlign.right, // RTL
        textDirection: TextDirection.rtl,
        textAlignVertical:
            maxLines > 1 ? TextAlignVertical.top : TextAlignVertical.center,
        cursorColor: Colors.black87,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 15,
          height: 1.5,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: const TextStyle(
            color: Colors.black54,
            fontSize: 15,
            height: 1.5,
          ),
          contentPadding: EdgeInsets.only(top: maxLines > 1 ? 10 : 0),
        ),
      ),
    );
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
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[400]!),
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
          color: enabled ? Colors.grey[200] : Colors.grey[300],
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, color: Colors.black54),
                SizedBox(height: 4),
                Text(
                  "اضافة",
                  style: TextStyle(color: Colors.black54, fontSize: 12),
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

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final mediaService = context.read<MediaService>();
    final bool isEditing = widget.initialItem != null;
    final parsedPrice = _parsePriceValue(_priceController.text);
    final discountPercent = _parseDiscountPercent();
    final originalPrice =
        (discountPercent != null && discountPercent > 0) ? parsedPrice : null;
    final finalPrice = (discountPercent != null && discountPercent > 0)
        ? double.parse(
            (parsedPrice * (1 - (discountPercent / 100))).toStringAsFixed(2),
          )
        : parsedPrice;

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
