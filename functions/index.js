const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

const MONTH_NAMES = [
  "January", "February", "March", "April", "May", "June",
  "July", "August", "September", "October", "November", "December",
];

const OFFICIAL_SENDER_ID = "OFFICIAL_FYBTT_DESK";
const IST_OFFSET_MS = 5.5 * 60 * 60 * 1000;

/**
 * Creates a baseline 12-month ledger with default "not_enrolled" status
 */
function createDefaultMonthlyStatus() {
  const statusMap = {};
  for (const month of MONTH_NAMES) {
    statusMap[month] = "not_enrolled";
  }
  return statusMap;
}

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
 * Ensures the next run is strictly in the future to avoid backlog spam loops.
 */
function calculateNextMonthlyRun(currentRunDate, dayOfMonth, hour, minute) {
  const nowMs = Date.now();
  const baseDate = currentRunDate.getTime() > nowMs ? currentRunDate : new Date(nowMs);
  const istNow = new Date(baseDate.getTime() + IST_OFFSET_MS);

  let nextYear = istNow.getUTCFullYear();
  let nextMonth = istNow.getUTCMonth() + 1;
  if (nextMonth > 11) {
    nextMonth = 0;
    nextYear += 1;
  }

  const maxDaysInNextMonth = new Date(Date.UTC(nextYear, nextMonth + 1, 0)).getUTCDate();
  const safeDay = Math.min(Math.max(1, dayOfMonth), maxDaysInNextMonth);
  const nextIstUtcMs = Date.UTC(nextYear, nextMonth, safeDay, hour, minute, 0, 0) - IST_OFFSET_MS;

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
 * Helper: Normalizes month input (e.g. "november", "Nov", "November") to full Title Case month name
 */
function normalizeMonthName(rawMonth, fallbackDate) {
  const cleaned = (rawMonth || "").toString().trim().toLowerCase();
  if (cleaned) {
    const exact = MONTH_NAMES.find((m) => m.toLowerCase() === cleaned);
    if (exact) return exact;
    const prefix = MONTH_NAMES.find((m) => m.toLowerCase().startsWith(cleaned.slice(0, 3)));
    if (prefix && cleaned.length >= 3) return prefix;
  }
  const istDate = new Date(fallbackDate.getTime() + IST_OFFSET_MS);
  return MONTH_NAMES[istDate.getUTCMonth()];
}

/**
 * Helper: Calculates ledger totals strictly from the monthly status map
 */
function computeLedgerSummary(statusMap, unitFee) {
  let dueMonthsCount = 0;
  let paidMonthsCount = 0;
  let notEnrolledCount = 0;

  for (const rawStatus of Object.values(statusMap || {})) {
    const normalized = (rawStatus || "").toString().trim().toLowerCase();
    if (normalized === "due" || normalized === "pending") {
      dueMonthsCount += 1;
    } else if (normalized === "paid") {
      paidMonthsCount += 1;
    } else {
      notEnrolledCount += 1;
    }
  }

  const safeUnitFee = Number.isFinite(unitFee) && unitFee > 0 ? unitFee : 0;

  return {
    dueMonths: dueMonthsCount,
    dueMonthsCount: dueMonthsCount,
    paidMonths: paidMonthsCount,
    paidMonthsCount: paidMonthsCount,
    notEnrolledCount: notEnrolledCount,
    totalDue: dueMonthsCount * safeUnitFee,
    totalCollected: paidMonthsCount * safeUnitFee,
  };
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
      try {
        const data = reminderDoc.data() || {};
        const teacherId = (data.teacherId || "").toString().trim();
        const teacherName = (data.teacherName || "Your Teacher").toString().trim();
        const studentId = (data.studentId || "").toString().trim();
        const studentName = (data.studentName || "Student").toString().trim();
        const amount = Number(data.amount || 0);
        const dayOfMonth = Number(data.dayOfMonth || 15);
        const hour = Number(data.hour ?? 16);
        const minute = Number(data.minute ?? 0);
        const isRecurring = data.isRecurring !== false;

        if (
          !teacherId ||
          !studentId ||
          !Number.isFinite(amount) ||
          amount <= 0 ||
          !data.nextRunAt ||
          typeof data.nextRunAt.toDate !== "function"
        ) {
          await reminderDoc.ref.update({ isActive: false }).catch(() => {});
          continue;
        }

        const currentRunDate = data.nextRunAt.toDate();
        const istRunDate = new Date(currentRunDate.getTime() + IST_OFFSET_MS);
        const targetYear = istRunDate.getUTCFullYear();
        const monthName = normalizeMonthName(data.monthName, currentRunDate);
        const dueDateStr =
          data.dueDateText ||
          `${String(istRunDate.getUTCDate()).padStart(2, "0")}/${String(
            istRunDate.getUTCMonth() + 1
          ).padStart(2, "0")}/${targetYear}`;
        const timeStr = formatTime12Hour(hour, minute);

        // Official Channel Message Format
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

        // Send message inside FYBTT official channel (isolated from personal chats)
        batch.set(msgRef, {
          messageId: msgRef.id,
          senderId: OFFICIAL_SENDER_ID,
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
            participants: [studentId, OFFICIAL_SENDER_ID],
            isGroup: false,
            isOfficial: true,
            chatCategory: "official_fees",
            lastMessage: `Fee Reminder: ₹${amount} due for ${monthName}`,
            lastMessageContent: `Fee Reminder: ₹${amount} due for ${monthName}`,
            lastMessageTime: admin.firestore.FieldValue.serverTimestamp(),
            lastSenderId: OFFICIAL_SENDER_ID,
            [`unreadCount_${studentId}`]: admin.firestore.FieldValue.increment(1),
            unreadCount: admin.firestore.FieldValue.increment(1),
            unreadFor: studentId,
            deletedBy: admin.firestore.FieldValue.arrayRemove(studentId),
          },
          { merge: true }
        );

        // Trigger Push Notification for Student
        const studentNotifRef = db.collection("notifications").doc();
        batch.set(studentNotifRef, {
          notificationId: studentNotifRef.id,
          senderId: OFFICIAL_SENDER_ID,
          receiverId: studentId,
          chatId: officialChatId,
          title: "FYBTT Official • Fee Reminder",
          body: `Tuition fee of ₹${amount} for ${monthName} is due (${dueDateStr}).`,
          type: "official_fee_reminder",
          isRead: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          status: "pending",
        });

        // Ecosystem Sync: Find or create the student's student_fees document
        const diaryQuery = await db
          .collection("student_fees")
          .where("teacherId", "==", teacherId)
          .where("studentId", "==", studentId)
          .get();

        let diaryUpdated = false;
        let alreadyPaid = false;

        let diaryDocRef = null;
        let ledgerStatusMap = createDefaultMonthlyStatus();
        let unitFee = amount;

        if (!diaryQuery.empty) {
          const matchedDoc =
            diaryQuery.docs.find((d) => Number((d.data() || {}).year) === targetYear) ||
            diaryQuery.docs[0];
          diaryDocRef = matchedDoc.ref;
          const diaryData = matchedDoc.data() || {};

          // Reconcile unit fee
          unitFee = Number(
            diaryData.monthlyFee ?? diaryData.feeAmount ?? diaryData.monthlyAmount ?? amount
          );
          if (!Number.isFinite(unitFee) || unitFee <= 0) unitFee = amount;

          // Merge existing status map with full 12-month baseline
          const existingMap = diaryData.monthlyStatus || diaryData.monthlyStatuses || {};
          ledgerStatusMap = { ...ledgerStatusMap, ...existingMap };

          const currentMonthStatus = (ledgerStatusMap[monthName] || "")
            .toString()
            .trim()
            .toLowerCase();

          if (currentMonthStatus === "paid") {
            alreadyPaid = true;
          } else {
            ledgerStatusMap[monthName] = "due";
            diaryUpdated = true;
          }
        } else {
          // Initialize a brand new student_fees document if not existing
          diaryDocRef = db.collection("student_fees").doc();
          ledgerStatusMap[monthName] = "due";
          diaryUpdated = true;
        }

        if (diaryUpdated && !alreadyPaid) {
          const summary = computeLedgerSummary(ledgerStatusMap, unitFee);

          // Update main student_fees record
          batch.set(
            diaryDocRef,
            {
              teacherId: teacherId,
              teacherName: teacherName,
              studentId: studentId,
              studentName: studentName,
              year: targetYear,
              monthlyFee: unitFee,
              monthlyStatus: ledgerStatusMap,
              // Direct root-level month key for flat lookups
              [monthName]: "due",
              totalDue: summary.totalDue,
              totalCollected: summary.totalCollected,
              dueMonths: summary.dueMonths,
              dueMonthsCount: summary.dueMonthsCount,
              paidMonths: summary.paidMonths,
              paidMonthsCount: summary.paidMonthsCount,
              lastReminderMonth: monthName,
              lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true }
          );

          // Sync fee_entries subcollection entry
          const existingEntriesSnap = await diaryDocRef
            .collection("fee_entries")
            .where("month", "==", monthName)
            .limit(1)
            .get();

          if (!existingEntriesSnap.empty) {
            const entryDoc = existingEntriesSnap.docs[0];
            const currentEntryStatus = ((entryDoc.data() || {}).status || "")
              .toString()
              .trim()
              .toLowerCase();

            if (currentEntryStatus !== "paid") {
              batch.update(entryDoc.ref, {
                month: monthName,
                dueDate: dueDateStr,
                amount: unitFee,
                status: "due",
                source: "auto_fee_reminder",
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              });
            }
          } else {
            const newEntryRef = diaryDocRef.collection("fee_entries").doc();
            batch.set(newEntryRef, {
              entryId: newEntryRef.id,
              month: monthName,
              dueDate: dueDateStr,
              amount: unitFee,
              status: "due",
              source: "auto_fee_reminder",
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          }
        }

        // Confirmation Notification to Teacher
        const teacherNotifRef = db.collection("notifications").doc();
        batch.set(teacherNotifRef, {
          notificationId: teacherNotifRef.id,
          senderId: OFFICIAL_SENDER_ID,
          receiverId: teacherId,
          title: "Fee Reminder Sent",
          body: diaryUpdated
            ? `Official fee reminder (₹${amount}) sent to ${studentName} & ${monthName} marked Due in Diary.`
            : alreadyPaid
              ? `Official fee reminder (₹${amount}) sent to ${studentName} (${monthName} already Paid in Diary).`
              : `Official fee reminder (₹${amount}) sent to ${studentName}.`,
          type: "fee_reminder_confirmation",
          isRead: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          status: "pending",
        });

        // Reschedule for next monthly cycle or deactivate if non-recurring
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
      } catch (err) {
        console.error(`Error processing reminder ${reminderDoc.id}:`, err);
      }
    }
  }
);