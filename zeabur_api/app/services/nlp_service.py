"""
NLP 增強服務

使用 spaCy 和 dateparser 增強時間和地點辨識的準確性
"""

import dateparser
import spacy
from loguru import logger
from typing import Dict, Any, Optional
from datetime import datetime

class NLPService:
    """NLP 增強服務類別"""
    
    def __init__(self):
        """初始化服務"""
        try:
            # 載入 spaCy 中文模型
            self.nlp = spacy.load("zh_core_web_sm")
            logger.info("✅ spaCy 中文模型載入成功")
        except OSError:
            logger.warning("⚠️ spaCy 中文模型未安裝，將跳過 NLP 增強")
            self.nlp = None
    
    def extract_entities(
        self,
        event_data: Dict[str, Any],
        original_text: str
    ) -> Dict[str, Any]:
        """
        使用 NLP 工具增強時間和地點辨識
        
        Args:
            event_data: GPT 解析的行程資料
            original_text: 原始語音文字
        
        Returns:
            增強後的行程資料
        """
        logger.info(f"開始 NLP 增強：{original_text}")
        
        # 1. 增強時間辨識（使用 dateparser）
        event_data = self._enhance_time_parsing(event_data, original_text)
        
        # 2. 增強地點辨識（使用 spaCy）
        if self.nlp:
            event_data = self._enhance_location_parsing(event_data, original_text)
        
        logger.info(f"NLP 增強完成：{event_data}")
        return event_data
    
    def _enhance_time_parsing(
        self,
        event_data: Dict[str, Any],
        text: str
    ) -> Dict[str, Any]:
        """
        使用 dateparser 增強時間解析
        
        處理中文時間表達（例如：明天、下週、後天等）
        """
        try:
            # 檢查是否包含相對時間詞彙
            relative_time_keywords = [
                "明天", "後天", "大後天",
                "下週", "下個月", "下禮拜",
                "今天", "今晚", "今早"
            ]
            
            has_relative_time = any(keyword in text for keyword in relative_time_keywords)
            
            if has_relative_time:
                logger.info("檢測到相對時間詞彙，使用 dateparser 進行增強")
                
                # 使用 dateparser 解析原始文字
                parsed_date = dateparser.parse(
                    text,
                    languages=['zh'],
                    settings={
                        'PREFER_DATES_FROM': 'future',  # 優先解析未來日期
                        'RELATIVE_BASE': datetime.now(),
                    }
                )
                
                if parsed_date:
                    logger.info(f"dateparser 解析結果：{parsed_date}")
                    
                    # 如果 GPT 的日期看起來不正確，使用 dateparser 的結果
                    gpt_date = datetime.fromisoformat(event_data["startTime"])
                    
                    # 如果 GPT 解析的日期是過去的，但文字暗示未來，則使用 dateparser
                    if gpt_date < datetime.now() and parsed_date > datetime.now():
                        logger.info("使用 dateparser 的日期結果")
                        
                        # 保留 GPT 解析的時間，替換日期
                        event_data["startTime"] = parsed_date.replace(
                            hour=gpt_date.hour,
                            minute=gpt_date.minute,
                            second=0
                        ).isoformat()
                        
                        # 結束時間也相應調整
                        end_time = datetime.fromisoformat(event_data["endTime"])
                        duration = (end_time - gpt_date).total_seconds()
                        new_end_time = datetime.fromisoformat(event_data["startTime"]) + \
                                       timedelta(seconds=duration)
                        event_data["endTime"] = new_end_time.isoformat()
            
            return event_data
            
        except Exception as e:
            logger.warning(f"時間增強失敗，使用原始資料：{e}")
            return event_data
    
    def _enhance_location_parsing(
        self,
        event_data: Dict[str, Any],
        text: str
    ) -> Dict[str, Any]:
        """
        使用 spaCy 增強地點辨識
        
        提取地名、機構名稱等
        """
        try:
            # 如果 GPT 已經提取到地點，則跳過
            if event_data.get("location"):
                logger.info("GPT 已提取到地點，跳過 NLP 增強")
                return event_data
            
            # 使用 spaCy 分析文字
            doc = self.nlp(text)
            
            # 提取地點實體
            locations = []
            for ent in doc.ents:
                if ent.label_ in ["GPE", "LOC", "FAC", "ORG"]:
                    # GPE: 地理政治實體（城市、國家）
                    # LOC: 非 GPE 的地點
                    # FAC: 建築物、機場、高速公路
                    # ORG: 組織、公司（有時也是地點）
                    locations.append(ent.text)
            
            if locations:
                # 使用第一個找到的地點
                event_data["location"] = locations[0]
                logger.info(f"NLP 提取到地點：{locations[0]}")
            
            return event_data
            
        except Exception as e:
            logger.warning(f"地點增強失敗，使用原始資料：{e}")
            return event_data

# 匯入 timedelta（用於時間計算）
from datetime import timedelta

