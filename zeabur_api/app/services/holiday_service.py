"""
節日計算服務

使用 lunardate 計算農曆節日
使用 ephem 計算節氣（清明、冬至等）
"""

from datetime import datetime, date, timedelta
from typing import List, Dict, Optional
from loguru import logger

import lunardate
import ephem
import math

from app.models.holiday_schemas import Holiday, HolidayType


class HolidayService:
    """節日計算服務"""

    # 農曆月份名稱
    LUNAR_MONTH_NAMES = [
        "", "正月", "二月", "三月", "四月", "五月", "六月",
        "七月", "八月", "九月", "十月", "十一月", "臘月"
    ]

    # 農曆日期名稱
    LUNAR_DAY_NAMES = [
        "", "初一", "初二", "初三", "初四", "初五", "初六", "初七", "初八", "初九", "初十",
        "十一", "十二", "十三", "十四", "十五", "十六", "十七", "十八", "十九", "二十",
        "廿一", "廿二", "廿三", "廿四", "廿五", "廿六", "廿七", "廿八", "廿九", "三十"
    ]

    def __init__(self):
        """初始化節日服務"""
        self._cache: Dict[int, List[Holiday]] = {}

    def get_holidays_for_year(self, year: int, region: str = "taiwan") -> List[Holiday]:
        """
        取得指定年份的所有節日

        Args:
            year: 年份
            region: 地區（目前只支援 taiwan）

        Returns:
            節日列表
        """
        # 檢查快取
        cache_key = f"{region}_{year}"
        if cache_key in self._cache:
            return self._cache[cache_key]

        holidays = []

        if region == "taiwan":
            # 固定日期節日
            holidays.extend(self._get_fixed_holidays(year))
            # 農曆節日
            holidays.extend(self._get_lunar_holidays(year))
            # 節氣節日（清明、冬至）
            holidays.extend(self._get_solar_term_holidays(year))
            # 浮動節日（母親節等）
            holidays.extend(self._get_floating_holidays(year))

        # 按日期排序
        holidays.sort(key=lambda h: h.date)

        # 存入快取
        self._cache[cache_key] = holidays

        return holidays

    def _get_fixed_holidays(self, year: int) -> List[Holiday]:
        """取得固定日期的節日"""
        return [
            # 國定假日（放假）
            Holiday(
                name="元旦",
                date=f"{year}-01-01",
                type=HolidayType.national,
                is_off_day=True,
            ),
            Holiday(
                name="和平紀念日",
                date=f"{year}-02-28",
                type=HolidayType.national,
                is_off_day=True,
            ),
            Holiday(
                name="兒童節",
                date=f"{year}-04-04",
                type=HolidayType.national,
                is_off_day=True,
            ),
            Holiday(
                name="勞動節",
                date=f"{year}-05-01",
                type=HolidayType.national,
                is_off_day=True,
            ),
            Holiday(
                name="國慶日",
                date=f"{year}-10-10",
                type=HolidayType.national,
                is_off_day=True,
            ),
            # 紀念日（不放假）
            Holiday(
                name="婦女節",
                date=f"{year}-03-08",
                type=HolidayType.memorial,
                is_off_day=False,
            ),
            Holiday(
                name="植樹節",
                date=f"{year}-03-12",
                type=HolidayType.memorial,
                is_off_day=False,
            ),
            Holiday(
                name="青年節",
                date=f"{year}-03-29",
                type=HolidayType.memorial,
                is_off_day=False,
            ),
            Holiday(
                name="父親節",
                date=f"{year}-08-08",
                type=HolidayType.memorial,
                is_off_day=False,
            ),
            Holiday(
                name="教師節",
                date=f"{year}-09-28",
                type=HolidayType.memorial,
                is_off_day=False,
            ),
            Holiday(
                name="光復節",
                date=f"{year}-10-25",
                type=HolidayType.memorial,
                is_off_day=False,
            ),
            Holiday(
                name="行憲紀念日",
                date=f"{year}-12-25",
                type=HolidayType.national,
                is_off_day=False,
            ),
            Holiday(
                name="跨年夜",
                date=f"{year}-12-31",
                type=HolidayType.memorial,
                is_off_day=False,
            ),
        ]

    def _get_lunar_holidays(self, year: int) -> List[Holiday]:
        """取得農曆節日（動態計算）"""
        holidays = []

        # 農曆節日定義：(農曆月, 農曆日, 名稱, 類型, 是否放假)
        lunar_holidays_def = [
            (1, 1, "春節", HolidayType.traditional, True),
            (1, 2, "初二", HolidayType.traditional, True),
            (1, 3, "初三", HolidayType.traditional, True),
            (1, 15, "元宵節", HolidayType.traditional, False),
            (5, 5, "端午節", HolidayType.traditional, True),
            (7, 7, "七夕", HolidayType.traditional, False),
            (7, 15, "中元節", HolidayType.traditional, False),
            (8, 15, "中秋節", HolidayType.traditional, True),
            (9, 9, "重陽節", HolidayType.traditional, False),
        ]

        for lunar_month, lunar_day, name, holiday_type, is_off_day in lunar_holidays_def:
            try:
                # 將農曆轉換為西曆
                solar_date = self._lunar_to_solar(year, lunar_month, lunar_day)
                if solar_date:
                    lunar_date_str = f"{self.LUNAR_MONTH_NAMES[lunar_month]}{self.LUNAR_DAY_NAMES[lunar_day]}"
                    holidays.append(Holiday(
                        name=name,
                        date=solar_date.strftime("%Y-%m-%d"),
                        type=holiday_type,
                        is_off_day=is_off_day,
                        lunar_date=lunar_date_str,
                    ))
            except Exception as e:
                logger.warning(f"計算農曆節日失敗: {name} ({year}年{lunar_month}月{lunar_day}日) - {e}")

        # 除夕：春節前一天
        try:
            spring_festival = self._lunar_to_solar(year, 1, 1)
            if spring_festival:
                new_years_eve = spring_festival - timedelta(days=1)
                # 取得除夕的農曆日期（可能是臘月二十九或三十）
                lunar_eve = lunardate.LunarDate.fromSolarDate(
                    new_years_eve.year, new_years_eve.month, new_years_eve.day
                )
                lunar_eve_str = f"{self.LUNAR_MONTH_NAMES[lunar_eve.month]}{self.LUNAR_DAY_NAMES[lunar_eve.day]}"
                holidays.append(Holiday(
                    name="除夕",
                    date=new_years_eve.strftime("%Y-%m-%d"),
                    type=HolidayType.traditional,
                    is_off_day=True,
                    lunar_date=lunar_eve_str,
                ))
        except Exception as e:
            logger.warning(f"計算除夕失敗: {year} - {e}")

        return holidays

    def _lunar_to_solar(self, solar_year: int, lunar_month: int, lunar_day: int) -> Optional[date]:
        """
        將農曆日期轉換為西曆日期

        注意：農曆新年可能在西曆年份的 1-2 月
        我們需要找到在給定西曆年份中對應的農曆節日

        Args:
            solar_year: 目標西曆年份
            lunar_month: 農曆月份
            lunar_day: 農曆日期

        Returns:
            西曆日期
        """
        try:
            # 對於農曆正月的節日，可能需要使用前一年的農曆年
            # 例如：2026年春節（農曆正月初一）對應的是農曆 2025 年（乙巳年）

            # 策略：嘗試當年和前一年的農曆，選擇落在目標西曆年份的結果
            candidates = []

            for lunar_year in [solar_year - 1, solar_year]:
                try:
                    ld = lunardate.LunarDate(lunar_year, lunar_month, lunar_day)
                    sd = ld.toSolarDate()
                    solar_date = date(sd.year, sd.month, sd.day)
                    candidates.append(solar_date)
                except ValueError:
                    # 該年農曆沒有這個日期（如閏月情況）
                    continue

            # 選擇落在目標西曆年份的日期
            for solar_date in candidates:
                if solar_date.year == solar_year:
                    return solar_date

            # 如果都不在目標年份，返回最接近的
            if candidates:
                return min(candidates, key=lambda d: abs(d.year - solar_year))

            return None

        except Exception as e:
            logger.warning(f"農曆轉換失敗: {solar_year}/{lunar_month}/{lunar_day} - {e}")
            return None

    def _get_solar_term_holidays(self, year: int) -> List[Holiday]:
        """取得節氣相關節日（清明、冬至）"""
        holidays = []

        # 清明節：太陽黃經 15 度
        qingming = self._calculate_solar_term(year, 15)
        if qingming:
            holidays.append(Holiday(
                name="清明節",
                date=qingming.strftime("%Y-%m-%d"),
                type=HolidayType.traditional,
                is_off_day=True,
            ))

        # 冬至：太陽黃經 270 度
        dongzhi = self._calculate_solar_term(year, 270)
        if dongzhi:
            holidays.append(Holiday(
                name="冬至",
                date=dongzhi.strftime("%Y-%m-%d"),
                type=HolidayType.traditional,
                is_off_day=False,
            ))

        return holidays

    def _calculate_solar_term(self, year: int, target_longitude: float) -> Optional[date]:
        """
        計算節氣日期

        使用 ephem 計算太陽到達指定黃經的日期

        Args:
            year: 年份
            target_longitude: 目標太陽黃經（度）

        Returns:
            節氣日期
        """
        try:
            # 根據黃經估算搜尋起始日期
            # 清明（15度）約在 4 月初，冬至（270度）約在 12 月下旬
            if target_longitude < 90:
                # 春季節氣
                start_date = date(year, 3, 1)
            elif target_longitude < 180:
                # 夏季節氣
                start_date = date(year, 6, 1)
            elif target_longitude < 270:
                # 秋季節氣
                start_date = date(year, 9, 1)
            else:
                # 冬季節氣
                start_date = date(year, 12, 1)

            # 使用二分搜尋找到太陽黃經等於目標值的日期
            sun = ephem.Sun()

            # 搜尋範圍：起始日期前後 45 天
            low = ephem.Date(start_date - timedelta(days=45))
            high = ephem.Date(start_date + timedelta(days=45))

            target_rad = math.radians(target_longitude)

            for _ in range(50):  # 最多迭代 50 次
                mid = (low + high) / 2
                sun.compute(mid)

                # 取得太陽黃經（弧度）
                current_lon = float(ephem.Ecliptic(sun).lon)

                # 處理黃經跨越 0/360 度的情況
                diff = current_lon - target_rad
                if diff > math.pi:
                    diff -= 2 * math.pi
                elif diff < -math.pi:
                    diff += 2 * math.pi

                if abs(diff) < 0.0001:  # 精度約為 0.006 度
                    result_date = ephem.Date(mid).datetime().date()
                    return result_date

                if diff > 0:
                    high = mid
                else:
                    low = mid

            # 使用最後的近似值
            result_date = ephem.Date((low + high) / 2).datetime().date()
            return result_date

        except Exception as e:
            logger.warning(f"計算節氣失敗: {year}年 黃經{target_longitude}度 - {e}")
            return None

    def _get_floating_holidays(self, year: int) -> List[Holiday]:
        """取得浮動日期節日（如母親節：5月第二個週日）"""
        holidays = []

        # 母親節：5 月第二個週日
        mothers_day = self._get_nth_weekday_of_month(year, 5, 6, 2)  # 週日=6
        if mothers_day:
            holidays.append(Holiday(
                name="母親節",
                date=mothers_day.strftime("%Y-%m-%d"),
                type=HolidayType.memorial,
                is_off_day=False,
            ))

        return holidays

    def _get_nth_weekday_of_month(
        self, year: int, month: int, weekday: int, n: int
    ) -> Optional[date]:
        """
        取得某月第 n 個星期幾

        Args:
            year: 年份
            month: 月份
            weekday: 星期幾（0=週一, 6=週日）
            n: 第幾個（1=第一個）

        Returns:
            日期
        """
        try:
            # 從該月第一天開始
            first_day = date(year, month, 1)

            # 計算第一個目標星期幾的日期
            days_until_weekday = (weekday - first_day.weekday()) % 7
            first_target = first_day + timedelta(days=days_until_weekday)

            # 計算第 n 個
            result = first_target + timedelta(weeks=n - 1)

            # 確認還在同一個月
            if result.month == month:
                return result
            return None

        except Exception as e:
            logger.warning(f"計算浮動節日失敗: {year}/{month} 第{n}個週{weekday} - {e}")
            return None


# 單例實例
holiday_service = HolidayService()
