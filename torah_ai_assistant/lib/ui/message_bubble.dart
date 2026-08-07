import 'dart:convert';
import 'package:flutter/material.dart';
import '../agent/models.dart';
import 'chat_theme.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final ChatTheme theme;
  final Function(SourceResult)? onSourceTap;

  const MessageBubble({
    Key? key,
    required this.message,
    required this.theme,
    this.onSourceTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    
    // Debug message content
    if (!isUser) {
      print('💬 MessageBubble: Displaying AI message: "${message.text}"');
      print('💬 MessageBubble: Message length: ${message.text.length} chars');
      print('💬 MessageBubble: Message bytes: ${utf8.encode(message.text).length} bytes');
      print('💬 MessageBubble: First 100 chars: "${message.text.length > 100 ? message.text.substring(0, 100) + '...' : message.text}"');
    }
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            _buildAvatar(theme.primaryColor, Icons.auto_awesome),
            const SizedBox(width: 8),
          ],
          
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isUser ? theme.userBubbleColor : theme.agentBubbleColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isUser ? 18 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.text,
                        style: theme.messageTextStyle.copyWith(
                          color: isUser ? Colors.white : theme.onSurfaceColor,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                      if (!isUser && message.searchResults != null && message.searchResults!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _buildSourceChips(message.searchResults!),
                      ],
                    ],
                  ),
                ),
                
                Container(
                  margin: EdgeInsets.only(
                    top: 4,
                    left: isUser ? 0 : 12,
                    right: isUser ? 12 : 0,
                  ),
                  child: Text(
                    _formatTime(message.timestamp),
                    style: theme.timestampTextStyle,
                  ),
                ),
              ],
            ),
          ),
          
          if (isUser) ...[
            const SizedBox(width: 8),
            _buildAvatar(Colors.grey[300]!, Icons.person),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar(Color color, IconData icon) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Icon(
        icon,
        color: Colors.white,
        size: 20,
      ),
    );
  }

  Widget _buildSourceChips(List<SourceResult> results) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: results.map((result) {
        final iconAsset = (result.metadata['channel_icon'] ?? result.metadata['source_icon']) as String?;
        return GestureDetector(
          onTap: () => onSourceTap?.call(result),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: theme.primaryColor.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (iconAsset != null)
                  Image.asset(
                    iconAsset,
                    width: 24,
                    height: 24,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.play_circle_outline,
                      size: 24,
                      color: theme.primaryColor,
                    ),
                  )
                else
                  Icon(
                    Icons.play_circle_outline,
                    size: 24,
                    color: theme.primaryColor,
                  ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    result.title,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.rtl,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} שעות';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} דקות';
    } else {
      return 'עכשיו';
    }
  }
}