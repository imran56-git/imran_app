import 'dart:io';
import 'package:flutter/material.dart';

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

    final hasPartialSelection = widget.selectedIds.isNotEmpty;

    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              offset: const Offset(0, -2),
              blurRadius: 4,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
              child: Row(
                children: [
                  Icon(
                    hasPartialSelection ? Icons.check_circle_outline : Icons.collections_outlined,
                    size: 16,
                    color: hasPartialSelection
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).hintColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    hasPartialSelection
                        ? '${widget.selectedIds.length} of ${widget.items.length} selected for send'
                        : '${widget.items.length} items ready',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: hasPartialSelection
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).hintColor,
                    ),
                  ),
                  const Spacer(),
                  if (hasPartialSelection)
                    GestureDetector(
                      onTap: widget.onClearSelection,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6.0),
                        child: Text(
                          'Deselect',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  GestureDetector(
                    onTap: widget.onClearAll,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Icon(
                        Icons.close,
                        size: 18,
                        color: Theme.of(context).hintColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 96,
              child: ListView.separated(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                itemCount: widget.items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final item = widget.items[index];
                  final isSelected = widget.selectedIds.contains(item.id);

                  return _TrayItemCard(
                    key: ValueKey(item.id),
                    item: item,
                    isSelected: isSelected,
                    hasPartialSelection: hasPartialSelection,
                    onTap: () => widget.onItemTap(item, index),
                    onLongPress: () => widget.onItemToggleSelect(item.id),
                    onRemove: () => widget.onItemRemove(item, index),
                  );
                },
              ),
            ),
            const SizedBox(height: 6),
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

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSelected = widget.isSelected;
    final primaryColor = theme.colorScheme.primary;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTapDown: (_) => _animController.forward(),
        onTapUp: (_) => _animController.reverse(),
        onTapCancel: () => _animController.reverse(),
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 76,
          height: 86,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? primaryColor
                  : widget.hasPartialSelection
                      ? Colors.transparent
                      : theme.dividerColor.withValues(alpha: 0.3),
              width: isSelected ? 2.5 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.35),
                      blurRadius: 6,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: widget.item.isImage
                    ? Image.file(
                        widget.item.file,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.broken_image, color: Colors.grey),
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
                              size: 26,
                              color: primaryColor,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.item.fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 9,
                                color: theme.textTheme.bodySmall?.color,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              if (widget.item.caption != null && widget.item.caption!.trim().isNotEmpty)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(10),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.short_text, size: 10, color: Colors.white),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            widget.item.caption!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (widget.hasPartialSelection)
                Positioned(
                  top: 4,
                  left: 4,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? primaryColor : Colors.black.withValues(alpha: 0.45),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 13, color: Colors.white)
                        : null,
                  ),
                ),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: widget.onRemove,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 12, color: Colors.white),
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
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'zip':
      case 'rar':
        return Icons.archive;
      default:
        return Icons.insert_drive_file;
    }
  }
}