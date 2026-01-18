"""
節日資料模型

定義節日相關的 Pydantic 模型
"""

from pydantic import BaseModel
from typing import List, Optional
from enum import Enum


class HolidayType(str, Enum):
    """節日類型"""
    national = "national"           # 國定假日（放假）
    traditional = "traditional"     # 傳統節日
    memorial = "memorial"           # 紀念日
    international = "international" # 國際節日


class Holiday(BaseModel):
    """單一節日資料"""
    name: str                       # 節日名稱
    date: str                       # YYYY-MM-DD 格式
    type: HolidayType               # 節日類型
    is_off_day: bool                # 是否放假
    lunar_date: Optional[str] = None  # 農曆日期（顯示用，如「正月初一」）

    class Config:
        use_enum_values = True


class HolidaysResponse(BaseModel):
    """節日 API 回應"""
    year: int                       # 年份
    region: str                     # 地區（如 taiwan）
    holidays: List[Holiday]         # 節日列表
    generated_at: str               # 產生時間（ISO 8601）


class HolidaysRequest(BaseModel):
    """節日 API 請求（可選參數）"""
    region: str = "taiwan"          # 地區，預設台灣
