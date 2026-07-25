import 'package:flutter/material.dart';
import '../utils/popup_menu_actions.dart';
import 'popup_menu_item_tile.dart';

class ChatPopupMenu extends StatelessWidget {
  final Function(ChatMenuAction) onSelected;

  const ChatPopupMenu({
    super.key,
    required this.onSelected,
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
      elevation: 6,
      color: Colors.white,
      offset: const Offset(0, 40),
      itemBuilder: (context) => [
        PopupMenuItem<ChatMenuAction>(
          value: ChatMenuAction.viewProfile,
          padding: EdgeInsets.zero,
          child: PopupMenuItemTile(
            icon: Icons.person_outline_rounded,
            title: 'View Profile',
            onTap: () {
              Navigator.pop(context);
              onSelected(ChatMenuAction.viewProfile);
            },
          ),
        ),
        PopupMenuItem<ChatMenuAction>(
          value: ChatMenuAction.blockUser,
          padding: EdgeInsets.zero,
          child: PopupMenuItemTile(
            icon: Icons.block_rounded,
            title: 'Block User',
            textColor: Colors.redAccent,
            onTap: () {
              Navigator.pop(context);
              onSelected(ChatMenuAction.blockUser);
            },
          ),
        ),
        PopupMenuItem<ChatMenuAction>(
          value: ChatMenuAction.reportUser,
          padding: EdgeInsets.zero,
          child: PopupMenuItemTile(
            icon: Icons.flag_outlined,
            title: 'Report User',
            textColor: Colors.orangeAccent,
            onTap: () {
              Navigator.pop(context);
              onSelected(ChatMenuAction.reportUser);
            },
          ),
        ),
        PopupMenuItem<ChatMenuAction>(
          value: ChatMenuAction.clearChat,
          padding: EdgeInsets.zero,
          child: PopupMenuItemTile(
            icon: Icons.cleaning_services_outlined,
            title: 'Clear Chat',
            onTap: () {
              Navigator.pop(context);
              onSelected(ChatMenuAction.clearChat);
            },
          ),
        ),
        PopupMenuItem<ChatMenuAction>(
          value: ChatMenuAction.deleteConversation,
          padding: EdgeInsets.zero,
          child: PopupMenuItemTile(
            icon: Icons.delete_outline_rounded,
            title: 'Delete Conversation',
            textColor: Colors.red,
            onTap: () {
              Navigator.pop(context);
              onSelected(ChatMenuAction.deleteConversation);
            },
          ),
        ),
      ],
    );
  }
}
