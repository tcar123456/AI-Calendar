/**
 * 推播通知處理函數
 * 
 * 處理行程提醒推播通知
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

/**
 * 排程行程提醒（示範函數）
 * 
 * 當新行程建立時觸發
 * 未來可以整合 Cloud Scheduler 或 Pub/Sub 來實現定時推播
 * 
 * 注意：這是簡化版本，實際應用中需要：
 * 1. 使用 Cloud Scheduler 排程定時任務
 * 2. 檢查用戶的 FCM Token
 * 3. 在提醒時間發送推播
 */
export const scheduleEventReminders = functions.firestore
  .document("events/{eventId}")
  .onCreate(async (snap, context) => {
    const event = snap.data();
    const eventId = context.params.eventId;

    console.log(`[Notification] 為行程排程提醒：${eventId}`);
    console.log(`  標題: ${event.title}`);
    console.log(`  開始時間: ${event.startTime.toDate()}`);
    console.log(`  提醒時間: ${event.reminderMinutes} 分鐘前`);

    // 取得用戶的 FCM Token
    const userDoc = await admin.firestore()
      .collection("users")
      .doc(event.userId)
      .get();

    if (!userDoc.exists) {
      console.log("[Notification] 找不到用戶");
      return;
    }

    const userData = userDoc.data();
    const fcmToken = userData?.fcmToken;

    if (!fcmToken) {
      console.log("[Notification] 用戶未設定 FCM Token");
      return;
    }

    // 計算提醒時間
    const eventStartTime = event.startTime.toDate();
    const reminderTime = new Date(
      eventStartTime.getTime() - (event.reminderMinutes * 60 * 1000)
    );

    console.log(`  提醒時間點: ${reminderTime}`);

    // TODO: 整合 Cloud Scheduler 或 Pub/Sub
    // 這裡是簡化版本，實際應該排程一個定時任務
    // 在 reminderTime 時刻發送推播

    // 示範：立即發送推播（實際應該在 reminderTime 發送）
    const now = new Date();
    if (reminderTime <= now) {
      // 如果提醒時間已經過了，立即發送
      await sendEventReminder(fcmToken, event, eventId);
    } else {
      console.log("[Notification] 提醒已排程（需要實作 Cloud Scheduler）");
      // TODO: 在這裡整合 Cloud Scheduler
      // await scheduleReminder(fcmToken, event, eventId, reminderTime);
    }
  });

/**
 * 發送行程提醒推播
 */
async function sendEventReminder(
  fcmToken: string,
  event: any,
  eventId: string
): Promise<void> {
  try {
    const message = {
      notification: {
        title: "行程提醒",
        body: `${event.title} 即將在 ${event.reminderMinutes} 分鐘後開始`,
      },
      data: {
        eventId,
        type: "event_reminder",
      },
      token: fcmToken,
    };

    const response = await admin.messaging().send(message);
    console.log(`[Notification] 推播發送成功：${response}`);
  } catch (error) {
    console.error("[Notification] 推播發送失敗:", error);
  }
}

/**
 * 發送測試推播（用於除錯）
 * 
 * HTTP 觸發函數，用於測試推播功能
 * 使用方式：
 * POST https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/sendTestNotification
 * Body: { "userId": "USER_ID", "message": "測試訊息" }
 */
export const sendTestNotification = functions.https.onRequest(async (req, res) => {
  // CORS 設定
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "POST");
  res.set("Access-Control-Allow-Headers", "Content-Type");

  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return;
  }

  if (req.method !== "POST") {
    res.status(405).send("Method Not Allowed");
    return;
  }

  const {userId, message} = req.body;

  if (!userId || !message) {
    res.status(400).json({error: "Missing userId or message"});
    return;
  }

  try {
    // 取得用戶的 FCM Token
    const userDoc = await admin.firestore()
      .collection("users")
      .doc(userId)
      .get();

    if (!userDoc.exists) {
      res.status(404).json({error: "User not found"});
      return;
    }

    const userData = userDoc.data();
    const fcmToken = userData?.fcmToken;

    if (!fcmToken) {
      res.status(400).json({error: "User has no FCM token"});
      return;
    }

    // 發送推播
    const response = await admin.messaging().send({
      notification: {
        title: "測試推播",
        body: message,
      },
      token: fcmToken,
    });

    res.status(200).json({
      success: true,
      response,
      message: "Notification sent successfully",
    });
  } catch (error: any) {
    console.error("Error sending notification:", error);
    res.status(500).json({
      error: "Failed to send notification",
      details: error.message,
    });
  }
});

