//+------------------------------------------------------------------+
//|                                                   TimeUtils.mqh   |
//|                                Copyright 2024, Gridzilla Project  |
//+------------------------------------------------------------------+
#property copyright "Gridzilla Project"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Trading sessions                                                   |
//+------------------------------------------------------------------+
enum ENUM_TRADING_SESSION {
    SESSION_ASIAN = 0,          // Tokyo session: 00:00-09:00 UTC
    SESSION_EUROPEAN = 1,       // London session: 07:00-16:00 UTC
    SESSION_AMERICAN = 2,       // New York session: 13:00-22:00 UTC
    SESSION_OVERLAP_EU_US = 3,  // EU/US overlap: 13:00-16:00 UTC (highest volatility)
    SESSION_OFF_HOURS = 4       // Outside major sessions
};

//+------------------------------------------------------------------+
//| CTimeUtils - Tid och session-relaterade hjälpfunktioner           |
//|                                                                   |
//| Syfte: Tillhandahålla deterministiska tidsberäkningar för         |
//| session-identifiering och marknadstider.                          |
//+------------------------------------------------------------------+
class CTimeUtils {
public:
    //+------------------------------------------------------------------+
    //| GetCurrentSession - Identifiera nuvarande handelssession          |
    //|                                                                   |
    //| server_time: Servertid (UTC antas)                                |
    //+------------------------------------------------------------------+
    static ENUM_TRADING_SESSION GetCurrentSession(datetime server_time) {
        MqlDateTime dt;
        TimeToStruct(server_time, dt);
        int hour = dt.hour;

        // EU/US Overlap har högst prioritet (13:00-16:00 UTC)
        if (hour >= 13 && hour < 16) {
            return SESSION_OVERLAP_EU_US;
        }

        // American session (13:00-22:00 UTC)
        if (hour >= 13 && hour < 22) {
            return SESSION_AMERICAN;
        }

        // European session (07:00-16:00 UTC)
        if (hour >= 7 && hour < 16) {
            return SESSION_EUROPEAN;
        }

        // Asian session (00:00-09:00 UTC)
        if (hour >= 0 && hour < 9) {
            return SESSION_ASIAN;
        }

        // Off-hours (22:00-00:00 UTC, eller tidigt morgon före Asien)
        return SESSION_OFF_HOURS;
    }

    //+------------------------------------------------------------------+
    //| GetCurrentSessionNow - Identifiera session med TimeCurrent()      |
    //+------------------------------------------------------------------+
    static ENUM_TRADING_SESSION GetCurrentSessionNow() {
        return GetCurrentSession(TimeCurrent());
    }

    //+------------------------------------------------------------------+
    //| SessionToString - Konvertera session till sträng                  |
    //+------------------------------------------------------------------+
    static string SessionToString(ENUM_TRADING_SESSION session) {
        switch (session) {
            case SESSION_ASIAN:        return "Asian";
            case SESSION_EUROPEAN:     return "European";
            case SESSION_AMERICAN:     return "American";
            case SESSION_OVERLAP_EU_US: return "EU/US Overlap";
            case SESSION_OFF_HOURS:    return "Off Hours";
            default:                   return "Unknown";
        }
    }

    //+------------------------------------------------------------------+
    //| IsSessionActive - Kontrollera om specifik session är aktiv        |
    //+------------------------------------------------------------------+
    static bool IsSessionActive(ENUM_TRADING_SESSION session, datetime time) {
        MqlDateTime dt;
        TimeToStruct(time, dt);
        int hour = dt.hour;

        switch (session) {
            case SESSION_ASIAN:
                return (hour >= 0 && hour < 9);
            case SESSION_EUROPEAN:
                return (hour >= 7 && hour < 16);
            case SESSION_AMERICAN:
                return (hour >= 13 && hour < 22);
            case SESSION_OVERLAP_EU_US:
                return (hour >= 13 && hour < 16);
            case SESSION_OFF_HOURS:
                return (hour >= 22 || hour < 7);
            default:
                return false;
        }
    }

    //+------------------------------------------------------------------+
    //| IsWeekend - Kontrollera om det är helg                            |
    //+------------------------------------------------------------------+
    static bool IsWeekend(datetime time) {
        MqlDateTime dt;
        TimeToStruct(time, dt);
        // 0 = Söndag, 6 = Lördag
        return (dt.day_of_week == 0 || dt.day_of_week == 6);
    }

    //+------------------------------------------------------------------+
    //| IsWeekendNow - Kontrollera om det är helg nu                       |
    //+------------------------------------------------------------------+
    static bool IsWeekendNow() {
        return IsWeekend(TimeCurrent());
    }

    //+------------------------------------------------------------------+
    //| IsFridayClose - Kontrollera om det är fredag nära stängning       |
    //|                                                                   |
    //| close_hour: Timme då marknaden stänger (default 21 UTC)           |
    //+------------------------------------------------------------------+
    static bool IsFridayClose(datetime time, int close_hour = 21) {
        MqlDateTime dt;
        TimeToStruct(time, dt);
        // Fredag = 5
        return (dt.day_of_week == 5 && dt.hour >= close_hour);
    }

    //+------------------------------------------------------------------+
    //| IsSundayOpen - Kontrollera om det är söndag nära öppning          |
    //|                                                                   |
    //| open_hour: Timme då marknaden öppnar (default 22 UTC)             |
    //+------------------------------------------------------------------+
    static bool IsSundayOpen(datetime time, int open_hour = 22) {
        MqlDateTime dt;
        TimeToStruct(time, dt);
        // Söndag = 0
        return (dt.day_of_week == 0 && dt.hour >= open_hour);
    }

    //+------------------------------------------------------------------+
    //| IsWeekendLockout - Kontrollera om handel ska undvikas pga helg     |
    //|                                                                   |
    //| Returnerar true från fredag 21:00 till söndag 22:00 UTC           |
    //+------------------------------------------------------------------+
    static bool IsWeekendLockout(datetime time) {
        if (IsFridayClose(time, 21)) return true;
        if (IsWeekend(time) && !IsSundayOpen(time, 22)) return true;
        return false;
    }

    //+------------------------------------------------------------------+
    //| GetHourUTC - Hämta timme (0-23) från tid                          |
    //+------------------------------------------------------------------+
    static int GetHourUTC(datetime time) {
        MqlDateTime dt;
        TimeToStruct(time, dt);
        return dt.hour;
    }

    //+------------------------------------------------------------------+
    //| GetMinuteOfDay - Hämta minut av dagen (0-1439)                    |
    //+------------------------------------------------------------------+
    static int GetMinuteOfDay(datetime time) {
        MqlDateTime dt;
        TimeToStruct(time, dt);
        return dt.hour * 60 + dt.min;
    }

    //+------------------------------------------------------------------+
    //| GetDayOfWeek - Hämta veckodag (0=Söndag, 6=Lördag)                |
    //+------------------------------------------------------------------+
    static int GetDayOfWeek(datetime time) {
        MqlDateTime dt;
        TimeToStruct(time, dt);
        return dt.day_of_week;
    }

    //+------------------------------------------------------------------+
    //| GetStartOfDay - Hämta början av dagen (00:00:00)                  |
    //+------------------------------------------------------------------+
    static datetime GetStartOfDay(datetime time) {
        MqlDateTime dt;
        TimeToStruct(time, dt);
        dt.hour = 0;
        dt.min = 0;
        dt.sec = 0;
        return StructToTime(dt);
    }

    //+------------------------------------------------------------------+
    //| GetStartOfWeek - Hämta början av veckan (måndag 00:00)            |
    //+------------------------------------------------------------------+
    static datetime GetStartOfWeek(datetime time) {
        MqlDateTime dt;
        TimeToStruct(time, dt);

        // Beräkna dagar sedan måndag (måndag = 1)
        int days_since_monday = dt.day_of_week - 1;
        if (days_since_monday < 0) days_since_monday = 6;  // Söndag

        datetime start_of_day = GetStartOfDay(time);
        return start_of_day - days_since_monday * 86400;  // 86400 sekunder per dag
    }

    //+------------------------------------------------------------------+
    //| BarsSince - Räkna antal bars sedan given tid                      |
    //|                                                                   |
    //| from_time: Starttid                                               |
    //| tf: Timeframe (PERIOD_M1, PERIOD_H1, etc.)                        |
    //+------------------------------------------------------------------+
    static int BarsSince(datetime from_time, ENUM_TIMEFRAMES tf = PERIOD_CURRENT) {
        datetime now = TimeCurrent();
        if (from_time >= now) return 0;

        int bar_seconds = PeriodSeconds(tf);
        if (bar_seconds == 0) return 0;

        return (int)((now - from_time) / bar_seconds);
    }

    //+------------------------------------------------------------------+
    //| AddBars - Lägg till antal bars till tid                           |
    //+------------------------------------------------------------------+
    static datetime AddBars(datetime start, int bars, ENUM_TIMEFRAMES tf = PERIOD_CURRENT) {
        int bar_seconds = PeriodSeconds(tf);
        return start + bars * bar_seconds;
    }

    //+------------------------------------------------------------------+
    //| GetBarDurationHours - Hämta bar-längd i timmar                    |
    //+------------------------------------------------------------------+
    static double GetBarDurationHours(ENUM_TIMEFRAMES tf) {
        return PeriodSeconds(tf) / 3600.0;
    }

    //+------------------------------------------------------------------+
    //| GetBarDurationMinutes - Hämta bar-längd i minuter                 |
    //+------------------------------------------------------------------+
    static double GetBarDurationMinutes(ENUM_TIMEFRAMES tf) {
        return PeriodSeconds(tf) / 60.0;
    }

    //+------------------------------------------------------------------+
    //| FormatTime - Formatera tid till sträng                            |
    //+------------------------------------------------------------------+
    static string FormatTime(datetime time, bool include_seconds = true) {
        if (include_seconds) {
            return TimeToString(time, TIME_DATE | TIME_SECONDS);
        }
        return TimeToString(time, TIME_DATE | TIME_MINUTES);
    }

    //+------------------------------------------------------------------+
    //| FormatDuration - Formatera duration (sekunder) till läsbar sträng |
    //+------------------------------------------------------------------+
    static string FormatDuration(int seconds) {
        if (seconds < 0) seconds = 0;

        int days = seconds / 86400;
        int hours = (seconds % 86400) / 3600;
        int mins = (seconds % 3600) / 60;
        int secs = seconds % 60;

        if (days > 0) {
            return StringFormat("%dd %02d:%02d:%02d", days, hours, mins, secs);
        }
        if (hours > 0) {
            return StringFormat("%d:%02d:%02d", hours, mins, secs);
        }
        return StringFormat("%d:%02d", mins, secs);
    }

    //+------------------------------------------------------------------+
    //| GetTimeDifferenceHours - Beräkna tidsskillnad i timmar            |
    //+------------------------------------------------------------------+
    static double GetTimeDifferenceHours(datetime time1, datetime time2) {
        return MathAbs((double)(time1 - time2)) / 3600.0;
    }

    //+------------------------------------------------------------------+
    //| IsNewBar - Kontrollera om ny bar har bildats                      |
    //|                                                                   |
    //| last_bar_time: Referens till senast kända bar-tid                 |
    //| tf: Timeframe                                                     |
    //| Returnerar true och uppdaterar last_bar_time om ny bar            |
    //+------------------------------------------------------------------+
    static bool IsNewBar(datetime &last_bar_time, ENUM_TIMEFRAMES tf = PERIOD_CURRENT) {
        datetime current_bar_time = iTime(_Symbol, tf, 0);
        if (current_bar_time > last_bar_time) {
            last_bar_time = current_bar_time;
            return true;
        }
        return false;
    }

    //+------------------------------------------------------------------+
    //| HoursBetween - Antal timmar mellan två tidpunkter                 |
    //+------------------------------------------------------------------+
    static int HoursBetween(datetime start, datetime end) {
        return (int)MathAbs((end - start) / 3600);
    }

    //+------------------------------------------------------------------+
    //| MinutesBetween - Antal minuter mellan två tidpunkter              |
    //+------------------------------------------------------------------+
    static int MinutesBetween(datetime start, datetime end) {
        return (int)MathAbs((end - start) / 60);
    }
};

//+------------------------------------------------------------------+
