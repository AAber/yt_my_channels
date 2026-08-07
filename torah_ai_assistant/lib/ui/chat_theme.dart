import 'package:flutter/material.dart';

class ChatTheme {
  final Color primaryColor;
  final Color onPrimaryColor;
  final Color backgroundColor;
  final Color surfaceColor;
  final Color onSurfaceColor;
  final Color dividerColor;
  final Color userBubbleColor;
  final Color agentBubbleColor;
  final TextStyle messageTextStyle;
  final TextStyle timestampTextStyle;

  const ChatTheme({
    this.primaryColor = Colors.orange,
    this.onPrimaryColor = Colors.white,
    this.backgroundColor = const Color(0xFFE5DDD5),
    this.surfaceColor = Colors.white,
    this.onSurfaceColor = Colors.black87,
    this.dividerColor = const Color(0xFFE0E0E0),
    this.userBubbleColor = Colors.orange,
    this.agentBubbleColor = Colors.white,
    this.messageTextStyle = const TextStyle(fontSize: 16, height: 1.3),
    this.timestampTextStyle = const TextStyle(fontSize: 12, color: Colors.grey),
  });

  static ChatTheme defaultTheme(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return ChatTheme(
      primaryColor: isDark ? Colors.blueGrey[700]! : Colors.orange[700]!,
      onPrimaryColor: Colors.white,
      backgroundColor: isDark ? const Color(0xFF0C1317) : const Color(0xFFE5DDD5),
      surfaceColor: isDark ? Colors.grey[900]! : Colors.grey[50]!,
      onSurfaceColor: isDark ? Colors.white : Colors.black87,
      dividerColor: isDark ? Colors.white24 : Colors.grey.withOpacity(0.3),
      userBubbleColor: isDark ? Colors.blueGrey[600]! : Colors.orange[600]!,
      agentBubbleColor: isDark ? Colors.grey[800]! : Colors.white,
    );
  }

  ChatTheme copyWith({
    Color? primaryColor,
    Color? onPrimaryColor,
    Color? backgroundColor,
    Color? surfaceColor,
    Color? onSurfaceColor,
    Color? dividerColor,
    Color? userBubbleColor,
    Color? agentBubbleColor,
    TextStyle? messageTextStyle,
    TextStyle? timestampTextStyle,
  }) {
    return ChatTheme(
      primaryColor: primaryColor ?? this.primaryColor,
      onPrimaryColor: onPrimaryColor ?? this.onPrimaryColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      surfaceColor: surfaceColor ?? this.surfaceColor,
      onSurfaceColor: onSurfaceColor ?? this.onSurfaceColor,
      dividerColor: dividerColor ?? this.dividerColor,
      userBubbleColor: userBubbleColor ?? this.userBubbleColor,
      agentBubbleColor: agentBubbleColor ?? this.agentBubbleColor,
      messageTextStyle: messageTextStyle ?? this.messageTextStyle,
      timestampTextStyle: timestampTextStyle ?? this.timestampTextStyle,
    );
  }
}