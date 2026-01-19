"""
GPT 語意解析服務

使用 OpenAI GPT API 將口語化文字解析為結構化行程資料
"""

import os
import json
from openai import OpenAI
from loguru import logger
from datetime import datetime, timedelta
from typing import Dict, Any, List, Optional

class GPTService:
    """GPT 語意解析服務類別"""
    
    def __init__(self):
        """初始化服務"""
        api_key = os.getenv("OPENAI_API_KEY")
        if not api_key:
            raise ValueError("未設定 OPENAI_API_KEY 環境變數")

        self.client = OpenAI(api_key=api_key)

    def _get_weekday_chinese(self, dt: datetime) -> str:
        """將日期轉換為中文星期"""
        weekdays = ["一", "二", "三", "四", "五", "六", "日"]
        return weekdays[dt.weekday()]
    
    def _build_label_prompt(self, labels: Optional[List[Dict[str, str]]]) -> str:
        """
        建立標籤推斷的 prompt 片段

        Args:
            labels: 標籤列表，每個標籤包含 id 和 name

        Returns:
            標籤推斷規則的 prompt 字串
        """
        if not labels or len(labels) == 0:
            return ""

        prompt = """
9. **標籤推斷**：
   根據行程內容，選擇最適合的標籤 ID。可用標籤如下：
"""
        for label in labels:
            label_id = label.get('id', '')
            label_name = label.get('name', '')
            prompt += f"   - {label_id}：{label_name}\n"

        prompt += """
   推斷規則：
   - 會議、討論、報告、客戶、專案 → 選擇「會議」或「工作」相關標籤
   - 爸媽、家人、親戚 → 選擇「家庭」相關標籤
   - 讀書、上課、考試、作業 → 選擇「學習」相關標籤
   - 健身、跑步、游泳、球類、運動 → 選擇「運動」相關標籤
   - 看電影、吃飯、玩樂、休息 → 選擇「休閒」相關標籤
   - 約會、情侶 → 選擇「約會」相關標籤
   - 出差、旅遊、出國 → 選擇「旅行」相關標籤
   - 生日、慶祝 → 選擇「個人」或相關標籤
   - 如果無法確定適合的標籤，labelId 設為 null
"""
        return prompt

    def parse_event_from_text(self, text: str, labels: Optional[List[Dict[str, str]]] = None) -> Dict[str, Any]:
        """
        將口語化文字解析為結構化行程資料

        Args:
            text: 語音轉換的文字
            labels: 可選的標籤列表，用於 AI 自動選擇標籤

        Returns:
            結構化的行程資料字典

        Raises:
            Exception: 解析失敗時拋出例外
        """
        try:
            logger.info(f"開始解析文字：{text}")
            if labels:
                logger.info(f"使用標籤列表：{labels}")

            # 取得當前日期時間作為參考
            now = datetime.now()
            current_date = now.strftime("%Y-%m-%d")
            current_time = now.strftime("%H:%M")

            # 建立標籤推斷 prompt（如果有提供標籤）
            label_prompt = self._build_label_prompt(labels)

            # 建立系統提示詞
            system_prompt = f"""你是一個專業的行程解析助手。
用戶會用口語化的方式描述行程，你需要將它轉換成 JSON 格式。

當前日期時間參考：
- 日期：{current_date}（星期{self._get_weekday_chinese(now)}）
- 時間：{current_time}

=== 解析規則 ===

1. **標題提取**（最重要）：
   - 提取核心動作或活動名稱作為標題
   - "去餐廳吃飯" → 標題："吃飯"
   - "跟 Amy 開會" → 標題："跟 Amy 開會"
   - "看電影" → 標題："看電影"
   - "做報告" → 標題："做報告"
   - "健身" / "運動" → 標題："健身" / "運動"
   - 標題應簡潔明瞭，不包含時間地點資訊

2. **時間格式**：必須使用 ISO 8601 格式（YYYY-MM-DDTHH:MM:SS）

3. **日期推斷**：
   - "今天" → {current_date}
   - "明天" → 當前日期 + 1 天
   - "後天" / "大後天" → 當前日期 + 2/3 天
   - "下週一/二/三/四/五/六/日" → 計算下週對應星期的日期
   - "這週X" / "本週X" → 計算本週對應星期的日期
   - "X月X日" / "X月X號" → 使用指定日期（年份預設為當年，若已過則為明年）
   - "月底" → 當月最後一天
   - "下個月X號" → 下個月對應日期

4. **時間推斷**：
   - "早上" / "上午" → 09:00
   - "中午" → 12:00
   - "下午" → 14:00（若有具體時間如"下午3點"則為 15:00）
   - "傍晚" → 17:00
   - "晚上" → 19:00（若有具體時間如"晚上8點"則為 20:00）
   - "凌晨" → 02:00
   - "半夜" → 00:00
   - 數字時間：
     - "兩點" / "2點" → 根據上下文判斷 02:00 或 14:00（預設下午）
     - "下午5點" / "五點" → 17:00
     - "兩點半" / "2點30" → 14:30
     - "三點十五" → 15:15
     - "差十分三點" → 14:50

5. **持續時間**：
   - 若未明確說明結束時間，預設為開始時間 + 1 小時
   - "開會兩小時" → 結束時間 = 開始時間 + 2 小時
   - "全天" / "整天" → isAllDay: true，startTime 為 00:00:00，endTime 為 23:59:59
   - "一整個下午" → 14:00 到 18:00

6. **地點提取**：
   - "在XX" → 地點：XX（例如："在咖啡廳" → "咖啡廳"）
   - "去XX" → 地點：XX（例如："去餐廳" → "餐廳"）
   - "到XX" → 地點：XX
   - "XX見" → 地點：XX
   - 具體地名直接提取（例如："台北101" → "台北101"）
   - 若無地點資訊，location 設為空字串 ""

7. **備註 (description)**：
   - "記得帶XX" / "要帶XX" → 寫入 description
   - "注意XX" / "別忘了XX" → 寫入 description
   - 額外說明資訊寫入 description
   - 若無額外資訊，description 設為空字串 ""

8. **參與者**：
   - "跟XX" / "和XX" / "與XX" → 加入 participants
   - 多人用頓號或「和」分隔："跟 Amy 和 Bob" → ["Amy", "Bob"]
   - 若無參與者，participants 設為空陣列 []
{label_prompt}
=== 解析範例 ===

範例 1：
輸入："明天下午5點去餐廳吃飯"
輸出：
{{
  "title": "吃飯",
  "startTime": "2025-01-21T17:00:00",
  "endTime": "2025-01-21T18:00:00",
  "location": "餐廳",
  "description": "",
  "isAllDay": false,
  "participants": []
}}

範例 2：
輸入："下週三早上十點在咖啡廳跟 Amy 討論專案"
輸出：
{{
  "title": "跟 Amy 討論專案",
  "startTime": "2025-01-29T10:00:00",
  "endTime": "2025-01-29T11:00:00",
  "location": "咖啡廳",
  "description": "",
  "isAllDay": false,
  "participants": ["Amy"]
}}

範例 3：
輸入："後天整天要出差，記得帶筆電"
輸出：
{{
  "title": "出差",
  "startTime": "2025-01-22T00:00:00",
  "endTime": "2025-01-22T23:59:59",
  "location": "",
  "description": "記得帶筆電",
  "isAllDay": true,
  "participants": []
}}

範例 4：
輸入："禮拜五晚上7點半和小明去看電影"
輸出：
{{
  "title": "看電影",
  "startTime": "2025-01-24T19:30:00",
  "endTime": "2025-01-24T20:30:00",
  "location": "",
  "description": "",
  "isAllDay": false,
  "participants": ["小明"]
}}

範例 5：
輸入："1月30號下午三點到五點在會議室開會"
輸出：
{{
  "title": "開會",
  "startTime": "2025-01-30T15:00:00",
  "endTime": "2025-01-30T17:00:00",
  "location": "會議室",
  "description": "",
  "isAllDay": false,
  "participants": []
}}

範例 6：
輸入："今天中午吃飯"
輸出：
{{
  "title": "吃飯",
  "startTime": "{current_date}T12:00:00",
  "endTime": "{current_date}T13:00:00",
  "location": "",
  "description": "",
  "isAllDay": false,
  "participants": []
}}

=== 重要提醒 ===
- 只輸出 JSON 格式，不要有任何其他文字或解釋
- 確保時間邏輯正確（結束時間不能早於開始時間）
- 如果資訊不足，使用合理的預設值
- 標題必須簡潔，不要包含時間地點等冗餘資訊
- 如果有提供標籤列表，必須根據行程內容推斷 labelId（可為 null）
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

