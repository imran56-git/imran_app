import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class ExpandableChatText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final int trimLines;
  final Color actionColor;

  const ExpandableChatText({
    super.key,
    required this.text,
    this.style,
    this.trimLines = 4,
    this.actionColor = const Color(0xFF1E88E5),
  });

  @override
  State<ExpandableChatText> createState() => _ExpandableChatTextState();
}

class _ExpandableChatTextState extends State<ExpandableChatText>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = widget.style ?? Theme.of(context).textTheme.bodyMedium!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final textSpan = TextSpan(
          text: widget.text,
          style: effectiveStyle,
        );

        final textPainter = TextPainter(
          text: textSpan,
          textDirection: Directionality.of(context),
          maxLines: widget.trimLines,
          ellipsis: '...',
        )..layout(maxWidth: constraints.maxWidth);

        if (!textPainter.didExceedMaxLines) {
          return Text(
            widget.text,
            style: effectiveStyle,
          );
        }

        return AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          alignment: Alignment.topLeft,
          child: _isExpanded
              ? Text.rich(
                  TextSpan(
                    text: widget.text,
                    style: effectiveStyle,
                    children: [
                      const TextSpan(text: ' '),
                      TextSpan(
                        text: 'Read less',
                        style: effectiveStyle.copyWith(
                          color: widget.actionColor,
                          fontWeight: FontWeight.w600,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            setState(() {
                              _isExpanded = false;
                            });
                          },
                      ),
                    ],
                  ),
                )
              : _buildCollapsedText(effectiveStyle, constraints.maxWidth),
        );
      },
    );
  }

  Widget _buildCollapsedText(TextStyle effectiveStyle, double maxWidth) {
    final linkSpan = TextSpan(
      text: '... Read more',
      style: effectiveStyle.copyWith(
        color: widget.actionColor,
        fontWeight: FontWeight.w600,
      ),
    );

    final linkPainter = TextPainter(
      text: linkSpan,
      textDirection: Directionality.of(context),
    )..layout(maxWidth: maxWidth);

    final position = TextPainter(
      text: TextSpan(text: widget.text, style: effectiveStyle),
      textDirection: Directionality.of(context),
      maxLines: widget.trimLines,
    )..layout(maxWidth: maxWidth);

    final endPosition = position.getPositionForOffset(
      Offset(maxWidth - linkPainter.width, position.height),
    );

    final lineEndOffset = position.getOffsetBefore(endPosition.offset) ?? endPosition.offset;
    final truncatedText = widget.text.substring(
      0,
      lineEndOffset > widget.text.length ? widget.text.length : lineEndOffset,
    );

    return Text.rich(
      TextSpan(
        text: truncatedText,
        style: effectiveStyle,
        children: [
          const TextSpan(text: '... '),
          TextSpan(
            text: 'Read more',
            style: effectiveStyle.copyWith(
              color: widget.actionColor,
              fontWeight: FontWeight.w600,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                setState(() {
                  _isExpanded = true;
                });
              },
          ),
        ],
      ),
    );
  }
}