const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

const REGION = "asia-south1";

/**
 * 1. 🚀 Notification Document Creation Trigger (Manual / Admin / Teacher Push)
 * Triggers automatically whenever a new notification is published in Firestore.
 */
exports.sendAutomatedNotification = functions
  .region(REGION)
  .firestore
  .document("schools/{schoolId}/notifications/{notificationId}")
  .onCreate(async (snapshot, context) => {
    const data = snapshot.data();
    if (!data) return null;

    const title = data.title || "School Notification";
    const body = data.body || "";
    const category = data.category || "General";
    const targetFcmTokens = data.targetFcmTokens || [];

    const validTokens = targetFcmTokens.filter(
      (token) => token && token !== "not shared" && token.trim().length > 10
    );

    if (validTokens.length === 0) {
      console.log("No valid FCM tokens for notification:", context.params.notificationId);
      return null;
    }

    const messagePayload = {
      tokens: validTokens,
      notification: { title, body },
      data: {
        notificationId: data.id || context.params.notificationId,
        category: category,
        senderName: data.senderName || "Admin",
        senderRole: data.senderRole || "Admin",
        createdAt: data.createdAt ? data.createdAt.toString() : new Date().toISOString(),
      },
      android: {
        priority: "high",
        notification: { sound: "default", channelId: "school_notifications", clickAction: "FLUTTER_NOTIFICATION_CLICK" },
      },
      apns: { payload: { aps: { sound: "default", badge: 1 } } },
      webpush: { notification: { icon: "/favicon.png" } },
    };

    try {
      const response = await admin.messaging().sendEachForMulticast(messagePayload);
      console.log(`Sent ${response.successCount} FCM push messages; ${response.failureCount} failed.`);
      return response;
    } catch (error) {
      console.error("Error dispatching FCM payload:", error);
      return null;
    }
  });

/**
 * 2. 📝 Automated Attendance Marked Alert to Parents
 * Fires when attendance is marked/updated for a class.
 */
exports.onAttendanceMarked = functions
  .region(REGION)
  .firestore
  .document("schools/{schoolId}/attendance/{dateId}")
  .onWrite(async (change, context) => {
    const newData = change.after.exists ? change.after.data() : null;
    if (!newData) return null;

    const schoolId = context.params.schoolId;

    try {
      for (const classKey of Object.keys(newData)) {
        const divisionsObj = newData[classKey];
        if (!divisionsObj || typeof divisionsObj !== "object") continue;

        for (const divKey of Object.keys(divisionsObj)) {
          const studentList = divisionsObj[divKey];
          if (!Array.isArray(studentList)) continue;

          for (const studentAtt of studentList) {
            const studentId = studentAtt.studentId;
            const status = studentAtt.status || studentAtt.isPresent;
            const isAbsent = status === false || status === "Absent" || status === "absent";
            const statusText = isAbsent ? "ABSENT" : "PRESENT";

            if (studentId) {
              const devicesSnap = await admin
                .firestore()
                .collection("schools")
                .doc(schoolId)
                .collection("students")
                .doc(studentId)
                .collection("devices")
                .where("isActive", "==", true)
                .get();

              const parentTokens = [];
              devicesSnap.forEach((doc) => {
                const token = doc.data().fcmToken;
                if (token && token.trim().length > 10) parentTokens.push(token.trim());
              });

              if (parentTokens.length > 0) {
                const payload = {
                  tokens: parentTokens,
                  notification: {
                    title: `Attendance Update: ${studentAtt.studentName || "Student"}`,
                    body: `Your ward ${studentAtt.studentName || "Student"} is marked ${statusText} for today.`,
                  },
                  data: { category: "Attendance", studentId: studentId },
                  android: { priority: "high", notification: { sound: "default" } },
                };
                await admin.messaging().sendEachForMulticast(payload);
              }
            }
          }
        }
      }
    } catch (err) {
      console.error("Error sending automated parent attendance alert:", err);
    }
    return null;
  });

/**
 * 3. 💰 Automated Fee Added Alert to Targeted Parents/Students
 * Fires when a new fee entry is added in Firestore.
 */
exports.onFeeAdded = functions
  .region(REGION)
  .firestore
  .document("schools/{schoolId}/fees/{feeId}")
  .onCreate(async (snapshot, context) => {
    const feeData = snapshot.data();
    if (!feeData) return null;

    const schoolId = context.params.schoolId;
    const title = `Fee Alert: ${feeData.feeType || feeData.title || "New Fee Assigned"}`;
    const amount = feeData.amount || feeData.totalAmount || "0";
    const body = `Fee of Rs. ${amount} has been added for ${feeData.studentName || feeData.targetClass || "your account"}. Due date: ${feeData.dueDate || "As specified"}.`;

    try {
      let targetStudentIds = feeData.targetStudentIds || [];
      if (feeData.studentId) targetStudentIds.push(feeData.studentId);

      const recipientTokens = new Set();

      for (const studentId of targetStudentIds) {
        const devicesSnap = await admin
          .firestore()
          .collection("schools")
          .doc(schoolId)
          .collection("students")
          .doc(studentId)
          .collection("devices")
          .where("isActive", "==", true)
          .get();

        devicesSnap.forEach((doc) => {
          const t = doc.data().fcmToken;
          if (t && t.trim().length > 10) recipientTokens.add(t.trim());
        });
      }

      const tokensList = Array.from(recipientTokens);
      if (tokensList.length > 0) {
        const payload = {
          tokens: tokensList,
          notification: { title, body },
          data: { category: "Fee", feeId: context.params.feeId },
          android: { priority: "high", notification: { sound: "default" } },
        };
        await admin.messaging().sendEachForMulticast(payload);
      }
    } catch (err) {
      console.error("Error sending automated fee push notification:", err);
    }
    return null;
  });

/**
 * 4. ⏰ Scheduled Attendance Unmarked Reminder to Class Teachers
 * Runs 15 minutes before marking deadlines (10:15 AM & 2:15 PM IST).
 * Windows: 9:00 AM - 10:30 AM (Reminder at 10:15 AM) & 1:30 PM - 2:30 PM (Reminder at 2:15 PM)
 */
exports.attendanceUnmarkedReminderCron = functions
  .region(REGION)
  .pubsub
  .schedule("15 10,14 * * 1-6")
  .timeZone("Asia/Kolkata")
  .onRun(async (context) => {
    const now = new Date();
    const dayStr = String(now.getDate()).padStart(2, "0");
    const monthStr = String(now.getMonth() + 1).padStart(2, "0");
    const dateId = ` ${dayStr}-${monthStr}-${now.getFullYear()}`;

    try {
      const schoolsSnap = await admin.firestore().collection("schools").get();

      for (const schoolDoc of schoolsSnap.docs) {
        const schoolId = schoolDoc.id;

        const attDocSnap = await admin
          .firestore()
          .collection("schools")
          .doc(schoolId)
          .collection("attendance")
          .doc(dateId)
          .get();

        const attendanceData = attDocSnap.exists ? attDocSnap.data() : {};

        const teachersSnap = await admin
          .firestore()
          .collection("schools")
          .doc(schoolId)
          .collection("teachers")
          .where("delete", "==", false)
          .get();

        for (const teacherDoc of teachersSnap.docs) {
          const teacher = teacherDoc.data();
          const classNo = (teacher.classNo || "").toString();
          const division = (teacher.division || "").toString().toUpperCase();

          if (!classNo || division === "NIL" || division === "NONE") continue;

          const classDivData = attendanceData[classNo]?.[division];
          const isMarked = Array.isArray(classDivData) && classDivData.length > 0;

          if (!isMarked) {
            const teacherDevicesSnap = await teacherDoc.ref
              .collection("devices")
              .where("isActive", "==", true)
              .get();

            const teacherTokens = [];
            teacherDevicesSnap.forEach((doc) => {
              const t = doc.data().fcmToken;
              if (t && t.trim().length > 10) teacherTokens.push(t.trim());
            });

            if (teacherTokens.length > 0) {
              const reminderPayload = {
                tokens: teacherTokens,
                notification: {
                  title: "⏰ Attendance Marking Deadline Reminder",
                  body: `Attendance for Class ${classNo}${division} is not marked yet. Marking window closes in 15 minutes!`,
                },
                data: {
                  category: "AttendanceReminder",
                  classNo: classNo,
                  division: division,
                },
                android: { priority: "high", notification: { sound: "default" } },
              };
              await admin.messaging().sendEachForMulticast(reminderPayload);
            }
          }
        }
      }
    } catch (err) {
      console.error("Error executing attendance unmarked cron reminder:", err);
    }
    return null;
  });
