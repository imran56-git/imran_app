class ChatConstants {
  static const String typeText = 'text';
  static const String typeImage = 'image';
  static const String typeVideo = 'video';
  static const String typeAudio = 'audio';
  static const String typeVoice = 'voice';
  static const String typeDocument = 'document';
  static const String typeLocation = 'location';
  static const String typeContact = 'contact';

  static const String statusSent = 'sent';
  static const String statusDelivered = 'delivered';
  static const String statusSeen = 'seen';

  static const String tableChats = 'chats';
  static const String tableMessages = 'messages';
  static const String tableGroups = 'groups';
  static const String tableUsers = 'users';

  static const String fieldTimestamp = 'timestamp';
  static const String fieldMessageId = 'messageId';
  static const String fieldSenderId = 'senderId';
  static const String fieldReceiverId = 'receiverId';

  static const int maxMessageLength = 5000;
  static const int maxAudioDurationSeconds = 300;
  static const int compressionQuality = 50;
}
