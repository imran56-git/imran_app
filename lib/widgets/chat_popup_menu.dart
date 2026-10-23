import 'package:flutter/material.dart';
import '../utils/popup_menu_actions.dart';
import 'popup_menu_item_tile.dart';

class ChatPopupMenu extends StatelessWidget {
  final Function(ChatMenuAction) onSelected;
  final bool isBlockedByMe;

  const ChatPopupMenu({
    super.key,
    required this.onSelected,
    this.isBlockedByMe = false,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ChatMenuAction>(
      icon: const Icon(
        Icons.more_vert_rounded,
        color: Colors.white,
        size: 22,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 8,
      color: Colors.white,
      offset: const Offset(0, 42),
      onSelected: onSelected,
      itemBuilder: (context) => [
        PopupMenuItem<ChatMenuAction>(
          value: ChatMenuAction.viewProfile,
          padding: EdgeInsets.zero,
          child: const PopupMenuItemTile(
            icon: Icons.person_outline_rounded,
            title: 'View Profile',
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem<ChatMenuAction>(
          value: ChatMenuAction.blockUser,
          padding: EdgeInsets.zero,
          child: PopupMenuItemTile(
            icon: isBlockedByMe ? Icons.lock_open_rounded : Icons.block_rounded,
            title: isBlockedByMe ? 'Unblock User' : 'Block User',
            textColor: isBlockedByMe ? const Color(0xFF10B981) : Colors.redAccent,
          ),
        ),
        PopupMenuItem<ChatMenuAction>(
          value: ChatMenuAction.reportUser,
          padding: EdgeInsets.zero,
          child: const PopupMenuItemTile(
            icon: Icons.flag_outlined,
            title: 'Report User',
            textColor: Colors.orangeAccent,
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem<ChatMenuAction>(
          value: ChatMenuAction.clearChat,
          padding: EdgeInsets.zero,
          child: const PopupMenuItemTile(
            icon: Icons.cleaning_services_outlined,
            title: 'Clear Chat',
          ),
        ),
        PopupMenuItem<ChatMenuAction>(
          value: ChatMenuAction.deleteConversation,
          padding: EdgeInsets.zero,
          child: const PopupMenuItemTile(
            icon: Icons.delete_outline_rounded,
            title: 'Delete Conversation',
            textColor: Colors.red,
          ),
        ),
      ],
    );
  }
}
