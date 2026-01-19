"""
資料模型與 Schema 定義
"""

from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime

class LabelInfo(BaseModel):
    """標籤資訊"""
    id: str = Field(..., description="標籤 ID (例如 label_1)")
    name: str = Field(..., description="標籤名稱 (例如 工作)")


class VoiceParseRequest(BaseModel):
    """語音解析請求"""
    audioUrl: str = Field(..., description="語音檔案 URL")
    userId: str = Field(..., description="用戶 ID")
    labels: Optional[List[LabelInfo]] = Field(None, description="行事曆的標籤列表（用於 AI 自動選擇標籤）")

class EventResult(BaseModel):
    """行程解析結果"""
    title: str = Field(..., description="行程標題")
    startTime: str = Field(..., description="開始時間（ISO 8601 格式）")
    endTime: str = Field(..., description="結束時間（ISO 8601 格式）")
    location: Optional[str] = Field(None, description="地點")
    description: Optional[str] = Field(None, description="備註說明")
    isAllDay: bool = Field(False, description="是否全天行程")
    participants: List[str] = Field(default_factory=list, description="參與者列表")

class VoiceParseResponse(BaseModel):
    """語音解析回應"""
    transcription: str = Field(..., description="語音轉文字結果")
    title: str = Field(..., description="行程標題")
    startTime: str = Field(..., description="開始時間")
    endTime: str = Field(..., description="結束時間")
    location: Optional[str] = Field(None, description="地點")
    description: Optional[str] = Field(None, description="備註")
    isAllDay: bool = Field(False, description="是否全天")
    participants: List[str] = Field(default_factory=list, description="參與者")
    labelId: Optional[str] = Field(None, description="AI 推斷的標籤 ID")

    class Config:
        json_schema_extra = {
            "example": {
                "transcription": "明天下午兩點在公司會議室開會，記得帶筆電",
                "title": "公司會議",
                "startTime": "2025-10-02T14:00:00",
                "endTime": "2025-10-02T15:00:00",
                "location": "公司會議室",
                "description": "記得帶筆電",
                "isAllDay": False,
                "participants": [],
                "labelId": "label_6"
            }
        }

class ErrorResponse(BaseModel):
    """錯誤回應"""
    error: str = Field(..., description="錯誤訊息")
    detail: Optional[str] = Field(None, description="詳細說明")

