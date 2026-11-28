import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TrayMediaItem {
  final String id;
  File file;
  String? caption;
  final bool isImage;
  final String fileName;

  TrayMediaItem({
    required this.id,
    required this.file,
    this.caption,
    required this.isImage,
    required this.fileName,
  });

  TrayMediaItem copyWith({
    String? id,
    File? file,
    String? caption,
    bool? isImage,
    String? fileName,
  }) {
    return TrayMediaItem(
      id: id ?? this.id,
      file: file ?? this.file,
      caption: caption ?? this.caption,
      isImage: isImage ?? this.isImage,
      fileName: fileName ?? this.fileName,
    );
  }
}

class MediaShortcutTray extends StatefulWidget {
  final List<TrayMediaItem> items;
  final Set<String> selectedIds;
  final Function(TrayMediaItem item, int index) onItemTap;
  final Function(TrayMediaItem item, int index) onItemRemove;
  final Function(String id) onItemToggleSelect;
  final VoidCallback onClearSelection;
  final VoidCallback onClearAll;

  const MediaShortcutTray({
    super.key,
    required this.items,
    required this.selectedIds,
    required this.onItemTap,
    required this.onItemRemove,
    required this.onItemToggleSelect,
    required this.onClearSelection,
    required this.onClearAll,
  });

  @override
  State<MediaShortcutTray> createState() => _MediaShortcutTrayState();
}

class _MediaShortcutTrayState extends State<MediaShortcutTray> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final hasPartialSelection = widget.selectedIds.isNotEmpty;

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: theme.dividerColor.withValues(alpha: 0.15),
              width: 1.0,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              offset: const Offset(0, -3),
              blurRadius: 6,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14.0, 8.0, 10.0, 4.0),
              child: Row(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      hasPartialSelection
                          ? Icons.check_circle_rounded
                          : Icons.collections_rounded,
                      key: ValueKey<bool>(hasPartialSelection),
                      size: 17,
                      color: hasPartialSelection
                          ? theme.colorScheme.primary
                          : theme.hintColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      hasPartialSelection
                          ? '${widget.selectedIds.length} of ${widget.items.length} selected for send'
                          : '${widget.items.length} ${widget.items.length == 1 ? "item" : "items"} ready',
                      key: ValueKey<String>(
                        hasPartialSelection
                            ? 'selected_${widget.selectedIds.length}'
                            : 'all_${widget.items.length}',
                      ),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: hasPartialSelection
                            ? theme.colorScheme.primary
                            : theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (hasPartialSelection)
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        widget.onClearSelection();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Deselect All',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: theme.hintColor.withValues(alpha: 0.8),
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    splashRadius: 16,
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      widget.onClearAll();
                    },
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 104,
              child: ListView.separated(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                itemCount: widget.items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final item = widget.items[index];
                  final isSelected = widget.selectedIds.contains(item.id);

                  return _TrayItemCard(
                    key: ValueKey<String>(item.id),
                    item: item,
                    isSelected: isSelected,
                    hasPartialSelection: hasPartialSelection,
                    onTap: () {
                      if (hasPartialSelection) {
                        HapticFeedback.selectionClick();
                        widget.onItemToggleSelect(item.id);
                      } else {
                        widget.onItemTap(item, index);
                      }
                    },
                    onLongPress: () {
                      HapticFeedback.mediumImpact();
                      widget.onItemToggleSelect(item.id);
                    },
                    onRemove: () {
                      HapticFeedback.lightImpact();
                      widget.onItemRemove(item, index);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _TrayItemCard extends StatefulWidget {
  final TrayMediaItem item;
  final bool isSelected;
  final bool hasPartialSelection;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onRemove;

  const _TrayItemCard({
    super.key,
    required this.item,
    required this.isSelected,
    required this.hasPartialSelection,
    required this.onTap,
    required this.onLongPress,
    required this.onRemove,
  });

  @override
  State<_TrayItemCard> createState() => _TrayItemCardState();
}

class _TrayItemCardState extends State<_TrayItemCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  Timer? _longPressTimer;
  bool _longPressTriggered = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _longPressTriggered = false;
    _animController.forward();
    _longPressTimer?.cancel();
    _longPressTimer = Timer(const Duration(milliseconds: 500), () {
      _longPressTriggered = true;
      _animController.reverse();
      widget.onLongPress();
    });
  }

  void _handleTapUp(TapUpDetails details) {
    _longPressTimer?.cancel();
    _animController.reverse();
    if (!_longPressTriggered) {
      widget.onTap();
    }
  }

  void _handleTapCancel() {
    _longPressTimer?.cancel();
    _animController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSelected = widget.isSelected;
    final primaryColor = theme.colorScheme.primary;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: 80,
          height: 92,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? primaryColor
                  : widget.hasPartialSelection
                      ? theme.dividerColor.withValues(alpha: 0.25)
                      : theme.dividerColor.withValues(alpha: 0.35),
              width: isSelected ? 2.5 : 1.2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.38),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                      spreadRadius: 1,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(11.5),
                child: widget.item.isImage
                    ? Image.file(
                        widget.item.file,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.broken_image_outlined,
                            size: 28,
                            color: theme.hintColor,
                          ),
                        ),
                      )
                    : Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        padding: const EdgeInsets.all(6),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _getFileIcon(widget.item.fileName),
                              size: 28,
                              color: primaryColor,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.item.fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 9.5,
                                color: theme.textTheme.bodySmall?.color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              if (widget.item.isImage)
                Positioned(
                  bottom: 4,
                  left: 4,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.crop_rotate_rounded,
                      size: 11,
                      color: Colors.white,
                    ),
                  ),
                ),
              if (widget.item.caption != null && widget.item.caption!.trim().isNotEmpty)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.72),
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(11.5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.short_text_rounded,
                          size: 11,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            widget.item.caption!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (widget.hasPartialSelection)
                Positioned(
                  top: 5,
                  left: 5,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? primaryColor
                          : Colors.black.withValues(alpha: 0.4),
                      border: Border.all(
                        color: Colors.white,
                        width: 1.8,
                      ),
                    ),
                    child: isSelected
                        ? const Center(
                            child: Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                ),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: widget.onRemove,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.68),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.8),
                        width: 1.0,
                      ),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 13,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getFileIcon(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'doc':
      case 'docx':
        return Icons.description_rounded;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart_rounded;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow_rounded;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.archive_rounded;
      case 'mp3':
      case 'wav':
      case 'm4a':
        return Icons.audiotrack_rounded;
      case 'mp4':
      case 'mov':
      case 'avi':
        return Icons.videocam_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }
}