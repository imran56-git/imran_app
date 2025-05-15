const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

// Firestore-triggered Cloud Function to send FCM notification
exports.sendNotification = functions.firestore
  .document("messages/{messageId}")
  .onCreate(async (snap, context) => {
    const messageData = snap.data();

    const receiverToken = messageData.receiverToken;
    const messageText = messageData.text || "You received a new message";
    const senderName = messageData.senderName || "Someone";

    const payload = {
      notification: {
        title: `Message from ${senderName}`,
        body: messageText,
      },
      token: receiverToken,
    };

    try {
      const response = await admin.messaging().send(payload);
      console.log("Notification sent successfully:", response);
      return null;
    } catch (error) {
      console.error("Error sending notification:", error);
      return null;
    }
  });