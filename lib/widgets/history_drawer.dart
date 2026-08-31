import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/language_provider.dart';
import '../services/watch_history_service.dart';
import '../screens/player_screen.dart';
import '../screens/youtube_player_screen.dart';

// ---------------------------------------------------------------------------
// HistoryDrawerController
// ---------------------------------------------------------------------------

class HistoryDrawerController {
  _HistoryDrawerScaffoldState? _state;
  void open() => _state?._openDrawer();
}

// ---------------------------------------------------------------------------
// HistoryDrawerScaffold
// ---------------------------------------------------------------------------

class HistoryDrawerScaffold extends StatefulWidget {
  final WatchHistoryService historyService;
  final HistoryDrawerController controller;
  final PreferredSizeWidget appBar;
  final Widget body;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  const HistoryDrawerScaffold({
    super.key,
    required this.historyService,
    required this.controller,
    required this.appBar,
    required this.body,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
  });

  @override
  State<HistoryDrawerScaffold> createState() => _HistoryDrawerScaffoldState();
}

class _HistoryDrawerScaffoldState extends State<HistoryDrawerScaffold> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  // Incremented each open so the drawer widget gets a new key and rebuilds fresh.
  int _drawerEpoch = 0;
  // Stable — set once so drawer/endDrawer assignment never flips mid-build.
  late bool _isHebrew;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isHebrew = Provider.of<LanguageProvider>(context, listen: false)
            .locale
            .languageCode ==
        'he';
  }

  @override
  void initState() {
    super.initState();
    widget.controller._state = this;
    WidgetsBinding.instance.addPostFrameCallback((_) => _flashDrawer());
  }

  @override
  void didUpdateWidget(HistoryDrawerScaffold old) {
    super.didUpdateWidget(old);
    widget.controller._state = this;
  }

  @override
  void dispose() {
    widget.controller._state = null;
    super.dispose();
  }

  void _openDrawer() {
    setState(() => _drawerEpoch++);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_isHebrew) {
        _scaffoldKey.currentState?.openDrawer();
      } else {
        _scaffoldKey.currentState?.openEndDrawer();
      }
    });
  }

  Future<void> _flashDrawer() async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    _openDrawer();
    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;
    if (_isHebrew) {
      _scaffoldKey.currentState?.closeDrawer();
    } else {
      _scaffoldKey.currentState?.closeEndDrawer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final drawer = _HistoryDrawer(
      key: ValueKey(_drawerEpoch),
      historyService: widget.historyService,
    );

    return Scaffold(
      key: _scaffoldKey,
      appBar: widget.appBar,
      body: widget.body,
      bottomNavigationBar: widget.bottomNavigationBar,
      floatingActionButton: widget.floatingActionButton,
      floatingActionButtonLocation: widget.floatingActionButtonLocation,
      drawer: _isHebrew ? drawer : null,
      endDrawer: _isHebrew ? null : drawer,
    );
  }
}

// ---------------------------------------------------------------------------
// _HistoryDrawer  — StatelessWidget; gets a new ValueKey on every open
// ---------------------------------------------------------------------------

class _HistoryDrawer extends StatelessWidget {
  final WatchHistoryService historyService;

  const _HistoryDrawer({super.key, required this.historyService});

  @override
  Widget build(BuildContext context) {
    final isHebrew = Provider.of<LanguageProvider>(context, listen: false)
            .locale
            .languageCode ==
        'he';
    final entries = historyService.getHistory();

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: Row(
                children: [
                  const Icon(Icons.history, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    isHebrew ? 'Watch History' : 'Watch History',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  isHebrew ? 'אין שיעורים שנצפו' : 'No lessons watched yet',
                  style: const TextStyle(color: Colors.grey),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: entries.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return _HistoryTile(
                      entry: entry,
                      onTap: () {
                        Navigator.pop(context);
                        if (entry.type == 'lesson' && entry.lesson != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PlayerScreen(
                                lesson: entry.lesson!,
                                resumePosition: entry.position,
                              ),
                            ),
                          );
                        } else if (entry.type == 'youtube' &&
                            entry.video != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => YouTubePlayerScreen(
                                video: entry.video!,
                                resumePosition: entry.position,
                              ),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _HistoryTile
// ---------------------------------------------------------------------------

class _HistoryTile extends StatelessWidget {
  final WatchEntry entry;
  final VoidCallback onTap;

  const _HistoryTile({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final progress = entry.progress.clamp(0.0, 1.0);
    final percent = (progress * 100).round();

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            if (entry.videoChannelTitle != null) ...[
              const SizedBox(height: 2),
              Text(entry.videoChannelTitle!,
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) => Stack(
                children: [
                  Container(
                    height: 6,
                    width: constraints.maxWidth,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  Container(
                    height: 6,
                    width: constraints.maxWidth * progress,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1976D2),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text('$percent%',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
