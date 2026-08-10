import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';
import '../l10n/language_provider.dart';
import '../services/saved_channels_service.dart';
import '../services/youtube_service.dart';
import '../services/watch_history_service.dart';
import '../widgets/history_drawer.dart';
import 'channel_picker_screen.dart';
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
  final _searchController = TextEditingController();
  final _ytService = YouTubeService();
  final _historyService = WatchHistoryService();
  final _drawerController = HistoryDrawerController();

  bool _isSearching = false;
  bool _searchLoading = false;
  List<_SearchResult> _searchResults = [];

  List<SavedChannel> get _channels => SavedChannelsService.instance.channels;

  @override
  void initState() {
    super.initState();
    _historyService.init();
    PackageInfo.fromPlatform().then((info) => setState(() => _version = info.version));
    _searchController.addListener(_onSearchChanged);
  }

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
    for (final ch in _channels) {
      try {
        final videos = await _ytService.getChannelVideos(channelId: ch.id);
        for (final v in videos) {
          if (v.title.toLowerCase().contains(q) || v.description.toLowerCase().contains(q)) {
            results.add(_SearchResult(video: v, channel: ch));
          }
        }
      } catch (_) {}
    }
    if (mounted && _searchController.text.trim().toLowerCase() == q) {
      setState(() { _searchResults = results; _searchLoading = false; });
    }
  }

  Future<void> _sendFeedback() async {
    final subject = Uri.encodeComponent('Feedback — yt_my_channels v$_version');
    await launchUrl(Uri.parse('mailto:banzashi@gmail.com?subject=$subject'),
        mode: LaunchMode.externalApplication);
  }

  void _openPicker({bool isAddMode = false}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChannelPickerScreen(isAddMode: isAddMode)),
    );
    setState(() {}); // refresh grid after returning
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, _) {
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
                ? IconButton(icon: const Icon(Icons.history), onPressed: _drawerController.open)
                : null,
            actions: [
              if (!isHebrew)
                IconButton(icon: const Icon(Icons.history), onPressed: _drawerController.open),
              IconButton(icon: const Icon(Icons.email_outlined), onPressed: _sendFeedback),
              IconButton(
                icon: const Icon(Icons.language),
                onPressed: () => languageProvider.toggleLanguage(),
              ),
            ],
          ),
          body: Column(
            children: [
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
                              setState(() { _isSearching = false; _searchResults = []; });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              Expanded(
                child: _isSearching
                    ? _buildSearchResults(l10n)
                    : _buildGrid(context),
              ),
            ],
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.startDocked,
          floatingActionButton: FloatingActionButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TorahChatScreen()),
            ),
            backgroundColor: Colors.orange,
            child: const Icon(Icons.auto_awesome, color: Colors.white),
          ),
          bottomNavigationBar: _isSearching ? null : _buildBottomBar(),
        );
      },
    );
  }

  // ── Grid ──────────────────────────────────────────────────────────────────

  Widget _buildGrid(BuildContext context) {
    final items = _channels;
    // +1 for the "Add channel" tile
    final count = items.length + 1;
    final cols = 2;

    return LayoutBuilder(builder: (context, constraints) {
      const hPad = 16.0, spacing = 12.0;
      final rows = ((count / cols).ceil()).clamp(1, 5);
      final tileW = (constraints.maxWidth - hPad * 2 - spacing) / cols;
      final tileH = (constraints.maxHeight - spacing * (rows - 1)) / rows;
      final ratio = tileW / tileH;

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: hPad, vertical: 8),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: ratio,
          ),
          itemCount: count,
          itemBuilder: (context, index) {
            if (index < items.length) {
              return _ChannelButton(
                channel: items[index],
                onTap: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => YouTubeHomeScreen(
                      channelId: items[index].id,
                      title: items[index].title,
                    ),
                  ),
                ),
              );
            }
            // "+" add tile
            return _AddChannelButton(
              onTap: () => _openPicker(isAddMode: true),
              atMax: items.length >= SavedChannelsService.maxChannels,
            );
          },
        ),
      );
    });
  }

  // ── Search results ────────────────────────────────────────────────────────

  Widget _buildSearchResults(AppLocalizations l10n) {
    if (_searchLoading) return const Center(child: CircularProgressIndicator());
    if (_searchController.text.trim().length < 2) {
      return Center(child: Text(l10n.translate('type_to_search'),
          style: const TextStyle(color: Colors.grey)));
    }
    if (_searchResults.isEmpty) {
      return Center(child: Text(l10n.translate('no_results'),
          style: const TextStyle(fontSize: 16, color: Colors.grey)));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text('${_searchResults.length} ${l10n.translate("results")}',
              style: const TextStyle(fontSize: 14, color: Colors.grey)),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _searchResults.length,
            itemBuilder: (context, i) => _buildResultTile(_searchResults[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildResultTile(_SearchResult result) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: result.channel.avatarUrl.isNotEmpty
              ? channelAvatarImage(result.channel.avatarUrl)
              : null,
          child: result.channel.avatarUrl.isEmpty ? const Icon(Icons.person) : null,
        ),
        title: Text(result.video.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(result.channel.title, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => YouTubePlayerScreen(
              video: result.video,
              channelTitle: result.channel.title,
            ),
          ),
        ),
      ),
    );
  }

  // ── Bottom bar ────────────────────────────────────────────────────────────

  Widget _buildBottomBar() {
    final l10n = AppLocalizations.of(context);
    return BottomAppBar(
      color: Theme.of(context).primaryColor,
      height: 90,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.translate('more_apps_from_developer'),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white)),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildAppButton('מכון מאיר לנייד', 'mobile.meritv.com',
                  'https://apps.apple.com/us/app/machon-meir-%D7%9E%D7%9B%D7%95%D7%9F-%D7%9E%D7%90%D7%99%D7%A8-%D7%9C%D7%A0%D7%99%D7%99%D7%93/id6447646214',
                  'assets/icon/meir.png'),
              _buildAppButton('תהילים לחסידים', 'live.isaac770.tfc',
                  'https://apps.apple.com/us/app/tehilim-for-%D7%AA%D7%94%D7%99%D7%9C%D7%99%D7%9D-%D7%9C%D7%97%D7%A1%D7%99%D7%93%D7%99%D7%9D/id6503480097',
                  'assets/icon/tfc.png'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppButton(String name, String androidPkg, String iosUrl, String iconPath) {
    return InkWell(
      onTap: () async {
        final url = defaultTargetPlatform == TargetPlatform.iOS
            ? Uri.parse(iosUrl)
            : Uri.parse('https://play.google.com/store/apps/details?id=$androidPkg');
        await launchUrl(url, mode: LaunchMode.externalApplication);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white54),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(iconPath, width: 18, height: 18,
                errorBuilder: (_, __, ___) => const Icon(Icons.apps, size: 18, color: Colors.white)),
            const SizedBox(width: 6),
            Flexible(child: Text(name,
                style: const TextStyle(fontSize: 13, color: Colors.white),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }
}

// ── Channel grid button ───────────────────────────────────────────────────────

class _ChannelButton extends StatelessWidget {
  final SavedChannel channel;
  final VoidCallback onTap;
  const _ChannelButton({required this.channel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                  child: channel.avatarUrl.isNotEmpty
                      ? Image(
                          image: channelAvatarImage(channel.avatarUrl),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const _FallbackIcon())
                      : const _FallbackIcon(),
                ),
              ),
              const SizedBox(height: 6),
              Text(channel.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

class _FallbackIcon extends StatelessWidget {
  const _FallbackIcon();
  @override
  Widget build(BuildContext context) => Center(
      child: Icon(Icons.subscriptions, color: Theme.of(context).primaryColor, size: 40));
}

ImageProvider channelAvatarImage(String url) {
  if (url.startsWith('asset:')) return AssetImage(url.substring(6));
  return NetworkImage(url);
}

class _AddChannelButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool atMax;
  const _AddChannelButton({required this.onTap, required this.atMax});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: atMax ? Colors.grey[300]! : Theme.of(context).primaryColor,
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: atMax ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(atMax ? Icons.check_circle_outline : Icons.add_circle_outline,
                size: 36,
                color: atMax ? Colors.grey : Theme.of(context).primaryColor),
            const SizedBox(height: 6),
            Text(
              atMax ? 'Max reached' : '+ Add Channel',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: atMax ? Colors.grey : Theme.of(context).primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchResult {
  final YouTubeVideo video;
  final SavedChannel channel;
  const _SearchResult({required this.video, required this.channel});
}
