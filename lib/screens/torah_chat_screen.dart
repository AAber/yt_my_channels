import 'package:flutter/material.dart';
import 'package:torah_ai_assistant/torah_ai_assistant.dart';
import '../services/saved_channels_service.dart';
import '../services/youtube_service.dart';
import '../States/Keys.dart';

class TorahChatScreen extends StatefulWidget {
  const TorahChatScreen({super.key});

  @override
  State<TorahChatScreen> createState() => _TorahChatScreenState();
}

class _TorahChatScreenState extends State<TorahChatScreen> {
  late final GroqClient _groq;
  final _controller = TextEditingController();
  final _scrollKey = GlobalKey<AnimatedListState>();
  final _scrollController = ScrollController();

  // conversation sent to the LLM: alternating user/assistant turns
  final List<Map<String, String>> _conversation = [];
  // display messages: {role, text}
  final List<Map<String, String>> _display = [];

  bool _loading = false;
  bool _done = false; // suggestions received
  List<ChannelSuggestion> _suggestions = [];
  int _questionCount = 0;

  @override
  void initState() {
    super.initState();
    _groq = GroqClient(apiKey: groqApiKey);
    _kickOff();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _kickOff() async {
    setState(() => _loading = true);
    final resp = await _groq.channelFinderStep(_conversation);
    _handleResponse(resp);
  }

  void _handleResponse(ChannelFinderResponse resp) {
    if (resp.type == ChannelFinderResponseType.suggestions) {
      setState(() {
        _suggestions = resp.suggestions!;
        _done = true;
        _loading = false;
      });
      _addDisplay('assistant', 'Here are 3 channels I think you\'ll love 🎵');
    } else {
      _addDisplay('assistant', resp.question!);
      setState(() => _loading = false);
    }
    _scrollToBottom();
  }

  void _addDisplay(String role, String text) {
    setState(() => _display.add({'role': role, 'text': text}));
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _loading || _done) return;
    _controller.clear();
    _questionCount++;

    _addDisplay('user', text);
    _conversation.add({'role': 'user', 'content': text});

    setState(() => _loading = true);
    final resp = await _groq.channelFinderStep(_conversation);

    // record assistant turn in conversation
    final assistantText = resp.type == ChannelFinderResponseType.question
        ? resp.question!
        : 'Here are my suggestions.';
    _conversation.add({'role': 'assistant', 'content': assistantText});

    _handleResponse(resp);
  }

  Future<void> _addChannel(ChannelSuggestion suggestion) async {
    if (SavedChannelsService.instance.channels.any((c) => c.id == suggestion.channelId)) {
      _showSnack('"${suggestion.title}" is already in your list.');
      return;
    }
    if (SavedChannelsService.instance.channels.length >= SavedChannelsService.maxChannels) {
      _showSnack('Maximum ${SavedChannelsService.maxChannels} channels reached.');
      return;
    }

    _showSnack('Looking up "${suggestion.title}"…');

    try {
      final ytService = YouTubeService();
      final channel = await ytService.fetchChannelInfo(suggestion.channelId);
      if (channel == null) {
        // Fallback: save with the AI-provided title, no avatar
        await SavedChannelsService.instance.add(SavedChannel(
          id: suggestion.channelId,
          title: suggestion.title,
          avatarUrl: '',
        ));
      } else {
        await SavedChannelsService.instance.add(channel);
      }
      if (mounted) {
        _showSnack('"${suggestion.title}" added! ✓');
        setState(() {}); // refresh button states
      }
    } catch (e) {
      if (mounted) _showSnack('Could not add channel. Check your connection.');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _restart() {
    setState(() {
      _conversation.clear();
      _display.clear();
      _suggestions = [];
      _done = false;
      _questionCount = 0;
    });
    _kickOff();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.orange[600],
        title: const Text('Channel Finder AI'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Start over',
            onPressed: _restart,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _display.length + (_loading ? 1 : 0) + (_done ? 1 : 0),
              itemBuilder: (context, i) {
                if (i < _display.length) return _buildBubble(_display[i]);
                if (_loading) return _buildTyping();
                if (_done) return _buildSuggestions();
                return const SizedBox.shrink();
              },
            ),
          ),
          if (!_done) _buildInput(),
        ],
      ),
    );
  }

  Widget _buildBubble(Map<String, String> msg) {
    final isUser = msg['role'] == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: isUser ? Colors.orange[600] : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          msg['text']!,
          style: TextStyle(color: isUser ? Colors.white : Colors.black87, fontSize: 15),
        ),
      ),
    );
  }

  Widget _buildTyping() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(16)),
        child: const SizedBox(
          width: 40,
          height: 16,
          child: _TypingDots(),
        ),
      ),
    );
  }

  Widget _buildSuggestions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        for (final s in _suggestions) _buildSuggestionCard(s),
      ],
    );
  }

  Widget _buildSuggestionCard(ChannelSuggestion s) {
    final alreadyAdded = SavedChannelsService.instance.channels.any((c) => c.id == s.channelId);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.orange[100],
          child: const Icon(Icons.subscriptions, color: Colors.orange),
        ),
        title: Text(s.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(s.reason, style: const TextStyle(fontSize: 13)),
        trailing: alreadyAdded
            ? const Icon(Icons.check_circle, color: Colors.green)
            : FilledButton(
                onPressed: () => _addChannel(s),
                style: FilledButton.styleFrom(backgroundColor: Colors.orange[600]),
                child: const Text('Add'),
              ),
      ),
    );
  }

  Widget _buildInput() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: !_loading,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'Type your answer…',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _loading ? null : _send,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.orange[600],
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(12),
              ),
              child: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final offset = ((_ctrl.value * 3 - i) % 1.0);
            final opacity = offset < 0.5 ? offset * 2 : (1 - offset) * 2;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Opacity(
                opacity: opacity.clamp(0.2, 1.0),
                child: const CircleAvatar(radius: 4, backgroundColor: Colors.grey),
              ),
            );
          }),
        );
      },
    );
  }
}
