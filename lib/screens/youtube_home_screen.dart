import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../l10n/language_provider.dart';
import '../services/youtube_service.dart';
import 'source_selection_screen.dart';
import 'youtube_player_screen.dart';

class YouTubeHomeScreen extends StatefulWidget {
  final String channelId;
  final String title;

  const YouTubeHomeScreen({
    super.key,
    required this.channelId,
    required this.title,
  });

  @override
  State<YouTubeHomeScreen> createState() => _YouTubeHomeScreenState();
}

class _YouTubeHomeScreenState extends State<YouTubeHomeScreen> {
  final YouTubeService _youtubeService = YouTubeService();
  final TextEditingController _searchController = TextEditingController();
  
  List<YouTubeVideo> _videos = [];
  List<YouTubeVideo> _filteredVideos = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVideos();
    _searchController.addListener(_filterVideos);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterVideos() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredVideos = _videos;
      } else {
        _filteredVideos = _videos
            .where((video) => 
                video.title.toLowerCase().contains(query) ||
                video.description.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  Future<void> _loadVideos() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final videos = await _youtubeService.getChannelVideos(channelId: widget.channelId);
      
      setState(() {
        _videos = videos;
        _filteredVideos = videos;
        _isLoading = false;
      });
    } catch (e) {
      developer.log('CRITICAL_ERROR: Failed to load YouTube videos: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final isHebrew = languageProvider.locale.languageCode == 'he';
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: isHebrew ? null : IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _navigateToSourceSelection(context),
        ),
        actions: [
          if (isHebrew)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => _navigateToSourceSelection(context),
            ),
          IconButton(
            icon: const Icon(Icons.language),
            onPressed: () {
              languageProvider.toggleLanguage();
            },
          ),
        ],
      ),
      body: _buildBody(),
      // floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      // floatingActionButton: FloatingActionButton(
      //   onPressed: () {
      //     Navigator.push(
      //       context,
      //       MaterialPageRoute(
      //         builder: (context) => const TorahChatScreen(),
      //       ),
      //     );
      //   },
      //   backgroundColor: Colors.orange,
      //   child: const Icon(
      //     Icons.auto_awesome,
      //     color: Colors.white,
      //   ),
      // ),
    );
  }

  void _navigateToSourceSelection(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const SourceSelectionScreen(),
      ),
      (route) => false,
    );
  }

  Widget _buildBody() {
    final l10n = AppLocalizations.of(context);
    
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      final isApiKeyError = _error!.contains('API key') || _error!.contains('400') || _error!.contains('403');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isApiKeyError ? Icons.key_off : Icons.error_outline,
              size: 64,
              color: isApiKeyError ? Colors.orange : Colors.red,
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                isApiKeyError
                    ? 'YouTube API key not configured.\nAdd your key to:\nlib/config/api_keys.dart'
                    : '${l10n.error}: $_error',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: isApiKeyError ? Colors.orange[800] : null,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadVideos,
              child: Text(l10n.tryAgain),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadVideos,
      child: Column(
        children: [
          // Search Box
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l10n.translate('search_videos'),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          
          // Results count
          if (_searchController.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  '${_filteredVideos.length} ${l10n.translate('results')}',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ),
            ),
          
          // Video List
          Expanded(
            child: _filteredVideos.isEmpty
                ? Center(
                    child: Text(
                      l10n.translate('no_results'),
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredVideos.length,
                    itemBuilder: (context, index) {
                      final video = _filteredVideos[index];
                      return _buildVideoTile(video);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoTile(YouTubeVideo video) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => YouTubePlayerScreen(
                video: video,
                channelTitle: widget.title,
              ),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                video.thumbnailUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.play_circle_outline, size: 64),
                  );
                },
              ),
            ),
            
            // Title and description
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    video.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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