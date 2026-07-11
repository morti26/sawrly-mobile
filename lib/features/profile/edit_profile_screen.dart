import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/services/media_service.dart';
import '../../models/user.dart';
import '../../core/auth/auth_service.dart';

const List<String> _allCountries = [
  'Afghanistan',
  'Albania',
  'Algeria',
  'Andorra',
  'Angola',
  'Antigua and Barbuda',
  'Argentina',
  'Armenia',
  'Australia',
  'Austria',
  'Azerbaijan',
  'Bahamas',
  'Bahrain',
  'Bangladesh',
  'Barbados',
  'Belarus',
  'Belgium',
  'Belize',
  'Benin',
  'Bhutan',
  'Bolivia',
  'Bosnia and Herzegovina',
  'Botswana',
  'Brazil',
  'Brunei',
  'Bulgaria',
  'Burkina Faso',
  'Burundi',
  'Cabo Verde',
  'Cambodia',
  'Cameroon',
  'Canada',
  'Central African Republic',
  'Chad',
  'Chile',
  'China',
  'Colombia',
  'Comoros',
  'Congo',
  'Costa Rica',
  'Croatia',
  'Cuba',
  'Cyprus',
  'Czech Republic',
  'Denmark',
  'Djibouti',
  'Dominica',
  'Dominican Republic',
  'DR Congo',
  'Ecuador',
  'Egypt',
  'El Salvador',
  'Equatorial Guinea',
  'Eritrea',
  'Estonia',
  'Eswatini',
  'Ethiopia',
  'Fiji',
  'Finland',
  'France',
  'Gabon',
  'Gambia',
  'Georgia',
  'Germany',
  'Ghana',
  'Greece',
  'Grenada',
  'Guatemala',
  'Guinea',
  'Guinea-Bissau',
  'Guyana',
  'Haiti',
  'Honduras',
  'Hungary',
  'Iceland',
  'India',
  'Indonesia',
  'Iran',
  'Iraq',
  'Ireland',
  'Israel',
  'Italy',
  'Ivory Coast',
  'Jamaica',
  'Japan',
  'Jordan',
  'Kazakhstan',
  'Kenya',
  'Kiribati',
  'Kuwait',
  'Kyrgyzstan',
  'Laos',
  'Latvia',
  'Lebanon',
  'Lesotho',
  'Liberia',
  'Libya',
  'Liechtenstein',
  'Lithuania',
  'Luxembourg',
  'Madagascar',
  'Malawi',
  'Malaysia',
  'Maldives',
  'Mali',
  'Malta',
  'Marshall Islands',
  'Mauritania',
  'Mauritius',
  'Mexico',
  'Micronesia',
  'Moldova',
  'Monaco',
  'Mongolia',
  'Montenegro',
  'Morocco',
  'Mozambique',
  'Myanmar',
  'Namibia',
  'Nauru',
  'Nepal',
  'Netherlands',
  'New Zealand',
  'Nicaragua',
  'Niger',
  'Nigeria',
  'North Korea',
  'North Macedonia',
  'Norway',
  'Oman',
  'Pakistan',
  'Palau',
  'Palestine',
  'Panama',
  'Papua New Guinea',
  'Paraguay',
  'Peru',
  'Philippines',
  'Poland',
  'Portugal',
  'Qatar',
  'Romania',
  'Russia',
  'Rwanda',
  'Saint Kitts and Nevis',
  'Saint Lucia',
  'Saint Vincent and the Grenadines',
  'Samoa',
  'San Marino',
  'Sao Tome and Principe',
  'Saudi Arabia',
  'Senegal',
  'Serbia',
  'Seychelles',
  'Sierra Leone',
  'Singapore',
  'Slovakia',
  'Slovenia',
  'Solomon Islands',
  'Somalia',
  'South Africa',
  'South Korea',
  'South Sudan',
  'Spain',
  'Sri Lanka',
  'Sudan',
  'Suriname',
  'Sweden',
  'Switzerland',
  'Syria',
  'Taiwan',
  'Tajikistan',
  'Tanzania',
  'Thailand',
  'Timor-Leste',
  'Togo',
  'Tonga',
  'Trinidad and Tobago',
  'Tunisia',
  'Turkey',
  'Turkmenistan',
  'Tuvalu',
  'Uganda',
  'Ukraine',
  'United Arab Emirates',
  'United Kingdom',
  'United States',
  'Uruguay',
  'Uzbekistan',
  'Vanuatu',
  'Vatican City',
  'Venezuela',
  'Vietnam',
  'Yemen',
  'Zambia',
  'Zimbabwe',
];

const List<String> _iraqiCities = [
  'Baghdad',
  'Basra',
  'Mosul',
  'Erbil',
  'Sulaymaniyah',
  'Duhok',
  'Kirkuk',
  'Najaf',
  'Karbala',
  'Hilla',
  'Nasiriyah',
  'Amarah',
  'Kut',
  'Diwaniyah',
  'Baqubah',
  'Ramadi',
  'Fallujah',
  'Samarra',
  'Tikrit',
  'Kufa',
  'Zakho',
  'Halabja',
  'Sinjar',
  'Tal Afar',
  'Khanaqin',
  'Mandali',
  'Kalar',
  'Chamchamal',
  'Akre',
  'Shaqlawa',
  'Soran',
  'Ranya',
  'Rawanduz',
  'Makhmur',
  'Qaladiza',
  'Penjwen',
  'Amedi',
  'Fao',
  'Zubair',
  'Abu al-Khasib',
  'Qurna',
  'Shatra',
  'Suq al-Shuyukh',
  'Rifai',
  'Qalat Sukkar',
  'Maysan',
  'Ali al-Gharbi',
  'Numaniyah',
  'Aziziyah',
  'Badra',
  "Mada'in",
  'Taji',
  'Mahmudiyah',
  'Haswa',
  'Musayyib',
  'Iskandariyah',
  'Kifri',
  'Khalis',
  'Muqdadiyah',
  'Jalawla',
  'Rutba',
  'Hit',
  'Haditha',
  'Anah',
  'Rawa',
  'Balad',
  'Dujail',
  'Bayji',
  'Sharqat',
];

class EditProfileScreen extends StatefulWidget {
  final User user;

  const EditProfileScreen({super.key, required this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _countryController;
  late TextEditingController _cityController;
  String _gender = "Male";
  String? _selectedCountry;
  final Set<String> _selectedCities = <String>{};
  File? _newProfileImage;
  File? _newCoverImage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _bioController = TextEditingController(text: widget.user.bio ?? "");
    _countryController = TextEditingController(text: widget.user.country ?? "");
    _cityController = TextEditingController(text: widget.user.city ?? "");
    _gender = widget.user.gender ?? "Male";
    _selectedCountry = _normalizeInitialCountry(widget.user.country);
    _selectedCities.addAll(_normalizeInitialCities(widget.user.city));
    _countryController.text = _selectedCountry ?? '';
    _syncSelectedCitiesText();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _countryController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    final file = await context.read<MediaService>().pickImage();
    if (file != null) {
      setState(() => _newProfileImage = file);
    }
  }

  Future<void> _pickCoverImage() async {
    final file = await context.read<MediaService>().pickImage();
    if (file != null) {
      setState(() => _newCoverImage = file);
    }
  }

  Future<void> _saveProfile() async {
    debugPrint("EditProfileScreen: Save pressed!");
    setState(() => _isSaving = true);

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final mediaService = context.read<MediaService>();
    final authService = context.read<AuthService>();

    String? avatarUrl = widget.user.avatarUrl;
    String? coverUrl = widget.user.coverImageUrl;

    try {
      if (_newProfileImage != null) {
        final uploadedUrl = await mediaService.uploadFile(_newProfileImage!);
        if (uploadedUrl == null) {
          throw Exception("Failed to upload profile image");
        }
        avatarUrl = uploadedUrl;
      }

      if (_newCoverImage != null) {
        final uploadedUrl = await mediaService.uploadFile(_newCoverImage!);
        if (uploadedUrl == null) {
          throw Exception("Failed to upload cover image");
        }
        coverUrl = uploadedUrl;
      }

      final success = await authService.updateProfile(
        name: _nameController.text.trim(),
        bio: _bioController.text.trim(),
        gender: _gender,
        avatarUrl: avatarUrl,
        coverImageUrl: coverUrl,
        country: _selectedCountry?.trim() ?? '',
        city: _isIraqSelected ? _cityController.text.trim() : '',
      );

      if (success && mounted) {
        navigator.pop();
        messenger.showSnackBar(
          const SnackBar(content: Text("تم تحديث الملف الشخصي بنجاح!")),
        );
      } else if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(authService.error ?? "Update failed")),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text("$e")));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AuthService>();

    return Scaffold(
      backgroundColor: const Color(0xFF161921),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161921),
        foregroundColor: Colors.white,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Color(0xFF161921),
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text("تعديل الملف الشخصي",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text("حفظ",
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          children: [
            _buildMediaSection(),
            const SizedBox(height: 16),
            _buildSectionCard(
              children: [
                _buildTextFieldTile(
                  label: "الاسم",
                  controller: _nameController,
                  icon: Icons.person_outline_rounded,
                  textInputAction: TextInputAction.next,
                ),
                _buildCountryTile(),
                if (_isIraqSelected) _buildIraqiCitiesTile(),
                if (!_isIraqSelected) _buildCityInfoTile(),
                _buildGenderTile(),
                _buildTextFieldTile(
                  label: "نبذة / توقيع",
                  controller: _bioController,
                  icon: Icons.edit_note_rounded,
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final authService = context.read<AuthService>();
                  final navigator = Navigator.of(context);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('تسجيل الخروج'),
                      content: const Text('هل أنت متأكد أنك تريد تسجيل الخروج؟'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('إلغاء'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text(
                            'خروج',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    await authService.logout();
                    if (!mounted) return;
                    navigator.popUntil((route) => route.isFirst);
                  }
                },
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text(
                  'تسجيل الخروج',
                  style: TextStyle(color: Colors.red),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaSection() {
    return _buildSectionCard(
      children: [
        _buildImageTile(
          title: "صورة الغلاف",
          subtitle: "اضغط لتغيير الغلاف",
          onTap: _pickCoverImage,
          preview: _buildCoverPreview(),
        ),
        _buildImageTile(
          title: "صورة الملف الشخصي",
          subtitle: "اضغط لتغيير الصورة",
          onTap: _pickProfileImage,
          preview: _buildAvatarPreview(),
        ),
      ],
    );
  }

  Widget _buildSectionCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1F2A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildImageTile({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Widget preview,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              preview,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoverPreview() {
    final imageProvider = _newCoverImage != null
        ? FileImage(_newCoverImage!)
        : _buildNetworkImage(widget.user.coverImageUrl);

    return Container(
      width: 108,
      height: 68,
      decoration: BoxDecoration(
        color: const Color(0xFF2A3040),
        borderRadius: BorderRadius.circular(14),
        image: imageProvider != null
            ? DecorationImage(image: imageProvider, fit: BoxFit.cover)
            : null,
      ),
      child: imageProvider == null
          ? const Icon(Icons.image_outlined, color: Colors.white54)
          : Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Colors.black.withValues(alpha: 0.12),
              ),
              child: const Icon(Icons.camera_alt_outlined, color: Colors.white70),
            ),
    );
  }

  Widget _buildAvatarPreview() {
    final imageProvider = _newProfileImage != null
        ? FileImage(_newProfileImage!)
        : _buildNetworkImage(widget.user.avatarUrl);

    return Stack(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF2A3040),
            image: imageProvider != null
                ? DecorationImage(image: imageProvider, fit: BoxFit.cover)
                : null,
          ),
          child: imageProvider == null
              ? const Icon(Icons.person_outline, color: Colors.white54)
              : null,
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Color(0xFF11131C),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.camera_alt_outlined,
              color: Colors.white,
              size: 12,
            ),
          ),
        ),
      ],
    );
  }

  ImageProvider? _buildNetworkImage(String? rawUrl) {
    final url = rawUrl?.trim() ?? '';
    if (url.isEmpty) return null;
    final normalized =
        url.startsWith('/') ? "https://sawrly.com$url" : url;
    return NetworkImage(normalized);
  }

  bool get _isIraqSelected => _isIraqValue(_selectedCountry);

  bool _isIraqValue(String? value) {
    final normalized = value?.trim().toLowerCase() ?? '';
    return normalized == 'iraq' ||
        normalized == 'republic of iraq' ||
        normalized == 'العراق' ||
        normalized == 'جمهورية العراق';
  }

  String? _normalizeInitialCountry(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    if (_isIraqValue(trimmed)) return 'Iraq';
    final exactMatch = _allCountries.where((country) => country == trimmed);
    if (exactMatch.isNotEmpty) return exactMatch.first;
    final caseInsensitiveMatch = _allCountries.where(
      (country) => country.toLowerCase() == trimmed.toLowerCase(),
    );
    if (caseInsensitiveMatch.isNotEmpty) return caseInsensitiveMatch.first;
    return trimmed;
  }

  List<String> _normalizeInitialCities(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return const [];

    final parts = raw
        .split(RegExp(r',|،'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();

    final normalized = <String>[];
    for (final part in parts) {
      final exactMatch = _iraqiCities.where((city) => city == part);
      if (exactMatch.isNotEmpty) {
        normalized.add(exactMatch.first);
        continue;
      }

      final caseInsensitiveMatch = _iraqiCities.where(
        (city) => city.toLowerCase() == part.toLowerCase(),
      );
      if (caseInsensitiveMatch.isNotEmpty) {
        normalized.add(caseInsensitiveMatch.first);
        continue;
      }

      normalized.add(part);
    }
    return normalized;
  }

  List<String> get _countryOptionsForUi {
    final countries = [..._allCountries];
    final selectedCountry = _selectedCountry?.trim() ?? '';
    if (selectedCountry.isNotEmpty && !countries.contains(selectedCountry)) {
      countries.add(selectedCountry);
    }
    return countries;
  }

  List<String> get _iraqiCitiesForUi {
    final cities = [..._iraqiCities];
    for (final selectedCity in _selectedCities) {
      if (!cities.contains(selectedCity)) {
        cities.add(selectedCity);
      }
    }
    return cities;
  }

  void _syncSelectedCitiesText() {
    _cityController.text = _selectedCities.join(', ');
  }

  Widget _buildCountryTile() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.public_rounded,
              color: Colors.white70,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton(
                  onPressed: _showCountryPicker,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    (_selectedCountry?.isNotEmpty ?? false)
                        ? _selectedCountry!
                        : "اختر الدولة",
                    style: const TextStyle(color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            const SizedBox(
              width: 78,
              child: Text(
                "الدولة",
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIraqiCitiesTile() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(
                  Icons.location_city_outlined,
                  color: Colors.white70,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton(
                      onPressed: _showIraqiCitiesPicker,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _selectedCities.isEmpty
                            ? "اختر المدن"
                            : "تم اختيار ${_selectedCities.length} مدينة",
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const SizedBox(
                  width: 78,
                  child: Text(
                    "المدن",
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (_selectedCities.isNotEmpty) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: _selectedCities
                      .map(
                        (city) => InputChip(
                          label: Text(city),
                          onDeleted: () {
                            setState(() {
                              _selectedCities.remove(city);
                              _syncSelectedCitiesText();
                            });
                          },
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showIraqiCitiesPicker() async {
    final tempSelectedCities = {..._selectedCities};
    final searchController = TextEditingController();
    String searchQuery = '';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1B1F2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.72,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            child: const Text("إلغاء"),
                          ),
                          const Spacer(),
                          const Text(
                            "اختر المدن",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedCities
                                  ..clear()
                                  ..addAll(tempSelectedCities);
                                _syncSelectedCitiesText();
                              });
                              Navigator.pop(sheetContext);
                            },
                            child: const Text("تم"),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: TextField(
                        controller: searchController,
                        onChanged: (value) {
                          setSheetState(() {
                            searchQuery = value.trim().toLowerCase();
                          });
                        },
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "ابحث عن مدينة",
                          hintStyle: const TextStyle(color: Colors.white38),
                          prefixIcon:
                              const Icon(Icons.search, color: Colors.white54),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.06),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.builder(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        itemCount: _iraqiCitiesForUi
                            .where(
                              (city) => city.toLowerCase().contains(searchQuery),
                            )
                            .length,
                        itemBuilder: (context, index) {
                          final filteredCities = _iraqiCitiesForUi
                              .where(
                                (city) =>
                                    city.toLowerCase().contains(searchQuery),
                              )
                              .toList();
                          final city = filteredCities[index];
                          final isSelected = tempSelectedCities.contains(city);
                          return CheckboxListTile(
                            value: isSelected,
                            activeColor: const Color(0xFF8E6BFF),
                            checkColor: Colors.white,
                            title: Text(
                              city,
                              textAlign: TextAlign.right,
                              style: const TextStyle(color: Colors.white),
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: (checked) {
                              setSheetState(() {
                                if (checked == true) {
                                  tempSelectedCities.add(city);
                                } else {
                                  tempSelectedCities.remove(city);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    searchController.dispose();
  }

  Future<void> _showCountryPicker() async {
    final searchController = TextEditingController();
    String searchQuery = '';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1B1F2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.78,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            child: const Text("إلغاء"),
                          ),
                          const Spacer(),
                          const Text(
                            "اختر الدولة",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: TextField(
                        controller: searchController,
                        onChanged: (value) {
                          setSheetState(() {
                            searchQuery = value.trim().toLowerCase();
                          });
                        },
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "ابحث عن دولة",
                          hintStyle: const TextStyle(color: Colors.white38),
                          prefixIcon:
                              const Icon(Icons.search, color: Colors.white54),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.06),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.builder(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        itemCount: _countryOptionsForUi
                            .where(
                              (country) =>
                                  country.toLowerCase().contains(searchQuery),
                            )
                            .length,
                        itemBuilder: (context, index) {
                          final filteredCountries = _countryOptionsForUi
                              .where(
                                (country) => country
                                    .toLowerCase()
                                    .contains(searchQuery),
                              )
                              .toList();
                          final country = filteredCountries[index];
                          final isSelected = country == _selectedCountry;
                          return ListTile(
                            title: Text(
                              country,
                              style: const TextStyle(color: Colors.white),
                            ),
                            trailing: isSelected
                                ? const Icon(
                                    Icons.check_rounded,
                                    color: Color(0xFF8E6BFF),
                                  )
                                : null,
                            onTap: () {
                              setState(() {
                                _selectedCountry = country;
                                _countryController.text = country;
                                if (!_isIraqValue(country)) {
                                  _selectedCities.clear();
                                  _cityController.clear();
                                }
                              });
                              Navigator.pop(sheetContext);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    searchController.dispose();
  }

  Widget _buildCityInfoTile() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: Colors.white54,
              size: 18,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                "قائمة المدن متاحة الآن فقط عند اختيار العراق",
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            SizedBox(width: 12),
            SizedBox(
              width: 78,
              child: Text(
                "المدن",
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextFieldTile({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    int maxLines = 1,
    TextInputAction? textInputAction,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment:
              maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white70, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                maxLines: maxLines,
                minLines: maxLines > 1 ? maxLines : 1,
                textAlign: TextAlign.right,
                textInputAction: textInputAction,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: label,
                  hintStyle: const TextStyle(color: Colors.white38),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 78,
              child: Text(
                label,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderTile() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.wc_rounded, color: Colors.white70, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _gender,
                    dropdownColor: const Color(0xFF232938),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    items: const [
                      DropdownMenuItem(value: "Male", child: Text("ذكر")),
                      DropdownMenuItem(value: "Female", child: Text("أنثى")),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _gender = val);
                      }
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            const SizedBox(
              width: 78,
              child: Text(
                "الجنس",
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
