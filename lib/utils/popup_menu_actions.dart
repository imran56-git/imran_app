enum ChatMenuAction {
  viewProfile,
  blockUser,
  reportUser,
  clearChat,
  deleteConversation,
}

extension ChatMenuActionExtension on ChatMenuAction {
  String get title {
    switch (this) {
      case ChatMenuAction.viewProfile:
        return 'View Profile';
      case ChatMenuAction.blockUser:
        return 'Block User';
      case ChatMenuAction.reportUser:
        return 'Report User';
      case ChatMenuAction.clearChat:
        return 'Clear Chat';
      case ChatMenuAction.deleteConversation:
        return 'Delete Conversation';
    }
  }

  bool get isDestructive {
    switch (this) {
      case ChatMenuAction.blockUser:
      case ChatMenuAction.clearChat:
      case ChatMenuAction.deleteConversation:
        return true;
      case ChatMenuAction.viewProfile:
      case ChatMenuAction.reportUser:
        return false;
    }
  }
}
