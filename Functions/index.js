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

    // Check if token exists before sending
    if (!receiverToken) {
      console.log("No receiver token found, skipping...");
      return null;
    }

    const message = {
      notification: {
        title: `Message from ${senderName}`,
        body: messageText,
      },
      token: receiverToken,
    };

    try {
      // Corrected method for v1 API
      const response = await admin.messaging().send(message);
      console.log("Notification sent successfully:", response);
      return null;
    } catch (error) {
      console.error("Error sending notification:", error);
      return null;
    }
  });
