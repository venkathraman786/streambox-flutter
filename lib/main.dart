import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(const StreamBoxApp());

class StreamBoxApp extends StatelessWidget {
  const StreamBoxApp({super.key});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFFF526B);
    return MaterialApp(
      title: 'StreamBox',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF101116),
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.dark,
          surface: const Color(0xFF1B1C24),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF191A21),
          surfaceTintColor: Colors.transparent,
        ),
        useMaterial3: true,
      ),
      home: const VideoGalleryPage(),
    );
  }
}

class VideoGalleryPage extends StatefulWidget {
  const VideoGalleryPage({super.key});

  @override
  State<VideoGalleryPage> createState() => _VideoGalleryPageState();
}

class _VideoGalleryPageState extends State<VideoGalleryPage> {
  static const String api =
      'https://www.eporner.com/api/v2/video/search/';

  final _searchController = TextEditingController(text: 'all');
  final _scrollController = ScrollController();

  final List<Map<String, dynamic>> _videos = [];
  String _query = 'all';
  String _order = 'top-weekly';
  int _page = 1;
  bool _loading = false;
  bool _hasMore = true;
  String? _error;

  final Map<String, String> _sortOptions = const {
    'Top Weekly': 'top-weekly',
    'Latest': 'latest',
    'Most Popular': 'most-popular',
    'Top Rated': 'top-rated',
    'Longest': 'longest',
    'Shortest': 'shortest',
  };

  @override
  void initState() {
    super.initState();
    _loadVideos(reset: true);
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 300 &&
          !_loading &&
          _hasMore) {
        _loadVideos();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadVideos({bool reset = false}) async {
    if (_loading) return;
    if (reset) {
      setState(() {
        _page = 1;
        _hasMore = true;
        _error = null;
        _videos.clear();
      });
    }
    if (!_hasMore) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final uri = Uri.parse(api).replace(queryParameters: {
      'query': _query.isEmpty ? 'all' : _query,
      'per_page': '24',
      'page': '$_page',
      'thumbsize': 'big',
      'order': _order,
      'format': 'json',
    });

    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 25));

      if (response.statusCode != 200) {
        throw Exception('API returned HTTP ${response.statusCode}');
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Unexpected API response format');
      }

      final raw = decoded['videos'] ?? decoded['results'] ?? [];
      if (raw is! List) throw Exception('Video list is missing');

      final items = raw
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      if (!mounted) return;
      setState(() {
        _videos.addAll(items);
        _hasMore = items.length >= 24;
        if (items.isNotEmpty) _page++;
        if (items.isEmpty && _videos.isEmpty) {
          _error = 'No videos found. Try another search.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load videos.\n${e.toString()}';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _thumbnail(Map<String, dynamic> video) {
    final thumb = video['default_thumb'];
    if (thumb is Map && thumb['src'] is String) {
      return thumb['src'] as String;
    }
    final image = video['image'];
    return image is String ? image : '';
  }

  String _duration(Map<String, dynamic> video) {
    final value = video['length_min'] ?? video['duration'] ?? '';
    return value.toString();
  }

  String _views(Map<String, dynamic> video) {
    final value = video['views'];
    final number = int.tryParse(value?.toString() ?? '');
    if (number == null) return 'Views unavailable';
    return '${number.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    )} views';
  }

  Future<void> _openVideo(Map<String, dynamic> video) async {
    final raw = video['url'];
    if (raw is! String) {
      _showMessage('Video link is unavailable.');
      return;
    }
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        uri.scheme != 'https' ||
        !(uri.host == 'eporner.com' || uri.host.endsWith('.eporner.com'))) {
      _showMessage('This video link is not valid.');
      return;
    }
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showMessage('Could not open the video link.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _search() {
    FocusScope.of(context).unfocus();
    _query = _searchController.text.trim().isEmpty
        ? 'all'
        : _searchController.text.trim();
    _loadVideos(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 18,
        title: RichText(
          text: const TextSpan(
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
            children: [
              TextSpan(
                text: 'Stream',
                style: TextStyle(color: Color(0xFFFF526B)),
              ),
              TextSpan(text: 'Box', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadVideos(reset: true),
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            textInputAction: TextInputAction.search,
                            onSubmitted: (_) => _search(),
                            decoration: InputDecoration(
                              hintText: 'Search videos...',
                              filled: true,
                              fillColor: const Color(0xFF282932),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _search,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFFF526B),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 16,
                            ),
                          ),
                          child: const Text('Search'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Explore Videos',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Discover videos in one place',
                      style: TextStyle(color: Color(0xFFA6A6B2)),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: _order,
                      isExpanded: true,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF282932),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: _sortOptions.entries
                          .map((entry) => DropdownMenuItem(
                                value: entry.value,
                                child: Text(entry.key),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _order = value);
                        _loadVideos(reset: true);
                      },
                    ),
                  ],
                ),
              ),
            ),
            if (_error != null && _videos.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_off, size: 44,
                            color: Color(0xFFA6A6B2)),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => _loadVideos(reset: true),
                          child: const Text('Try Again'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (_videos.isEmpty && _loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final video = _videos[index];
                      final title = (video['title'] ?? 'Untitled video')
                          .toString();
                      final imageUrl = _thumbnail(video);
                      final duration = _duration(video);
                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _openVideo(video),
                        child: Card(
                          margin: EdgeInsets.zero,
                          clipBehavior: Clip.antiAlias,
                          color: const Color(0xFF1B1C24),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 6,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    if (imageUrl.startsWith('https://'))
                                      CachedNetworkImage(
                                        imageUrl: imageUrl,
                                        fit: BoxFit.cover,
                                        placeholder: (_, __) => Container(
                                          color: const Color(0xFF292A32),
                                          child: const Icon(
                                            Icons.play_circle_outline,
                                            size: 38,
                                          ),
                                        ),
                                        errorWidget: (_, __, ___) => Container(
                                          color: const Color(0xFF292A32),
                                          child: const Icon(
                                            Icons.broken_image_outlined,
                                            size: 32,
                                          ),
                                        ),
                                      )
                                    else
                                      Container(
                                        color: const Color(0xFF292A32),
                                        child: const Icon(
                                          Icons.play_circle_outline,
                                          size: 38,
                                        ),
                                      ),
                                    if (duration.isNotEmpty)
                                      Positioned(
                                        right: 6,
                                        bottom: 6,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black87,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            duration,
                                            style: const TextStyle(
                                              fontSize: 10,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 4,
                                child: Padding(
                                  padding: const EdgeInsets.all(9),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                          height: 1.35,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        _views(video),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Color(0xFFA6A6B2),
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: _videos.length,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.82,
                  ),
                ),
              ),
            if (_loading && _videos.isNotEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            if (_error != null && _videos.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_error!, textAlign: TextAlign.center),
                ),
              ),
            if (!_loading && _videos.isNotEmpty && !_hasMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: Text(
                      'No more videos available',
                      style: TextStyle(color: Color(0xFFA6A6B2)),
                    ),
                  ),
                ),
              ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Text(
                  'Video metadata is provided by the configured API. '
                  'For adults 18+ only. Follow applicable laws and site terms.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFA6A6B2),
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
