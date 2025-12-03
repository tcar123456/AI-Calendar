"use strict";
/**
 * Firebase Cloud Functions for AI Calendar App
 *
 * 主要功能：
 * 1. 監聽 voiceProcessing 文檔建立，觸發語音處理
 * 2. 呼叫 Zeabur API 進行語音辨識和解析
 * 3. 將解析結果寫入 Firestore events collection
 */
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || function (mod) {
    if (mod && mod.__esModule) return mod;
    var result = {};
    if (mod != null) for (var k in mod) if (k !== "default" && Object.prototype.hasOwnProperty.call(mod, k)) __createBinding(result, mod, k);
    __setModuleDefault(result, mod);
    return result;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.scheduleEventReminders = exports.processVoiceInput = void 0;
const admin = __importStar(require("firebase-admin"));
// 初始化 Firebase Admin SDK
admin.initializeApp();
// 匯出語音處理函數
var voiceHandler_1 = require("./voiceHandler");
Object.defineProperty(exports, "processVoiceInput", { enumerable: true, get: function () { return voiceHandler_1.processVoiceInput; } });
var notificationHandler_1 = require("./notificationHandler");
Object.defineProperty(exports, "scheduleEventReminders", { enumerable: true, get: function () { return notificationHandler_1.scheduleEventReminders; } });
//# sourceMappingURL=index.js.map