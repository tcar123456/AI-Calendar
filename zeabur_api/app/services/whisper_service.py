"""
Whisper 語音辨識服務

使用 OpenAI Whisper API 將語音轉換為文字
"""

import os
import httpx
from openai import OpenAI
from loguru import logger
from typing import Optional

class WhisperService:
    """Whisper 語音辨識服務類別"""
    
    def __init__(self):
        """初始化服務"""
        api_key = os.getenv("OPENAI_API_KEY")
        if not api_key:
            raise ValueError("未設定 OPENAI_API_KEY 環境變數")
        
        self.client = OpenAI(api_key=api_key)
    
    async def transcribe_from_url(self, audio_url: str) -> str:
        """
        從 URL 下載音檔並轉錄為文字

        Args:
            audio_url: 音檔 URL（Firebase Storage URL）

        Returns:
            轉錄的文字內容

        Raises:
            Exception: 轉錄失敗時拋出例外
        """
        try:
            logger.info(f"開始下載音檔：{audio_url}")

            # 從 URL 中提取檔案擴展名
            # Firebase Storage URL 格式：.../{userId}/{timestamp}.{ext}?...
            import re
            ext_match = re.search(r'\.(\w+)\?', audio_url)
            file_ext = ext_match.group(1) if ext_match else 'wav'
            logger.info(f"檔案格式：{file_ext}")

            # 下載音檔
            async with httpx.AsyncClient() as client:
                response = await client.get(audio_url, timeout=30.0)
                response.raise_for_status()
                audio_data = response.content

            logger.info(f"音檔下載完成，大小：{len(audio_data)} bytes")

            # 將音檔存為暫存檔案（使用正確的擴展名）
            temp_file_path = f"/tmp/audio.{file_ext}"
            with open(temp_file_path, "wb") as f:
                f.write(audio_data)

            # 使用 Whisper API 轉錄
            logger.info("開始進行語音辨識...")

            with open(temp_file_path, "rb") as audio_file:
                transcript = self.client.audio.transcriptions.create(
                    model="whisper-1",
                    file=audio_file,
                    language="zh",  # 指定中文
                    response_format="text"
                )

            # 清理暫存檔案
            if os.path.exists(temp_file_path):
                os.remove(temp_file_path)

            logger.info(f"語音辨識完成：{transcript}")
            return transcript
            
        except httpx.HTTPError as e:
            logger.error(f"下載音檔失敗：{e}")
            raise Exception(f"下載音檔失敗：{str(e)}")
        
        except Exception as e:
            logger.error(f"語音辨識失敗：{e}")
            raise Exception(f"語音辨識失敗：{str(e)}")
    
    def transcribe_from_file(self, file_path: str) -> str:
        """
        從本地檔案轉錄為文字
        
        Args:
            file_path: 本地音檔路徑
        
        Returns:
            轉錄的文字內容
        """
        try:
            with open(file_path, "rb") as audio_file:
                transcript = self.client.audio.transcriptions.create(
                    model="whisper-1",
                    file=audio_file,
                    language="zh",
                    response_format="text"
                )
            
            return transcript
            
        except Exception as e:
            logger.error(f"語音辨識失敗：{e}")
            raise Exception(f"語音辨識失敗：{str(e)}")

