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
        title: 'עוד יוסף חי',
        subtitle: 'Od Yosef Hai',
        iconPath: 'assets/icon/yosef.png',
        onTap: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const YouTubeHomeScreen(
                channelId: 'UCQfTTiNEkZ3_HYr9S4zQB0g',
                title: 'עוד יוסף חי',
              ),
            ),
          );
        },
      ),
      _SourceButtonData(
        title: 'חב"ד רמת אביב',
        subtitle: 'Chabad Ramat Aviv',
        iconPath: 'assets/icon/aviv.png',
        onTap: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const YouTubeHomeScreen(
                channelId: 'UCJYMW0GZaanXsFnt5pnI6QA',
                title: 'חב"ד רמת אביב',
              ),
            ),
          );
        },
      ),
      _SourceButtonData(
        title: 'הסדר מעלות',
        subtitle: 'הסדר מעלות',
        iconPath: 'assets/icon/maalot.png',
        onTap: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const YouTubeHomeScreen(
                channelId: 'UCXGUXEMhk3PaZxep7NVTM5A',
                title: 'ישיבת הסדר מעלות',
              ),
            ),
          );
        },
      ),
      _SourceButtonData(
        titleKey: 'mayonai_israel_title',
        subtitleKey: 'mayonai_israel_subtitle',
        iconPath: 'assets/icon/mi.png',
        onTap: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const YouTubeHomeScreen(
                channelId: 'UCdoHZjm2ku452xK4f5gRzZw',
                title: 'מעייני ישראל',
              ),
            ),
          );
        },
      ),
      _SourceButtonData(
        titleKey: 'holon_yeshiva_title',
        subtitleKey: 'holon_yeshiva_subtitle',
        iconPath: 'assets/icon/holon.png',
        onTap: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const YouTubeHomeScreen(
                channelId: 'UCWdBoc1ZurwXJMOSq0eLx-A',
                title: 'ישיבת חולון',
              ),
            ),
          );
        },
      ),
      _SourceButtonData(
        title: 'ממעל ממש',
        subtitle: 'Mimaal Mamash',
        iconPath: 'assets/icon/mimaal.png',
        iconScale: 0.85,
        onTap: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const YouTubeHomeScreen(
                channelId: 'UCkrqrlLmV0OBP9a3jMWTAcw',
                title: 'ממעל ממש',
              ),
            ),
          );
        },
      ),
      _SourceButtonData(
        title: 'ישיבת שדרות',
        subtitle: 'Yeshivat Shderot',
        iconPath: 'assets/icon/shderot.png',
        iconScale: 0.85,
        onTap: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const YouTubeHomeScreen(
                channelId: 'UC4jSWBYE-jIllmJmsZC5xRQ',
                title: 'ישיבת שדרות',
              ),
            ),
          );
        },
      ),
    ];

    // Shuffle the buttons randomly
    _sourceButtons.shuffle(Random());
  }

  static const _youtubeChannels = [
    {
      'id': 'UCQfTTiNEkZ3_HYr9S4zQB0g',
      'title': 'עוד יוסף חי',
      'icon': 'assets/icon/yosef.png'
    },
    {
      'id': 'UCJYMW0GZaanXsFnt5pnI6QA',
      'title': 'חב"ד רמת אביב',
      'icon': 'assets/icon/aviv.png'
    },
    {
      'id': 'UCXGUXEMhk3PaZxep7NVTM5A',
      'title': 'ישיבת הסדר מעלות',
      'icon': 'assets/icon/maalot.png'
    },
    {
      'id': 'UCdoHZjm2ku452xK4f5gRzZw',
      'title': 'מעייני ישראל',
      'icon': 'assets/icon/mi.png'
    },
    {
      'id': 'UCWdBoc1ZurwXJMOSq0eLx-A',
      'title': 'ישיבת חולון',
      'icon': 'assets/icon/holon.png'
    },
    {
      'id': 'UCkrqrlLmV0OBP9a3jMWTAcw',
      'title': 'ממעל ממש',
      'icon': 'assets/icon/mimaal.png'
    },
    {
      'id': 'UC4jSWBYE-jIllmJmsZC5xRQ',
      'title': 'ישיבת שדרות',
      'icon': 'assets/icon/shderot.png'
    },
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
    final l10n = AppLocalizations.of(context);
    final isHebrew = l10n.locale.languageCode == 'he';

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
              final title = buttonData.title ?? _getLocalizedText(l10n, buttonData.titleKey!, isHebrew);
              final subtitle = buttonData.subtitle ?? _getLocalizedText(l10n, buttonData.subtitleKey!, isHebrew);
              return _buildSourceButton(
                context,
                title: title,
                subtitle: subtitle,
                iconPath: buttonData.iconPath,
                iconScale: buttonData.iconScale,
                onTap: buttonData.onTap,
              );
            }).toList(),
          ),
        );
      },
    );
  }

  String _getLocalizedText(AppLocalizations l10n, String key, bool isHebrew) {
    switch (key) {
      case 'mayonai_israel_title':
        return isHebrew ? 'מעייני ישראל' : 'Mayonaiy Israel';
      case 'mayonai_israel_subtitle':
        return isHebrew ? 'Mayonaiy Israel' : 'מעייני ישראל';
      case 'holon_yeshiva_title':
        return isHebrew ? 'ישיבת חולון' : 'Holon Yeshiva';
      case 'holon_yeshiva_subtitle':
        return isHebrew ? 'Holon Yeshiva' : 'ישיבת חולון';
      default:
        return key;
    }
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
    double iconScale = 1.0,
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
                            widthFactor: iconScale,
                            heightFactor: iconScale,
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
  final String? title;
  final String? subtitle;
  final String? titleKey;
  final String? subtitleKey;
  final String iconPath;
  final double iconScale;
  final VoidCallback onTap;

  _SourceButtonData({
    this.title,
    this.subtitle,
    this.titleKey,
    this.subtitleKey,
    required this.iconPath,
    this.iconScale = 1.0,
    required this.onTap,
  });
}
