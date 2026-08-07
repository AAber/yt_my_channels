import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math';
import '../l10n/app_localizations.dart';
import '../l10n/language_provider.dart';
import '../models/series.dart';
import '../services/api_service.dart';
import '../services/youtube_service.dart';
import '../services/watch_history_service.dart';
import '../widgets/history_drawer.dart';
import 'home_screen.dart';
import 'lessons_screen.dart';
import 'youtube_home_screen.dart';
import 'youtube_player_screen.dart';
import 'torah_chat_screen.dart';

class SourceSelectionScreen extends StatefulWidget {
  const SourceSelectionScreen({super.key});

  @override
  State<SourceSelectionScreen> createState() => _SourceSelectionScreenState();
}

class _SourceSelectionScreenState extends State<SourceSelectionScreen> {
  String _version = '';
  final TextEditingController _searchController = TextEditingController();
  final ApiService _apiService = ApiService();
  final YouTubeService _youtubeService = YouTubeService();
  final WatchHistoryService _historyService = WatchHistoryService();
  final HistoryDrawerController _drawerController = HistoryDrawerController();

  bool _isSearching = false;
  bool _searchLoading = false;
  List<_SearchResult> _searchResults = [];
  List<_SourceButtonData> _sourceButtons = [];

  @override
  void initState() {
    super.initState();
    _historyService.init();
    PackageInfo.fromPlatform().then((info) {
      setState(() => _version = info.version);
    });
    _searchController.addListener(_onSearchChanged);
    _initializeSourceButtons();
  }

  void _initializeSourceButtons() {
    _sourceButtons = [
      _SourceButtonData(
        title: 'בני דוד',
        subtitle: 'Bnei David',
        iconPath: 'assets/icon/david.png',
        onTap: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const HomeScreen(),
            ),
          );
        },
      ),
      _SourceButtonData(
        title: 'Sia',
        subtitle: 'sia',
        iconPath: 'assets/icon/sia.png',
        onTap: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const YouTubeHomeScreen(
                channelId: 'UCN9HPn2fq-NL8M5_kp4RWZQ',
                title: 'Sia',
              ),
            ),
          );
        },
      ),
      _SourceButtonData(
        title: 'Taylor Swift',
        subtitle: 'taylorswift',
        iconPath: 'assets/icon/taylor.png',
        onTap: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const YouTubeHomeScreen(
                channelId: 'UCqECaJ8Gagnn7YCbPEzWH6g',
                title: 'Taylor Swift',
              ),
            ),
          );
        },
      ),
      _SourceButtonData(
        title: 'Ed Sheeran',
        subtitle: 'edsheeran',
        iconPath: 'assets/icon/ed.png',
        onTap: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const YouTubeHomeScreen(
                channelId: 'UC0C-w0YjGpqDXGB8IHb662A',
                title: 'Ed Sheeran',
              ),
            ),
          );
        },
      ),
      _SourceButtonData(
        title: 'Ariana Grande',
        subtitle: 'arianagrande',
        iconPath: 'assets/icon/ariana.png',
        onTap: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const YouTubeHomeScreen(
                channelId: 'UC9CoOnJkIBMdeijd9qYoT_g',
                title: 'Ariana Grande',
              ),
            ),
          );
        },
      ),
      _SourceButtonData(
        title: 'Beyoncé',
        subtitle: 'beyonce',
        iconPath: 'assets/icon/beyonce.png',
        onTap: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const YouTubeHomeScreen(
                channelId: 'UCuHzBCaKmtaLcRAOoazhCPA',
                title: 'Beyoncé',
              ),
            ),
          );
        },
      ),
      _SourceButtonData(
        title: 'Drake',
        subtitle: 'drake',
        iconPath: 'assets/icon/drake.png',
        onTap: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const YouTubeHomeScreen(
                channelId: 'UCNTQH0uJzryQB4rRLGlv-Ww',
                title: 'Drake',
              ),
            ),
          );
        },
      ),
      _SourceButtonData(
        title: 'Billie Eilish',
        subtitle: 'billieeilish',
        iconPath: 'assets/icon/billie.png',
        onTap: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const YouTubeHomeScreen(
                channelId: 'UCiGm_E4ZwYSHV3bcW1pnSeQ',
                title: 'Billie Eilish',
              ),
            ),
          );
        },
      ),
    ];

    // Shuffle the buttons randomly (keep בני דוד first)
    final bneiDavid = _sourceButtons.removeAt(0);
    _sourceButtons.shuffle(Random());
    _sourceButtons.insert(0, bneiDavid);
  }

  static const _youtubeChannels = [
    {'id': 'UCN9HPn2fq-NL8M5_kp4RWZQ', 'title': 'Sia',           'icon': 'assets/icon/sia.png'},
    {'id': 'UCqECaJ8Gagnn7YCbPEzWH6g', 'title': 'Taylor Swift',  'icon': 'assets/icon/taylor.png'},
    {'id': 'UC0C-w0YjGpqDXGB8IHb662A', 'title': 'Ed Sheeran',    'icon': 'assets/icon/ed.png'},
    {'id': 'UC9CoOnJkIBMdeijd9qYoT_g', 'title': 'Ariana Grande', 'icon': 'assets/icon/ariana.png'},
    {'id': 'UCuHzBCaKmtaLcRAOoazhCPA', 'title': 'Beyoncé',       'icon': 'assets/icon/beyonce.png'},
    {'id': 'UCNTQH0uJzryQB4rRLGlv-Ww', 'title': 'Drake',         'icon': 'assets/icon/drake.png'},
    {'id': 'UCiGm_E4ZwYSHV3bcW1pnSeQ', 'title': 'Billie Eilish', 'icon': 'assets/icon/billie.png'},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    setState(() => _isSearching = query.isNotEmpty);
    if (query.length >= 2) {
      _runSearch(query);
    } else if (query.isEmpty) {
      setState(() => _searchResults = []);
    }
  }

  Future<void> _runSearch(String query) async {
    setState(() => _searchLoading = true);
    final results = <_SearchResult>[];
    final q = query.toLowerCase();

    // Search Bnei David series
    try {
      final allSeries = await _apiService.getSeries();
      for (final s in allSeries) {
        if (s.name.toLowerCase().contains(q)) {
          results.add(_SearchResult.series(s));
        }
      }
    } catch (_) {}

    // Search YouTube channels
    for (final ch in _youtubeChannels) {
      try {
        final videos =
            await _youtubeService.getChannelVideos(channelId: ch['id']);
        for (final v in videos) {
          if (v.title.toLowerCase().contains(q) ||
              v.description.toLowerCase().contains(q)) {
            results.add(_SearchResult.video(v, ch['title']!, ch['icon']!));
          }
        }
      } catch (_) {}
    }

    if (mounted && _searchController.text.trim().toLowerCase() == q) {
      setState(() {
        _searchResults = results;
        _searchLoading = false;
      });
    }
  }

  Future<void> _sendFeedback() async {
    final subject =
        Uri.encodeComponent('משוב לאפליקציה תורת א"י גרסה $_version');
    final uri = Uri.parse('mailto:banzashi@gmail.com?subject=$subject');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        final l10n = AppLocalizations.of(context);
        
        final isHebrew = languageProvider.locale.languageCode == 'he';
        return HistoryDrawerScaffold(
          historyService: _historyService,
          controller: _drawerController,
          appBar: AppBar(
            title: Text(l10n.translate('select_source')),
            centerTitle: true,
            automaticallyImplyLeading: false,
            leading: isHebrew
                ? IconButton(
                    icon: const Icon(Icons.history),
                    onPressed: _drawerController.open,
                  )
                : null,
            actions: [
              if (!isHebrew)
                IconButton(
                  icon: const Icon(Icons.history),
                  onPressed: _drawerController.open,
                ),
              IconButton(
                icon: const Icon(Icons.email_outlined),
                onPressed: _sendFeedback,
              ),
              IconButton(
                icon: const Icon(Icons.language),
                onPressed: () => languageProvider.toggleLanguage(),
              ),
            ],
          ),
          body: Column(
            children: [
              // Search box
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: l10n.translate('search_all_sources'),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _isSearching
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _isSearching = false;
                                _searchResults = [];
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              // Search results or source grid
              Expanded(
                child: _isSearching
                    ? _buildSearchResults(l10n)
                    : _buildSourceGrid(context),
              ),
            ],
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.startDocked,
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TorahChatScreen(),
                ),
              );
            },
            backgroundColor: Colors.orange,
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.white,
            ),
          ),
          bottomNavigationBar: _isSearching ? null : _buildBottomAppBar(),
        );
      },
    );
  }

  WatchHistoryService get historyService => _historyService;

  Widget _buildSearchResults(AppLocalizations l10n) {
    if (_searchLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_searchController.text.trim().length < 2) {
      return Center(
        child: Text(
          l10n.translate('type_to_search'),
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }
    if (_searchResults.isEmpty) {
      return Center(
        child: Text(
          l10n.translate('no_results'),
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(
            '${_searchResults.length} ${l10n.translate("results")}',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _searchResults.length,
            itemBuilder: (context, index) =>
                _buildResultTile(_searchResults[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildResultTile(_SearchResult result) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: Image.asset(
          result.iconPath,
          width: 36,
          height: 36,
          errorBuilder: (_, __, ___) => const Icon(Icons.play_circle_outline),
        ),
        title: Text(result.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(result.sourceName, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => _openResult(result),
      ),
    );
  }

  void _openResult(_SearchResult result) {
    if (result.series != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => LessonsScreen(series: result.series!)),
      );
    } else if (result.video != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => YouTubePlayerScreen(
                  video: result.video!,
                  channelTitle: result.sourceName,
                )),
      );
    }
  }

  Widget _buildSourceGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const columns = 2;
        const rows = 4;
        const hPad = 16.0;
        const spacing = 12.0;
        final tileWidth = (constraints.maxWidth - hPad * 2 - spacing) / columns;
        final tileHeight = (constraints.maxHeight - spacing * (rows - 1)) / rows;
        final aspectRatio = tileWidth / tileHeight;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: hPad, vertical: 8),
          child: GridView.count(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            crossAxisCount: columns,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: aspectRatio,
            children: _sourceButtons.map((buttonData) {
              return _buildSourceButton(
                context,
                title: buttonData.title,
                subtitle: buttonData.subtitle,
                iconPath: buttonData.iconPath,
                onTap: buttonData.onTap,
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildBottomAppBar() {
    final l10n = AppLocalizations.of(context);
    return BottomAppBar(
      color: Theme.of(context).primaryColor,
      height: 90,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.translate('more_apps_from_developer'),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildAppButton(
                'מכון מאיר לנייד',
                'mobile.meritv.com',
                'https://apps.apple.com/us/app/machon-meir-%D7%9E%D7%9B%D7%95%D7%9F-%D7%9E%D7%90%D7%99%D7%A8-%D7%9C%D7%A0%D7%99%D7%99%D7%93/id6447646214',
                'assets/icon/meir.png',
              ),
              _buildAppButton(
                'תהילים לחסידים',
                'live.isaac770.tfc',
                'https://apps.apple.com/us/app/tehilim-for-%D7%AA%D7%94%D7%99%D7%9C%D7%99%D7%9D-%D7%9C%D7%97%D7%A1%D7%99%D7%93%D7%99%D7%9D/id6503480097',
                'assets/icon/tfc.png',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppButton(String name, String androidPackageName,
      String iosAppStoreUrl, String iconPath) {
    return InkWell(
      onTap: () => _launchApp(androidPackageName, iosAppStoreUrl),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white54, width: 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              iconPath,
              width: 18,
              height: 18,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.apps, size: 18, color: Colors.white);
              },
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                name,
                style: const TextStyle(fontSize: 13, color: Colors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchApp(
      String androidPackageName, String iosAppStoreUrl) async {
    try {
      Uri url;

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        // iOS - open App Store
        url = Uri.parse(iosAppStoreUrl);
      } else {
        // Android - open Play Store
        url = Uri.parse(
            'https://play.google.com/store/apps/details?id=$androidPackageName');
      }

      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      // Silently handle launch errors
    }
  }

  Widget _buildSourceButton(
    BuildContext context, {
    required String title,
    required String subtitle,
    String? iconPath,
    IconData? icon,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: ColoredBox(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: iconPath != null
                        ? FractionallySizedBox(
                            widthFactor: 1.0,
                            heightFactor: 1.0,
                            child: Image.asset(
                              iconPath,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Center(
                                  child: Icon(
                                    Icons.school,
                                    color: Theme.of(context).primaryColor,
                                    size: 32,
                                  ),
                                );
                              },
                            ),
                          )
                        : Center(
                            child: Icon(
                              icon ?? Icons.add_circle_outline,
                              color: Colors.grey,
                              size: 32,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchResult {
  final String title;
  final String sourceName;
  final String iconPath;
  final Series? series;
  final YouTubeVideo? video;

  _SearchResult.series(Series s)
      : title = s.name,
        sourceName = 'בני דוד',
        iconPath = 'assets/icon/david.png',
        series = s,
        video = null;

  _SearchResult.video(YouTubeVideo v, String source, String icon)
      : title = v.title,
        sourceName = source,
        iconPath = icon,
        series = null,
        video = v;
}

class _SourceButtonData {
  final String title;
  final String subtitle;
  final String iconPath;
  final VoidCallback onTap;

  _SourceButtonData({
    required this.title,
    required this.subtitle,
    required this.iconPath,
    required this.onTap,
  });
}
