/**
 * 語音處理函數
 * 
 * 當 voiceProcessing 文檔被建立時觸發
 * 負責呼叫 Zeabur API 進行語音辨識和解析
 * 並將結果寫入 Firestore
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import axios from "axios";

// Zeabur API 端點（需要在 Firebase 環境變數中設定）
// 優先從環境變數 (.env) 讀取，這是新版 Firebase Functions 的標準做法
const ZEABUR_API_URL = process.env.ZEABUR_API_URL || "http://localhost:8000";

/**
 * 語音處理結果介面
 */
interface VoiceProcessingResult {
  transcription: string;  // 語音轉文字結果
  title: string;          // 行程標題
  startTime: string;      // 開始時間（ISO 8601）
  endTime: string;        // 結束時間（ISO 8601）
  location?: string;      // 地點
  description?: string;   // 描述
  isAllDay?: boolean;     // 是否全天
  participants?: string[]; // 參與者
}

/**
 * 處理語音輸入的 Cloud Function
 * 
 * 監聽：voiceProcessing/{processId} 文檔建立
 * 觸發：自動執行語音處理流程
 */
export const processVoiceInput = functions.firestore
  .document("voiceProcessing/{processId}")
  .onCreate(async (snap, context) => {
    const processId = context.params.processId;
    const data = snap.data();

    // 取得必要資訊
    const {audioUrl, userId} = data;

    // 記錄開始處理
    console.log(`[Voice Processing] 開始處理語音：${processId}`);
    console.log(`  用戶ID: ${userId}`);
    console.log(`  音檔URL: ${audioUrl}`);

    try {
      // 1. 更新狀態為處理中
      await snap.ref.update({
        status: "processing",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // 2. 呼叫 Zeabur API 進行語音處理
      console.log("[Voice Processing] 呼叫 Zeabur API...");

      const response = await axios.post<VoiceProcessingResult>(
        `${ZEABUR_API_URL}/api/voice/parse`,
        {
          audioUrl,
          userId,
        },
        {
          timeout: 60000, // 60 秒超時
          headers: {
            "Content-Type": "application/json",
          },
        }
      );

      const result = response.data;
      console.log("[Voice Processing] API 回應成功");
      console.log(`  轉錄文字: ${result.transcription}`);
      console.log(`  行程標題: ${result.title}`);

      // 3. 建立行程文檔
      console.log("[Voice Processing] 建立行程...");

      const eventRef = await admin.firestore().collection("events").add({
        userId,
        title: result.title,
        startTime: admin.firestore.Timestamp.fromDate(new Date(result.startTime)),
        endTime: admin.firestore.Timestamp.fromDate(new Date(result.endTime)),
        location: result.location || null,
        description: result.description || null,
        participants: result.participants || [],
        reminderMinutes: 15, // 預設提醒時間
        isAllDay: result.isAllDay || false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        metadata: {
          createdBy: "voice",
          originalVoiceText: result.transcription,
          voiceFileUrl: audioUrl,
        },
      });

      console.log(`[Voice Processing] 行程建立成功：${eventRef.id}`);

      // 4. 更新處理記錄為完成
      await snap.ref.update({
        status: "completed",
        result: {
          title: result.title,
          startTime: result.startTime,
          endTime: result.endTime,
          location: result.location,
          description: result.description,
          isAllDay: result.isAllDay,
          participants: result.participants,
        },
        transcription: result.transcription,
        eventId: eventRef.id,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log("[Voice Processing] 處理完成");
    } catch (error: any) {
      // 錯誤處理
      console.error("[Voice Processing] 處理失敗:", error);

      let errorMessage = "未知錯誤";

      if (axios.isAxiosError(error)) {
        if (error.response) {
          // API 回傳錯誤
          errorMessage = `API 錯誤：${error.response.status} - ${
            error.response.data?.message || error.message
          }`;
        } else if (error.request) {
          // 請求發送但沒有回應
          errorMessage = "API 無回應，請檢查網路連線";
        } else {
          // 請求設定錯誤
          errorMessage = `請求錯誤：${error.message}`;
        }
      } else if (error instanceof Error) {
        errorMessage = error.message;
      }

      // 更新處理記錄為失敗
      await snap.ref.update({
        status: "failed",
        errorMessage,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.error(`[Voice Processing] 錯誤訊息：${errorMessage}`);
    }
  });

