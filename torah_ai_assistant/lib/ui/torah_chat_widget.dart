import 'package:flutter/material.dart';
import '../agent/torah_agent.dart';
import '../agent/models.dart';
import 'chat_theme.dart';
import 'message_bubble.dart';
import 'typing_indicator.dart';

class TorahChatWidget extends StatefulWidget {
  final TorahAgent agent;
  final ChatTheme? theme;
  final Function(SourceResult)? onSourceTap;
  final String? title;

  const TorahChatWidget({
    Key? key,
    required this.agent,
    this.theme,
    this.onSourceTap,
    this.title,
  }) : super(key: key);

  @override
  State<TorahChatWidget> createState() => _TorahChatWidgetState();
}

class _TorahChatWidgetState extends State<TorahChatWidget> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;
  late ChatTheme _theme;

  @override
  void initState() {
    super.initState();
    _theme = widget.theme ?? ChatTheme.defaultTheme(context);
    _loadSession();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSession() async {
    await widget.agent.loadSession();
    setState(() {});
    _scrollToBottom();
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

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _isTyping) return;

    final message = _messageController.text.trim();
    _messageController.clear();

    setState(() {
      _isTyping = true;
    });

    try {
      await widget.agent.sendMessage(message);
    } catch (e) {
      print('Error sending message: $e');
    } finally {
      setState(() {
        _isTyping = false;
      });
    }

    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _theme.backgroundColor,
              _theme.backgroundColor.withOpacity(0.8),
            ],
          ),
        ),
        child: Column(
          children: [
            // Messages
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: widget.agent.messages.length + (_isTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == widget.agent.messages.length && _isTyping) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: TypingIndicator(theme: _theme),
                    );
                  }
                  
                  final message = widget.agent.messages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: MessageBubble(
                      message: message,
                      theme: _theme,
                      onSourceTap: widget.onSourceTap,
                    ),
                  );
                },
              ),
            ),
            
            // Input — SafeArea keeps field above home indicator / gesture bar
            SafeArea(
              top: false,
              minimum: const EdgeInsets.only(bottom: 8),
              child: Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              decoration: BoxDecoration(
                color: _theme.surfaceColor,
                border: Border(
                  top: BorderSide(
                    color: _theme.dividerColor,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: _theme.backgroundColor,
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: _theme.dividerColor,
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: _messageController,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(
                          fontFamily: 'Heebo',
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          hintText: 'שאל אותי על תורה, הלכה, או שיעורים...',
                          hintStyle: TextStyle(
                            color: _theme.onSurfaceColor.withOpacity(0.6),
                            fontFamily: 'Heebo',
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                        enabled: !_isTyping,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: _theme.primaryColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _theme.primaryColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: _isTyping ? null : _sendMessage,
                      icon: Icon(
                        Icons.send,
                        color: _theme.onPrimaryColor,
                      ),
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
  }
}