import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import '../l10n/app_localizations.dart';
import '../models/series.dart';
import '../services/api_service.dart';
import '../services/local_storage_service.dart';
import 'source_selection_screen.dart';
import 'lessons_screen.dart';

enum _SeriesSort { name, lessonCount }

class SeriesListScreen extends StatefulWidget {
  const SeriesListScreen({super.key});

  @override
  State<SeriesListScreen> createState() => _SeriesListScreenState();
}

class _SeriesListScreenState extends State<SeriesListScreen> {
  final ApiService _apiService = ApiService();
  final LocalStorageService _localStorage = LocalStorageService();
  final TextEditingController _searchController = TextEditingController();
  
  List<Series> _series = [];
  List<Series> _filteredSeries = [];
  bool _isLoading = true;
  String? _error;
  _SeriesSort _sort = _SeriesSort.name;

  @override
  void initState() {
    super.initState();
    _loadSeries();
    _searchController.addListener(_filterSeries);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applySort(List<Series> list) {
    if (_sort == _SeriesSort.name) {
      list.sort((a, b) => a.name.compareTo(b.name));
    } else {
      list.sort((a, b) => b.lessonCount.compareTo(a.lessonCount));
    }
  }

  void _filterSeries() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      final filtered = query.isEmpty
          ? List<Series>.from(_series)
          : _series.where((s) => s.name.toLowerCase().contains(query)).toList();
      _applySort(filtered);
      _filteredSeries = filtered;
    });
  }

  Future<void> _loadSeries() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final series = await _apiService.getSeries();
      
      // Cache series locally
      await _localStorage.cacheSeries(series);

      final sorted = List<Series>.from(series);
      _applySort(sorted);
      setState(() {
        _series = sorted;
        _filteredSeries = sorted;
        _isLoading = false;
      });
    } catch (e) {
      developer.log('CRITICAL_ERROR: Failed to load series list: $e');
      // Try to load from cache
      final cached = _localStorage.getCachedSeries();
      if (cached.isNotEmpty) {
        _applySort(cached);
        setState(() {
          _series = cached;
          _filteredSeries = cached;
          _error = 'נטען מהמטמון: $e';
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showSortMenu(BuildContext anchorContext) async {
    final button = anchorContext.findRenderObject()! as RenderBox;
    final overlay =
        Navigator.of(anchorContext).overlay!.context.findRenderObject()!
            as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero),
            ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );
    final selected = await showMenu<_SeriesSort>(
      context: anchorContext,
      position: position,
      items: [
        PopupMenuItem(
          value: _SeriesSort.name,
          child: Row(children: [
            Icon(Icons.check,
                size: 18,
                color: _sort == _SeriesSort.name
                    ? null
                    : Colors.transparent),
            const SizedBox(width: 8),
            const Text('א-ב / A-Z'),
          ]),
        ),
        PopupMenuItem(
          value: _SeriesSort.lessonCount,
          child: Row(children: [
            Icon(Icons.check,
                size: 18,
                color: _sort == _SeriesSort.lessonCount
                    ? null
                    : Colors.transparent),
            const SizedBox(width: 8),
            const Text('מספר שיעורים'),
          ]),
        ),
      ],
    );
    if (selected != null && mounted) {
      setState(() => _sort = selected);
      _filterSeries();
    }
  }

  Widget _sortIconButton() {
    return Builder(
      builder: (btnContext) => IconButton(
        icon: const Icon(Icons.sort),
        tooltip: 'מיון',
        onPressed: () => _showSortMenu(btnContext),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isHebrew = Localizations.localeOf(context).languageCode == 'he';
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.series),
        centerTitle: true,
        automaticallyImplyLeading: false,
        // RTL: leading is the physical right — put sort here for Hebrew.
        leading: isHebrew
            ? _sortIconButton()
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => _navigateToSourceSelection(context),
              ),
        actions: [
          if (isHebrew)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => _navigateToSourceSelection(context),
            )
          else
            _sortIconButton(),
        ],
      ),
      body: _buildBody(),
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

    if (_error != null && _series.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${l10n.error}: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadSeries,
              child: Text(l10n.tryAgain),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSeries,
      child: Column(
        children: [
          // Search Box
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l10n.translate('search_series'),
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
                  '${_filteredSeries.length} ${l10n.translate('results')}',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ),
            ),
          
          // Grid
          Expanded(
            child: _filteredSeries.isEmpty
                ? Center(
                    child: Text(
                      l10n.translate('no_results'),
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.5,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: _filteredSeries.length,
                    itemBuilder: (context, index) {
                      final series = _filteredSeries[index];
                      return _buildSeriesCard(series);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeriesCard(Series series) {
    final l10n = AppLocalizations.of(context);
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LessonsScreen(series: series),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (series.sourceId == 'bneidavid')
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Image.asset(
                    'assets/icon/david.png',
                    width: 32,
                    height: 32,
                    errorBuilder: (context, error, stackTrace) {
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              Flexible(
                child: Text(
                  series.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  l10n.lessonCount(series.lessonCount),
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
