"""
語音處理 API 路由
"""

from fastapi import APIRouter, HTTPException
from loguru import logger

from app.models.schemas import (
    VoiceParseRequest,
    VoiceParseResponse,
    ErrorResponse
)
from app.services.whisper_service import WhisperService
from app.services.gpt_service import GPTService
from app.services.nlp_service import NLPService

# 建立路由器
router = APIRouter()

# 初始化服務
whisper_service = WhisperService()
gpt_service = GPTService()
nlp_service = NLPService()

@router.post(
    "/parse",
    response_model=VoiceParseResponse,
    summary="解析語音檔案",
    description="接收語音檔案 URL，進行語音辨識和語意解析，回傳結構化的行程資料"
)
async def parse_voice(request: VoiceParseRequest):
    """
    語音解析主端點
    
    流程：
    1. 從 URL 下載語音檔案
    2. 使用 Whisper API 進行語音辨識
    3. 使用 GPT API 進行語意解析
    4. 使用 NLP 工具增強辨識準確性
    5. 回傳結構化的行程資料
    
    Args:
        request: 包含 audioUrl 和 userId 的請求
    
    Returns:
        VoiceParseResponse: 解析結果
    
    Raises:
        HTTPException: 處理失敗時拋出 HTTP 錯誤
    """
    try:
        logger.info(f"收到語音解析請求 - 用戶ID: {request.userId}")
        
        # 1. 語音轉文字（Whisper）
        logger.info("步驟 1/3：語音辨識...")
        transcription = await whisper_service.transcribe_from_url(request.audioUrl)
        
        if not transcription or not transcription.strip():
            raise HTTPException(
                status_code=400,
                detail="語音辨識失敗：無法識別語音內容"
            )
        
        logger.info(f"✅ 語音辨識完成：{transcription}")
        
        # 2. 語意解析（GPT）
        logger.info("步驟 2/3：語意解析...")
        # 將標籤列表轉換為字典格式傳給 GPT
        labels_dict = None
        if request.labels:
            labels_dict = [{"id": label.id, "name": label.name} for label in request.labels]
            logger.info(f"使用標籤列表進行推斷：{labels_dict}")
        event_data = gpt_service.parse_event_from_text(transcription, labels=labels_dict)
        logger.info(f"✅ 語意解析完成：{event_data}")
        
        # 3. NLP 增強
        logger.info("步驟 3/3：NLP 增強...")
        event_data = nlp_service.extract_entities(event_data, transcription)
        logger.info(f"✅ NLP 增強完成：{event_data}")
        
        # 組合最終回應
        response = VoiceParseResponse(
            transcription=transcription,
            title=event_data["title"],
            startTime=event_data["startTime"],
            endTime=event_data["endTime"],
            location=event_data.get("location"),
            description=event_data.get("description"),
            isAllDay=event_data.get("isAllDay", False),
            participants=event_data.get("participants", []),
            labelId=event_data.get("labelId")
        )
        
        logger.info("✅ 語音解析完成")
        return response
        
    except HTTPException:
        # 重新拋出 HTTPException
        raise
    
    except Exception as e:
        logger.error(f"❌ 語音解析失敗：{e}")
        raise HTTPException(
            status_code=500,
            detail=f"語音解析失敗：{str(e)}"
        )

@router.get(
    "/test",
    summary="測試端點",
    description="測試 API 是否正常運作"
)
async def test():
    """測試端點"""
    return {
        "status": "ok",
        "message": "Voice API is running",
        "services": {
            "whisper": "OpenAI Whisper API",
            "gpt": "OpenAI GPT-4",
            "nlp": "spaCy + dateparser"
        }
    }

