/**
 * Firebase Cloud Functions for AI Calendar App
 * 
 * 主要功能：
 * 1. 監聽 voiceProcessing 文檔建立，觸發語音處理
 * 2. 呼叫 Zeabur API 進行語音辨識和解析
 * 3. 將解析結果寫入 Firestore events collection
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

// 初始化 Firebase Admin SDK
admin.initializeApp();

// 匯出語音處理函數
export {processVoiceInput} from "./voiceHandler";
export {scheduleEventReminders} from "./notificationHandler";

