"""
節日 API 路由

提供台灣節日資料查詢端點
"""

from fastapi import APIRouter, HTTPException, Query
from datetime import datetime
from loguru import logger

from app.models.holiday_schemas import HolidaysResponse
from app.services.holiday_service import holiday_service

router = APIRouter()


@router.get("/", response_model=HolidaysResponse)
async def get_current_year_holidays(
    region: str = Query(default="taiwan", description="地區（目前僅支援 taiwan）")
):
    """
    取得當年度節日列表

    自動使用當前年份
    """
    current_year = datetime.now().year
    return await get_holidays_by_year(current_year, region)


@router.get("/{year}", response_model=HolidaysResponse)
async def get_holidays_by_year(
    year: int,
    region: str = Query(default="taiwan", description="地區（目前僅支援 taiwan）")
):
    """
    取得指定年份的節日列表

    Args:
        year: 年份（如 2026）
        region: 地區（目前僅支援 taiwan）

    Returns:
        該年度的所有節日資料
    """
    # 驗證年份範圍
    if year < 1900 or year > 2100:
        raise HTTPException(
            status_code=400,
            detail=f"年份必須在 1900-2100 之間，收到: {year}"
        )

    # 驗證地區
    supported_regions = ["taiwan"]
    if region not in supported_regions:
        raise HTTPException(
            status_code=400,
            detail=f"不支援的地區: {region}。目前支援: {', '.join(supported_regions)}"
        )

    try:
        logger.info(f"取得節日資料: {year}年 {region}")
        holidays = holiday_service.get_holidays_for_year(year, region)

        return HolidaysResponse(
            year=year,
            region=region,
            holidays=holidays,
            generated_at=datetime.now().isoformat(),
        )

    except Exception as e:
        logger.error(f"取得節日資料失敗: {year}年 {region} - {e}")
        raise HTTPException(
            status_code=500,
            detail=f"取得節日資料失敗: {str(e)}"
        )
