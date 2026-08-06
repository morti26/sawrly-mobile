import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme_service.dart';
import '../../core/network/api_client.dart';
import '../../models/user.dart';
import '../profile/creator_profile_screen.dart';

class GlobalSearchScreen extends StatefulWidget {
  final String initialQuery;
  final int initialTabIndex;

  const GlobalSearchScreen({
    super.key,
    this.initialQuery = '',
    this.initialTabIndex = 0,
  });

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  List<dynamic> _creators = [];
  List<dynamic> _offers = [];
  bool _isLoadingCreators = false;
  bool _isLoadingOffers = false;

  @override
  void initState() {
    super.initState();
    final initialTabIndex = widget.initialTabIndex.clamp(0, 1);
    _tabController =
        TabController(length: 2, vsync: this, initialIndex: initialTabIndex);
    _query = widget.initialQuery.trim();
    if (_query.isNotEmpty) {
      _searchController.text = _query;
    }
    _search(_query);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    setState(() {
      _isLoadingCreators = true;
      _isLoadingOffers = true;
    });

    final dio = context.read<ApiClient>().client;

    try {
      final creatorsRes =
          await dio.get('/search/creators', queryParameters: {'q': q});
      if (mounted) {
        setState(() {
          _creators = creatorsRes.data is List ? creatorsRes.data : [];
          _isLoadingCreators = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingCreators = false);
    }

    try {
      final offersRes =
          await dio.get('/search/offers', queryParameters: {'q': q});
      if (mounted) {
        setState(() {
          _offers = offersRes.data is List ? offersRes.data : [];
          _isLoadingOffers = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingOffers = false);
    }
  }

  void _onSearchChanged(String value) {
    setState(() => _query = value);
    // Debounce: wait 400ms after user stops typing
    Future.delayed(const Duration(milliseconds: 400), () {
      if (_query == value) {
        _search(value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppThemeService>();
    final colors = theme.colors;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        titleSpacing: 12,
        title: Container(
          height: 42,
          decoration: BoxDecoration(
            color: colors.surfaceLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            autofocus: false,
            decoration: InputDecoration(
              hintText: 'ابحث عن منشئين أو عروض...',
              hintStyle: TextStyle(color: colors.textTertiary, fontSize: 14),
              prefixIcon:
                  Icon(Icons.search, color: colors.textSecondary, size: 20),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, size: 18, color: colors.textSecondary),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      })
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 11),
            ),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: colors.primary,
          unselectedLabelColor: colors.textSecondary,
          indicatorColor: colors.primary,
          tabs: [
            Tab(
                text:
                    'المنشئون${_creators.isEmpty ? '' : ' (${_creators.length})'}'),
            Tab(text: 'العروض${_offers.isEmpty ? '' : ' (${_offers.length})'}'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCreatorsList(colors),
          _buildOffersList(colors),
        ],
      ),
    );
  }

  Widget _buildCreatorsList(RemoteThemeColors colors) {
    if (_isLoadingCreators) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_creators.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search, size: 60, color: colors.textTertiary),
            const SizedBox(height: 12),
            Text('لم يتم العثور على منشئين',
                style: TextStyle(color: colors.textTertiary)),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _creators.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, index) {
        final creator = _creators[index];
        final name = creator['name'] ?? 'Unknown';
        final id = creator['id']?.toString() ?? '';
        final avatarUrl = creator['avatar_url'];
        final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';

        return ListTile(
          leading: CircleAvatar(
            radius: 24,
            backgroundImage:
                (avatarUrl != null && avatarUrl.toString().isNotEmpty)
                    ? NetworkImage(
                        avatarUrl.startsWith('/')
                            ? 'https://sawrly.com$avatarUrl'
                            : avatarUrl,
                      )
                    : null,
            child: avatarUrl == null ? Text(initials) : null,
          ),
          title:
              Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('منشئ محتوى',
              style: TextStyle(color: colors.textSecondary, fontSize: 12)),
          trailing:
              Icon(Icons.arrow_forward_ios, size: 14, color: colors.textSecondary),
          onTap: () {
            final user = User(
              id: id,
              name: name,
              email: '',
              role: UserRole.creator,
              avatarUrl: avatarUrl,
            );
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => CreatorProfileScreen(user: user)),
            );
          },
        );
      },
    );
  }

  Widget _buildOffersList(RemoteThemeColors colors) {
    if (_isLoadingOffers) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_offers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_offer_outlined, size: 60, color: colors.textTertiary),
            const SizedBox(height: 12),
            Text('لم يتم العثور على عروض',
                style: TextStyle(color: colors.textTertiary)),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _offers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final offer = _offers[index];
        final title = offer['title'] ?? 'Untitled';
        final price = offer['price_iqd'];
        final imageUrl = offer['image_url'];
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final thumbCache = (90 * dpr).round();

        String? imgSrc;
        if (imageUrl != null && imageUrl.toString().isNotEmpty) {
          imgSrc = imageUrl.startsWith('/')
              ? 'https://sawrly.com$imageUrl'
              : imageUrl;
        }

        return Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              SizedBox(
                width: 90,
                height: 90,
                child: imgSrc != null
                    ? Image.network(
                        imgSrc,
                        fit: BoxFit.cover,
                        cacheWidth: thumbCache,
                        cacheHeight: thumbCache,
                        errorBuilder: (_, __, ___) => Center(
                          child: Icon(
                            Icons.image_not_supported,
                            color: colors.textSecondary,
                          ),
                        ),
                      )
                    : ColoredBox(
                        color: colors.surfaceLight,
                        child: Center(
                            child: Icon(Icons.local_offer, color: colors.textSecondary)),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      if (price != null)
                        Text(
                          '${price.toString()} IQD',
                          style: TextStyle(
                              color: colors.success, fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child:
                    Icon(Icons.arrow_forward_ios, size: 14, color: colors.textSecondary),
              )
            ],
          ),
        );
      },
    );
  }
}
