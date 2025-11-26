"""
GPT 語意解析服務

使用 OpenAI GPT API 將口語化文字解析為結構化行程資料
"""

import os
import json
from openai import OpenAI
from loguru import logger
from datetime import datetime, timedelta
from typing import Dict, Any

class GPTService:
    """GPT 語意解析服務類別"""
    
    def __init__(self):
        """初始化服務"""
        api_key = os.getenv("OPENAI_API_KEY")
        if not api_key:
            raise ValueError("未設定 OPENAI_API_KEY 環境變數")
        
        self.client = OpenAI(api_key=api_key)
    
    def parse_event_from_text(self, text: str) -> Dict[str, Any]:
        """
        將口語化文字解析為結構化行程資料
        
        Args:
            text: 語音轉換的文字
        
        Returns:
            結構化的行程資料字典
        
        Raises:
            Exception: 解析失敗時拋出例外
        """
        try:
            logger.info(f"開始解析文字：{text}")
            
            # 取得當前日期時間作為參考
            now = datetime.now()
            current_date = now.strftime("%Y-%m-%d")
            current_time = now.strftime("%H:%M")
            
            # 建立系統提示詞
            system_prompt = f"""你是一個專業的行程解析助手。
用戶會用口語化的方式描述行程，你需要將它轉換成 JSON 格式。

當前日期時間參考：
- 日期：{current_date}
- 時間：{current_time}

輸出格式範例：
{{
  "title": "跟 Amy 開會",
  "startTime": "2025-10-05T14:00:00",
  "endTime": "2025-10-05T15:00:00",
  "location": "公司會議室",
  "description": "討論 Q4 專案進度，記得帶筆電和報告",
  "isAllDay": false,
  "participants": []
}}

解析規則：
1. **時間格式**：必須使用 ISO 8601 格式（YYYY-MM-DDTHH:MM:SS）
2. **日期推斷**：
   - "今天" → 使用當前日期
   - "明天" → 當前日期 + 1 天
   - "後天" → 當前日期 + 2 天
   - "下週一/二/三..." → 計算下週對應星期的日期
   - "X月X日" → 使用指定日期（年份預設為當年）
3. **時間推斷**：
   - "早上/上午" → 09:00
   - "中午" → 12:00
   - "下午" → 14:00
   - "晚上" → 19:00
   - 具體時間如"兩點"/"14點" → 14:00
   - "兩點半" → 14:30
4. **持續時間**：
   - 若未明確說明結束時間，預設為開始時間 + 1 小時
   - 若說"全天"，設定 isAllDay: true，startTime 為 00:00，endTime 為 23:59
5. **地點**：從文字中提取地點資訊（例如：在XX、去XX、XX會議室）
6. **備註**：
   - 其他資訊（例如：記得帶XX、注意XX、要做XX）寫入 description
   - 多個資訊用逗號分隔
7. **參與者**：暫時留空陣列（未來可擴展人名辨識）

**重要**：
- 只輸出 JSON 格式，不要有其他文字
- 確保時間邏輯正確（結束時間不能早於開始時間）
- 如果資訊不足，使用合理的預設值
"""
            
            # 呼叫 GPT API
            response = self.client.chat.completions.create(
                model="gpt-4",  # 或使用 "gpt-3.5-turbo" 降低成本
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": f"請解析以下行程描述：\n{text}"}
                ],
                temperature=0.3,  # 降低隨機性，提高準確性
                max_tokens=500,
            )
            
            # 取得回應內容
            result_text = response.choices[0].message.content
            logger.info(f"GPT 回應：{result_text}")
            
            # 解析 JSON
            result = json.loads(result_text)
            
            # 驗證必要欄位
            required_fields = ["title", "startTime", "endTime"]
            for field in required_fields:
                if field not in result:
                    raise ValueError(f"缺少必要欄位：{field}")
            
            # 驗證時間格式
            try:
                datetime.fromisoformat(result["startTime"])
                datetime.fromisoformat(result["endTime"])
            except ValueError as e:
                raise ValueError(f"時間格式錯誤：{e}")
            
            logger.info(f"解析完成：{result}")
            return result
            
        except json.JSONDecodeError as e:
            logger.error(f"JSON 解析失敗：{e}")
            logger.error(f"原始回應：{result_text}")
            raise Exception(f"JSON 解析失敗：{str(e)}")
        
        except Exception as e:
            logger.error(f"GPT 解析失敗：{e}")
            raise Exception(f"GPT 解析失敗：{str(e)}")

