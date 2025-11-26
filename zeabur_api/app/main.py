"""
FastAPI 主應用程式

提供語音處理 API 端點
"""

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from loguru import logger
import os
from dotenv import load_dotenv

from app.routes import voice

# 載入環境變數
load_dotenv()

# 建立 FastAPI 應用程式
app = FastAPI(
    title="AI Calendar Voice API",
    description="語音辨識與行程解析服務",
    version="1.0.0",
)

# CORS 設定
app.add_middleware(
    CORSMiddleware,
    allow_origins=os.getenv("CORS_ORIGINS", "*").split(","),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 註冊路由
app.include_router(voice.router, prefix="/api/voice", tags=["語音處理"])

# 健康檢查端點
@app.get("/")
async def root():
    """根端點 - 健康檢查"""
    return {
        "message": "AI Calendar Voice API",
        "version": "1.0.0",
        "status": "running",
    }

@app.get("/health")
async def health_check():
    """健康檢查端點"""
    return {
        "status": "healthy",
        "service": "voice-api",
    }

# 啟動事件
@app.on_event("startup")
async def startup_event():
    """應用程式啟動時執行"""
    logger.info("🚀 AI Calendar Voice API 已啟動")
    
    # 檢查必要的環境變數
    openai_key = os.getenv("OPENAI_API_KEY")
    if not openai_key:
        logger.warning("⚠️ 未設定 OPENAI_API_KEY 環境變數")

# 關閉事件
@app.on_event("shutdown")
async def shutdown_event():
    """應用程式關閉時執行"""
    logger.info("👋 AI Calendar Voice API 已關閉")

