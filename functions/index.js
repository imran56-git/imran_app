const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

const MONTH_NAMES = [
  "January", "February", "March", "April", "May", "June",
  "July", "August", "September", "October", "November", "December"
];

/**
 * Helper: Fetch receiver's FCM token from users, teachers, or students collection
 */
async function getReceiverFcmToken(receiverId) {
  if (!receiverId) return null;
  const collections = ["users", "teachers", "students"];
  for (const col of collections) {
    try {
      const doc = await db.collection(col).doc(receiverId).get();
      if (doc.exists) {
        const data = doc.data() || {};
        const token = (data.fcmToken || data.deviceToken || "").toString().trim();
        if (token.length > 0) return token;
      }
    } catch (_) {}
  }
  return null;
}

/**
 * 1. Instant Push Notification Trigger (Chats, Groups, Official Reminders)
 */
exports.sendPushNotificationOnCreate = onDocumentCreated(
  {
    document: "notifications/{notificationId}",
    region: "asia-south1",
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const data = snap.data() || {};
    if (data.status === "sent") return;

    const receiverId = (data.receiverId || "").toString().trim();
    const title = (data.title || "FYBTT Notification").toString();
    const body = (data.body || "You have a new update").toString();
    const type = (data.type || "general").toString();
    const chatId = (data.chatId || "").toString();
    const groupId = (data.groupId || "").toString();

    if (!receiverId) {
      await snap.ref.update({ status: "skipped_no_receiver" }).catch(() => {});
      return;
    }

    const token = await getReceiverFcmToken(receiverId);
    if (!token) {
      await snap.ref.update({ status: "skipped_no_token" }).catch(() => {});
      return;
    }

    const message = {
      token: token,
      notification: {
        title: title,
        body: body,
      },
      data: {
        type: type,
        chatId: chatId,
        groupId: groupId,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      android: {
        priority: "high",
        notification: {
          sound: "default",
          channelId: "high_importance_channel",
        },
      },
    };

    try {
      const response = await admin.messaging().send(message);
      await snap.ref.update({
        status: "sent",
        fcmMessageId: response,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
      }).catch(() => {});
    } catch (error) {
      console.error("FCM Push Error:", error);
      await snap.ref.update({
        status: "failed",
        errorMessage: error.message || "Unknown FCM error",
      }).catch(() => {});
    }
  }
);

/**
 * Helper: Calculates exact next monthly run timestamp in IST (UTC+5:30)
 */
function calculateNextMonthlyRun(currentRunDate, dayOfMonth, hour, minute) {
  const istOffsetMs = 5.5 * 60 * 60 * 1000;
  const istNow = new Date(currentRunDate.getTime() + istOffsetMs);

  let nextYear = istNow.getUTCFullYear();
  let nextMonth = istNow.getUTCMonth() + 1;
  if (nextMonth > 11) {
    nextMonth = 0;
    nextYear += 1;
  }

  const maxDaysInNextMonth = new Date(Date.UTC(nextYear, nextMonth + 1, 0)).getUTCDate();
  const safeDay = Math.min(dayOfMonth, maxDaysInNextMonth);

  const nextIstUtcMs = Date.UTC(nextYear, nextMonth, safeDay, hour, minute, 0, 0) - istOffsetMs;
  return {
    nextDate: new Date(nextIstUtcMs),
    nextMonthName: MONTH_NAMES[nextMonth],
    formattedDueDate: `${String(safeDay).padStart(2, "0")}/${String(nextMonth + 1).padStart(2, "0")}/${nextYear}`,
  };
}

function formatTime12Hour(hour, minute) {
  const period = hour >= 12 ? "PM" : "AM";
  const h12 = hour % 12 === 0 ? 12 : hour % 12;
  const mStr = String(minute).padStart(2, "0");
  return `${h12}:${mStr} ${period}`;
}

/**
 * 2. Exact-Minute Scheduled Fee Reminders & Automatic Tuition Diary Sync
 */
exports.processScheduledFeeReminders = onSchedule(
  {
    schedule: "* * * * *", // Runs every single minute at :00 seconds
    timeZone: "Asia/Kolkata",
    region: "asia-south1",
  },
  async () => {
    const now = admin.firestore.Timestamp.now();

    const dueRemindersSnap = await db
      .collection("fee_reminders")
      .where("isActive", "==", true)
      .where("nextRunAt", "<=", now)
      .limit(50)
      .get();

    if (dueRemindersSnap.empty) {
      return;
    }

    for (const reminderDoc of dueRemindersSnap.docs) {
      const data = reminderDoc.data();
      const teacherId = (data.teacherId || "").trim();
      const teacherName = (data.teacherName || "Your Teacher").trim();
      const studentId = (data.studentId || "").trim();
      const studentName = (data.studentName || "Student").trim();
      const amount = Number(data.amount || 0);
      const dayOfMonth = Number(data.dayOfMonth || 15);
      const hour = Number(data.hour ?? 16);
      const minute = Number(data.minute ?? 0);
      const isRecurring = data.isRecurring !== false;

      if (!teacherId || !studentId || amount <= 0) {
        await reminderDoc.ref.update({ isActive: false });
        continue;
      }

      const currentRunDate = data.nextRunAt.toDate();
      const istRunDate = new Date(currentRunDate.getTime() + 5.5 * 60 * 60 * 1000);
      const monthName = data.monthName || MONTH_NAMES[istRunDate.getUTCMonth()];
      const dueDateStr =
        data.dueDateText ||
        `${String(istRunDate.getUTCDate()).padStart(2, "0")}/${String(
          istRunDate.getUTCMonth() + 1
        ).padStart(2, "0")}/${istRunDate.getUTCFullYear()}`;
      const timeStr = formatTime12Hour(hour, minute);

      // Official Channel Message (Exact Preview Format)
      const officialMessageText =
        `Hello ${studentName},\n\n` +
        `This is an official tuition fee reminder on behalf of ${teacherName}. ` +
        `Tuition fee for ${monthName} is due.\n\n` +
        `Amount: ₹${amount}\n` +
        `Due Date: ${dueDateStr}\n` +
        `Scheduled Transmission: ${timeStr}\n\n` +
        `Please complete the payment promptly.\n` +
        `Thank you,\n` +
        `FYBTT Official Desk`;

      const officialChatId = `official_desk_${studentId}`;
      const officialChatRef = db.collection("chats").doc(officialChatId);
      const msgRef = officialChatRef.collection("messages").doc();

      const batch = db.batch();

      // Send message inside FYBTT official channel (NOT teacher's personal chat)
      batch.set(msgRef, {
        messageId: msgRef.id,
        senderId: "OFFICIAL_FYBTT_DESK",
        receiverId: studentId,
        content: officialMessageText,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        type: "text",
        status: "sent",
        isDeletedForEveryone: false,
        deletedForUsers: [],
        starredBy: [],
        reactions: {},
        messageCategory: "fee_reminder",
        isOfficial: true,
      });

      batch.set(
        officialChatRef,
        {
          chatId: officialChatId,
          participants: [studentId],
          isGroup: false,
          isOfficial: true,
          lastMessage: `Fee Reminder: ₹${amount} due for ${monthName}`,
          lastMessageContent: `Fee Reminder: ₹${amount} due for ${monthName}`,
          lastMessageTime: admin.firestore.FieldValue.serverTimestamp(),
          lastSenderId: "OFFICIAL_FYBTT_DESK",
          [`unreadCount_${studentId}`]: admin.firestore.FieldValue.increment(1),
          unreadCount: admin.firestore.FieldValue.increment(1),
          unreadFor: studentId,
          deletedBy: admin.firestore.FieldValue.arrayRemove(studentId),
        },
        { merge: true }
      );

      // Trigger Push Notification for Student (picked up immediately by sendPushNotificationOnCreate)
      const studentNotifRef = db.collection("notifications").doc();
      batch.set(studentNotifRef, {
        notificationId: studentNotifRef.id,
        senderId: "OFFICIAL_FYBTT_DESK",
        receiverId: studentId,
        chatId: officialChatId,
        title: "FYBTT Official • Fee Reminder",
        body: `Tuition fee of ₹${amount} for ${monthName} is due (${dueDateStr}).`,
        type: "official_fee_reminder",
        isRead: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        status: "pending",
      });

      // Ecosystem Sync: Auto-add Pending Due to Teacher's Tuition Diary if Diary exists
      const diaryQuery = await db
        .collection("student_fees")
        .where("teacherId", "==", teacherId)
        .where("studentId", "==", studentId)
        .limit(1)
        .get();

      let diaryUpdated = false;
      if (!diaryQuery.empty) {
        const diaryDoc = diaryQuery.docs[0];
        const ledgerRef = diaryDoc.ref.collection("fee_entries").doc();
        batch.set(ledgerRef, {
          entryId: ledgerRef.id,
          month: monthName,
          dueDate: dueDateStr,
          amount: amount,
          status: "pending",
          source: "auto_fee_reminder",
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        batch.update(diaryDoc.ref, {
          totalDue: admin.firestore.FieldValue.increment(amount),
          lastReminderMonth: monthName,
          lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
        });
        diaryUpdated = true;
      }

      // Confirmation Notification to Teacher
      const teacherNotifRef = db.collection("notifications").doc();
      batch.set(teacherNotifRef, {
        notificationId: teacherNotifRef.id,
        senderId: "OFFICIAL_FYBTT_DESK",
        receiverId: teacherId,
        title: "Fee Reminder Sent",
        body: diaryUpdated
          ? `Official fee reminder (₹${amount}) sent to ${studentName} & added to Diary pending dues.`
          : `Official fee reminder (₹${amount}) sent to ${studentName}.`,
        type: "fee_reminder_confirmation",
        isRead: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        status: "pending",
      });

      // Schedule Next Month Automatically (or deactivate if one-time)
      if (isRecurring) {
        const nextSchedule = calculateNextMonthlyRun(
          currentRunDate,
          dayOfMonth,
          hour,
          minute
        );
        batch.update(reminderDoc.ref, {
          lastSentAt: admin.firestore.FieldValue.serverTimestamp(),
          nextRunAt: admin.firestore.Timestamp.fromDate(nextSchedule.nextDate),
          monthName: nextSchedule.nextMonthName,
          dueDateText: nextSchedule.formattedDueDate,
        });
      } else {
        batch.update(reminderDoc.ref, {
          lastSentAt: admin.firestore.FieldValue.serverTimestamp(),
          isActive: false,
        });
      }

      await batch.commit();
    }
  }
);
