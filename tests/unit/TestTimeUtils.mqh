//+------------------------------------------------------------------+
//|                                               TestTimeUtils.mqh   |
//|                                Copyright 2024, Gridzilla Project  |
//+------------------------------------------------------------------+
#property copyright "Gridzilla Project"
#property version   "1.00"
#property strict

#include "..\..\src\utils\TimeUtils.mqh"
#include "..\TestAssertions.mqh"

//+------------------------------------------------------------------+
//| RunTimeUtilsTests - Kör alla TimeUtils-tester                     |
//+------------------------------------------------------------------+
void RunTimeUtilsTests() {
    BeginTestSuite("TimeUtils");

    //=== Session Tests ===
    BeginTest("GetCurrentSession_EuropeanHours_ReturnsEuropean");
    {
        // 10:00 UTC = European session (07:00-16:00, ej overlap)
        datetime test_time = StringToTime("2025-01-15 10:00:00");
        ENUM_TRADING_SESSION session = CTimeUtils::GetCurrentSession(test_time);
        AssertEqual((int)SESSION_EUROPEAN, (int)session, "10:00 UTC should be European");
    }
    EndTest();

    BeginTest("GetCurrentSession_AsianHours_ReturnsAsian");
    {
        // 03:00 UTC = Asian session (00:00-09:00)
        datetime test_time = StringToTime("2025-01-15 03:00:00");
        ENUM_TRADING_SESSION session = CTimeUtils::GetCurrentSession(test_time);
        AssertEqual((int)SESSION_ASIAN, (int)session, "03:00 UTC should be Asian");
    }
    EndTest();

    BeginTest("GetCurrentSession_AmericanHours_ReturnsAmerican");
    {
        // 18:00 UTC = American session (13:00-22:00, ej overlap)
        datetime test_time = StringToTime("2025-01-15 18:00:00");
        ENUM_TRADING_SESSION session = CTimeUtils::GetCurrentSession(test_time);
        AssertEqual((int)SESSION_AMERICAN, (int)session, "18:00 UTC should be American");
    }
    EndTest();

    BeginTest("GetCurrentSession_OverlapHours_ReturnsOverlap");
    {
        // 14:00 UTC = EU/US Overlap (13:00-16:00)
        datetime test_time = StringToTime("2025-01-15 14:00:00");
        ENUM_TRADING_SESSION session = CTimeUtils::GetCurrentSession(test_time);
        AssertEqual((int)SESSION_OVERLAP_EU_US, (int)session, "14:00 UTC should be Overlap");
    }
    EndTest();

    BeginTest("GetCurrentSession_OffHours_ReturnsOffHours");
    {
        // 23:00 UTC = Off hours (after 22:00)
        datetime test_time = StringToTime("2025-01-15 23:00:00");
        ENUM_TRADING_SESSION session = CTimeUtils::GetCurrentSession(test_time);
        AssertEqual((int)SESSION_OFF_HOURS, (int)session, "23:00 UTC should be Off Hours");
    }
    EndTest();

    BeginTest("SessionToString_AllSessions_ReturnsCorrectNames");
    {
        AssertEqual("Asian", CTimeUtils::SessionToString(SESSION_ASIAN));
        AssertEqual("European", CTimeUtils::SessionToString(SESSION_EUROPEAN));
        AssertEqual("American", CTimeUtils::SessionToString(SESSION_AMERICAN));
        AssertEqual("EU/US Overlap", CTimeUtils::SessionToString(SESSION_OVERLAP_EU_US));
        AssertEqual("Off Hours", CTimeUtils::SessionToString(SESSION_OFF_HOURS));
    }
    EndTest();

    //=== Weekend Tests ===
    BeginTest("IsWeekend_Saturday_ReturnsTrue");
    {
        // 2025-01-18 är en lördag
        datetime saturday = StringToTime("2025-01-18 12:00:00");
        AssertTrue(CTimeUtils::IsWeekend(saturday), "Saturday should be weekend");
    }
    EndTest();

    BeginTest("IsWeekend_Sunday_ReturnsTrue");
    {
        // 2025-01-19 är en söndag
        datetime sunday = StringToTime("2025-01-19 12:00:00");
        AssertTrue(CTimeUtils::IsWeekend(sunday), "Sunday should be weekend");
    }
    EndTest();

    BeginTest("IsWeekend_Wednesday_ReturnsFalse");
    {
        // 2025-01-15 är en onsdag
        datetime wednesday = StringToTime("2025-01-15 12:00:00");
        AssertFalse(CTimeUtils::IsWeekend(wednesday), "Wednesday should not be weekend");
    }
    EndTest();

    BeginTest("IsWeekend_Friday_ReturnsFalse");
    {
        // 2025-01-17 är en fredag
        datetime friday = StringToTime("2025-01-17 12:00:00");
        AssertFalse(CTimeUtils::IsWeekend(friday), "Friday should not be weekend");
    }
    EndTest();

    //=== Friday Close Tests ===
    BeginTest("IsFridayClose_FridayAfter21_ReturnsTrue");
    {
        // Fredag 22:00
        datetime friday_late = StringToTime("2025-01-17 22:00:00");
        AssertTrue(CTimeUtils::IsFridayClose(friday_late, 21), "Friday 22:00 should be close");
    }
    EndTest();

    BeginTest("IsFridayClose_FridayBefore21_ReturnsFalse");
    {
        // Fredag 15:00
        datetime friday_early = StringToTime("2025-01-17 15:00:00");
        AssertFalse(CTimeUtils::IsFridayClose(friday_early, 21), "Friday 15:00 should not be close");
    }
    EndTest();

    BeginTest("IsFridayClose_ThursdayLate_ReturnsFalse");
    {
        // Torsdag 22:00 (inte fredag)
        datetime thursday_late = StringToTime("2025-01-16 22:00:00");
        AssertFalse(CTimeUtils::IsFridayClose(thursday_late, 21), "Thursday should not be Friday close");
    }
    EndTest();

    //=== Weekend Lockout Tests ===
    BeginTest("IsWeekendLockout_FridayAfter21_ReturnsTrue");
    {
        datetime friday_close = StringToTime("2025-01-17 21:30:00");
        AssertTrue(CTimeUtils::IsWeekendLockout(friday_close), "Friday after 21:00 should be lockout");
    }
    EndTest();

    BeginTest("IsWeekendLockout_Saturday_ReturnsTrue");
    {
        datetime saturday = StringToTime("2025-01-18 12:00:00");
        AssertTrue(CTimeUtils::IsWeekendLockout(saturday), "Saturday should be lockout");
    }
    EndTest();

    BeginTest("IsWeekendLockout_SundayAfter22_ReturnsFalse");
    {
        // Söndag 23:00 (efter öppning)
        datetime sunday_open = StringToTime("2025-01-19 23:00:00");
        AssertFalse(CTimeUtils::IsWeekendLockout(sunday_open), "Sunday after 22:00 should not be lockout");
    }
    EndTest();

    //=== Time Component Tests ===
    BeginTest("GetHourUTC_Returns Correct Hour");
    {
        datetime time = StringToTime("2025-01-15 14:30:00");
        int hour = CTimeUtils::GetHourUTC(time);
        AssertEqual(14, hour, "Hour should be 14");
    }
    EndTest();

    BeginTest("GetMinuteOfDay_ReturnsCorrectMinute");
    {
        // 14:30 = 14*60 + 30 = 870 minuter
        datetime time = StringToTime("2025-01-15 14:30:00");
        int minute = CTimeUtils::GetMinuteOfDay(time);
        AssertEqual(870, minute, "14:30 should be 870 minutes of day");
    }
    EndTest();

    BeginTest("GetDayOfWeek_Wednesday_Returns3");
    {
        // 2025-01-15 är onsdag (3)
        datetime wednesday = StringToTime("2025-01-15 12:00:00");
        int dow = CTimeUtils::GetDayOfWeek(wednesday);
        AssertEqual(3, dow, "Wednesday should be day 3");
    }
    EndTest();

    BeginTest("GetDayOfWeek_Sunday_Returns0");
    {
        // 2025-01-19 är söndag (0)
        datetime sunday = StringToTime("2025-01-19 12:00:00");
        int dow = CTimeUtils::GetDayOfWeek(sunday);
        AssertEqual(0, dow, "Sunday should be day 0");
    }
    EndTest();

    //=== Start of Day/Week Tests ===
    BeginTest("GetStartOfDay_RemovesTimeComponent");
    {
        datetime time = StringToTime("2025-01-15 14:30:45");
        datetime start = CTimeUtils::GetStartOfDay(time);
        datetime expected = StringToTime("2025-01-15 00:00:00");
        AssertEqual((long)expected, (long)start, "Start of day should be 00:00:00");
    }
    EndTest();

    //=== Duration Tests ===
    BeginTest("GetBarDurationHours_H1_Returns1");
    {
        double hours = CTimeUtils::GetBarDurationHours(PERIOD_H1);
        AssertNear(1.0, hours, 0.0001, "H1 should be 1 hour");
    }
    EndTest();

    BeginTest("GetBarDurationHours_H4_Returns4");
    {
        double hours = CTimeUtils::GetBarDurationHours(PERIOD_H4);
        AssertNear(4.0, hours, 0.0001, "H4 should be 4 hours");
    }
    EndTest();

    BeginTest("GetBarDurationMinutes_M15_Returns15");
    {
        double minutes = CTimeUtils::GetBarDurationMinutes(PERIOD_M15);
        AssertNear(15.0, minutes, 0.0001, "M15 should be 15 minutes");
    }
    EndTest();

    //=== FormatDuration Tests ===
    BeginTest("FormatDuration_UnderOneHour_ReturnsMinutesSeconds");
    {
        string result = CTimeUtils::FormatDuration(125);  // 2:05
        AssertEqual("2:05", result, "125 seconds should be 2:05");
    }
    EndTest();

    BeginTest("FormatDuration_UnderOneDay_ReturnsHoursMinutesSeconds");
    {
        string result = CTimeUtils::FormatDuration(3665);  // 1:01:05
        AssertEqual("1:01:05", result, "3665 seconds should be 1:01:05");
    }
    EndTest();

    BeginTest("FormatDuration_OverOneDay_ReturnsDaysHoursMinutesSeconds");
    {
        string result = CTimeUtils::FormatDuration(90061);  // 1d 01:01:01
        AssertEqual("1d 01:01:01", result, "90061 seconds should include days");
    }
    EndTest();

    //=== GetTimeDifferenceHours Tests ===
    BeginTest("GetTimeDifferenceHours_OneHourApart_Returns1");
    {
        datetime t1 = StringToTime("2025-01-15 10:00:00");
        datetime t2 = StringToTime("2025-01-15 11:00:00");
        double hours = CTimeUtils::GetTimeDifferenceHours(t1, t2);
        AssertNear(1.0, hours, 0.0001, "One hour difference");
    }
    EndTest();

    BeginTest("GetTimeDifferenceHours_OneDayApart_Returns24");
    {
        datetime t1 = StringToTime("2025-01-15 10:00:00");
        datetime t2 = StringToTime("2025-01-16 10:00:00");
        double hours = CTimeUtils::GetTimeDifferenceHours(t1, t2);
        AssertNear(24.0, hours, 0.0001, "24 hours difference");
    }
    EndTest();

    //=== Session Active Tests ===
    BeginTest("IsSessionActive_EuropeanDuringEuropean_ReturnsTrue");
    {
        datetime time = StringToTime("2025-01-15 10:00:00");
        AssertTrue(CTimeUtils::IsSessionActive(SESSION_EUROPEAN, time),
                   "European should be active at 10:00");
    }
    EndTest();

    BeginTest("IsSessionActive_AsianDuringEuropean_ReturnsFalse");
    {
        datetime time = StringToTime("2025-01-15 12:00:00");
        AssertFalse(CTimeUtils::IsSessionActive(SESSION_ASIAN, time),
                    "Asian should not be active at 12:00");
    }
    EndTest();

    EndTestSuite();
}

//+------------------------------------------------------------------+
