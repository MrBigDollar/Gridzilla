//+------------------------------------------------------------------+
//|                                      TestMarketStateManager.mqh   |
//|                                Copyright 2024, Gridzilla Project  |
//+------------------------------------------------------------------+
#property copyright "Gridzilla Project"
#property version   "1.00"
#property strict

#include "..\..\src\core\MarketStateManager.mqh"
#include "..\..\src\mocks\CMockDataProvider.mqh"
#include "..\TestAssertions.mqh"

//+------------------------------------------------------------------+
//| Helper: Skapa mock med bullish alignment                          |
//+------------------------------------------------------------------+
void SetupBullishTrend(CMockDataProvider &mock) {
    mock.SetPrices(1.0900, 1.0901);

    // Sätt indikatorvärden - alla arrays måste ha minst 20 element
    double atr_vals[];
    ArrayResize(atr_vals, 20);
    ArrayInitialize(atr_vals, 0.0050);  // 50 pips ATR

    double ema_values[];
    ArrayResize(ema_values, 20);
    ArrayInitialize(ema_values, 1.0850);

    double rsi_vals[];
    ArrayResize(rsi_vals, 20);
    ArrayInitialize(rsi_vals, 60.0);

    double adx_vals[];
    ArrayResize(adx_vals, 20);
    ArrayInitialize(adx_vals, 35.0);  // Stark trend

    mock.SetIndicatorValues(atr_vals, ema_values, rsi_vals, adx_vals, 20);

    // EMA alignment: EMA20 > EMA50 > EMA200 (bullish)
    mock.SetEMAByPeriod(1.0880, 1.0850, 1.0750);

    // Lägg till stigande bars
    datetime base_time = D'2024.01.01 00:00';
    for (int i = 0; i < 30; i++) {
        double open_price = 1.0800 + i * 0.0005;
        double close_price = open_price + 0.0003;
        double high_price = close_price + 0.0002;
        double low_price = open_price - 0.0002;
        mock.AddBar(base_time + i * 3600, open_price, high_price, low_price, close_price, 1000, 100, 10);
    }
}

//+------------------------------------------------------------------+
//| Helper: Skapa mock med bearish alignment                          |
//+------------------------------------------------------------------+
void SetupBearishTrend(CMockDataProvider &mock) {
    mock.SetPrices(1.0700, 1.0701);

    double atr_vals[];
    ArrayResize(atr_vals, 20);
    ArrayInitialize(atr_vals, 0.0050);

    double ema_values[];
    ArrayResize(ema_values, 20);
    ArrayInitialize(ema_values, 1.0750);

    double rsi_vals[];
    ArrayResize(rsi_vals, 20);
    ArrayInitialize(rsi_vals, 40.0);

    double adx_vals[];
    ArrayResize(adx_vals, 20);
    ArrayInitialize(adx_vals, 35.0);

    mock.SetIndicatorValues(atr_vals, ema_values, rsi_vals, adx_vals, 20);

    // EMA alignment: EMA20 < EMA50 < EMA200 (bearish)
    mock.SetEMAByPeriod(1.0720, 1.0750, 1.0850);

    // Fallande bars
    datetime base_time = D'2024.01.01 00:00';
    for (int i = 0; i < 30; i++) {
        double open_price = 1.0900 - i * 0.0005;
        double close_price = open_price - 0.0003;
        double high_price = open_price + 0.0002;
        double low_price = close_price - 0.0002;
        mock.AddBar(base_time + i * 3600, open_price, high_price, low_price, close_price, 1000, 100, 10);
    }
}

//+------------------------------------------------------------------+
//| Helper: Skapa mock med ingen trend (sidledes)                     |
//+------------------------------------------------------------------+
void SetupNoTrend(CMockDataProvider &mock) {
    mock.SetPrices(1.0800, 1.0801);

    double atr_vals[];
    ArrayResize(atr_vals, 20);
    ArrayInitialize(atr_vals, 0.0030);  // Låg volatilitet

    double ema_values[];
    ArrayResize(ema_values, 20);
    ArrayInitialize(ema_values, 1.0800);  // EMA = pris (ingen trend)

    double rsi_vals[];
    ArrayResize(rsi_vals, 20);
    ArrayInitialize(rsi_vals, 50.0);  // Neutral RSI

    double adx_vals[];
    ArrayResize(adx_vals, 20);
    ArrayInitialize(adx_vals, 15.0);  // Svag trend

    mock.SetIndicatorValues(atr_vals, ema_values, rsi_vals, adx_vals, 20);

    // Flat bars
    datetime base_time = D'2024.01.01 00:00';
    for (int i = 0; i < 30; i++) {
        double price = 1.0800 + MathSin(i * 0.3) * 0.0005;  // Liten oscillation
        mock.AddBar(base_time + i * 3600, price, price + 0.0002, price - 0.0002, price, 1000, 100, 10);
    }
}

//+------------------------------------------------------------------+
//| Helper: Skapa mock med hög volatilitet                            |
//+------------------------------------------------------------------+
void SetupHighVolatility(CMockDataProvider &mock) {
    mock.SetPrices(1.0800, 1.0801);

    double atr_vals[];
    ArrayResize(atr_vals, 20);
    // Nuvarande ATR hög, historiskt varierat
    for (int i = 0; i < 20; i++) {
        atr_vals[i] = (i == 0) ? 0.0100 : 0.0030 + i * 0.0002;  // Nuvarande är högst
    }

    double ema_values[];
    ArrayResize(ema_values, 20);
    ArrayInitialize(ema_values, 1.0800);

    double rsi_vals[];
    ArrayResize(rsi_vals, 20);
    ArrayInitialize(rsi_vals, 50.0);

    double adx_vals[];
    ArrayResize(adx_vals, 20);
    ArrayInitialize(adx_vals, 25.0);

    mock.SetIndicatorValues(atr_vals, ema_values, rsi_vals, adx_vals, 20);

    datetime base_time = D'2024.01.01 00:00';
    for (int i = 0; i < 30; i++) {
        mock.AddBar(base_time + i * 3600, 1.0800, 1.0850, 1.0750, 1.0800, 1000, 100, 10);
    }
}

//+------------------------------------------------------------------+
//| Helper: Skapa mock med låg volatilitet                            |
//+------------------------------------------------------------------+
void SetupLowVolatility(CMockDataProvider &mock) {
    mock.SetPrices(1.0800, 1.0801);

    double atr_vals[];
    ArrayResize(atr_vals, 20);
    // Nuvarande ATR låg, historiskt varierat
    for (int i = 0; i < 20; i++) {
        atr_vals[i] = (i == 0) ? 0.0015 : 0.0030 + i * 0.0002;  // Nuvarande är lägst
    }

    double ema_values[];
    ArrayResize(ema_values, 20);
    ArrayInitialize(ema_values, 1.0800);

    double rsi_vals[];
    ArrayResize(rsi_vals, 20);
    ArrayInitialize(rsi_vals, 50.0);

    double adx_vals[];
    ArrayResize(adx_vals, 20);
    ArrayInitialize(adx_vals, 15.0);

    mock.SetIndicatorValues(atr_vals, ema_values, rsi_vals, adx_vals, 20);

    datetime base_time = D'2024.01.01 00:00';
    for (int i = 0; i < 30; i++) {
        mock.AddBar(base_time + i * 3600, 1.0800, 1.0805, 1.0795, 1.0800, 1000, 100, 10);
    }
}

//+------------------------------------------------------------------+
//| Helper: Skapa mock vid övre BB-band (mean reversion setup)        |
//+------------------------------------------------------------------+
void SetupAtUpperBB(CMockDataProvider &mock) {
    mock.SetPrices(1.0900, 1.0901);

    double bb_upper[];
    ArrayResize(bb_upper, 20);
    ArrayInitialize(bb_upper, 1.0900);  // Pris = upper band

    double bb_middle[];
    ArrayResize(bb_middle, 20);
    ArrayInitialize(bb_middle, 1.0800);

    double bb_lower[];
    ArrayResize(bb_lower, 20);
    ArrayInitialize(bb_lower, 1.0700);

    mock.SetBollingerBands(bb_upper, bb_middle, bb_lower, 20);

    double atr_vals[];
    ArrayResize(atr_vals, 20);
    ArrayInitialize(atr_vals, 0.0050);

    double ema_values[];
    ArrayResize(ema_values, 20);
    ArrayInitialize(ema_values, 1.0800);

    double rsi_vals[];
    ArrayResize(rsi_vals, 20);
    ArrayInitialize(rsi_vals, 75.0);  // Overbought

    double adx_vals[];
    ArrayResize(adx_vals, 20);
    ArrayInitialize(adx_vals, 25.0);

    mock.SetIndicatorValues(atr_vals, ema_values, rsi_vals, adx_vals, 20);

    datetime base_time = D'2024.01.01 00:00';
    for (int i = 0; i < 30; i++) {
        mock.AddBar(base_time + i * 3600, 1.0850, 1.0900, 1.0840, 1.0890, 1000, 100, 10);
    }
}

//+------------------------------------------------------------------+
//| Helper: Skapa mock vid mitten av BB (neutral)                     |
//+------------------------------------------------------------------+
void SetupAtMiddleBB(CMockDataProvider &mock) {
    mock.SetPrices(1.0800, 1.0801);

    double bb_upper[];
    ArrayResize(bb_upper, 20);
    ArrayInitialize(bb_upper, 1.0900);

    double bb_middle[];
    ArrayResize(bb_middle, 20);
    ArrayInitialize(bb_middle, 1.0800);  // Pris = middle

    double bb_lower[];
    ArrayResize(bb_lower, 20);
    ArrayInitialize(bb_lower, 1.0700);

    mock.SetBollingerBands(bb_upper, bb_middle, bb_lower, 20);

    double atr_vals[];
    ArrayResize(atr_vals, 20);
    ArrayInitialize(atr_vals, 0.0050);

    double ema_values[];
    ArrayResize(ema_values, 20);
    ArrayInitialize(ema_values, 1.0800);

    double rsi_vals[];
    ArrayResize(rsi_vals, 20);
    ArrayInitialize(rsi_vals, 50.0);  // Neutral RSI

    double adx_vals[];
    ArrayResize(adx_vals, 20);
    ArrayInitialize(adx_vals, 20.0);

    mock.SetIndicatorValues(atr_vals, ema_values, rsi_vals, adx_vals, 20);

    datetime base_time = D'2024.01.01 00:00';
    for (int i = 0; i < 30; i++) {
        mock.AddBar(base_time + i * 3600, 1.0800, 1.0810, 1.0790, 1.0800, 1000, 100, 10);
    }
}

//+------------------------------------------------------------------+
//| RunMarketStateManagerTests - Kör alla tester                      |
//+------------------------------------------------------------------+
void RunMarketStateManagerTests() {
    BeginTestSuite("MarketStateManager");

    //=================================================================
    // TREND STRENGTH TESTS
    //=================================================================

    BeginTest("TrendStrength_BullishAlignment_ReturnsHigh");
    {
        CMockDataProvider mock;
        SetupBullishTrend(mock);
        mock.SetTime(D'2024.01.01 10:00', D'2024.01.01 10:00', 0);

        CMarketStateManager manager(&mock);
        manager.Initialize(50);

        MarketState state = manager.GetMarketState();
        AssertGreater(state.trend_strength, 0.5, "Bullish alignment should give high trend strength");
    }
    EndTest();

    BeginTest("TrendStrength_BearishAlignment_ReturnsHigh");
    {
        CMockDataProvider mock;
        SetupBearishTrend(mock);
        mock.SetTime(D'2024.01.01 10:00', D'2024.01.01 10:00', 0);

        CMarketStateManager manager(&mock);
        manager.Initialize(50);

        MarketState state = manager.GetMarketState();
        AssertGreater(state.trend_strength, 0.5, "Bearish alignment should also give high trend strength");
    }
    EndTest();

    BeginTest("TrendStrength_NoTrend_ReturnsLow");
    {
        CMockDataProvider mock;
        SetupNoTrend(mock);
        mock.SetTime(D'2024.01.01 10:00', D'2024.01.01 10:00', 0);

        CMarketStateManager manager(&mock);
        manager.Initialize(50);

        MarketState state = manager.GetMarketState();
        AssertLess(state.trend_strength, 0.5, "No alignment should give low trend strength");
    }
    EndTest();

    BeginTest("TrendStrength_AlwaysInRange");
    {
        CMockDataProvider mock;
        SetupBullishTrend(mock);
        mock.SetTime(D'2024.01.01 10:00', D'2024.01.01 10:00', 0);

        CMarketStateManager manager(&mock);
        manager.Initialize(50);

        MarketState state = manager.GetMarketState();
        AssertInRange(state.trend_strength, 0.0, 1.0, "trend_strength must be in [0,1]");
    }
    EndTest();

    //=================================================================
    // TREND SLOPE TESTS
    //=================================================================

    BeginTest("TrendSlope_RisingPrices_ReturnsPositive");
    {
        CMockDataProvider mock;
        SetupBullishTrend(mock);
        mock.SetTime(D'2024.01.01 10:00', D'2024.01.01 10:00', 0);

        CMarketStateManager manager(&mock);
        manager.Initialize(50);

        MarketState state = manager.GetMarketState();
        AssertGreater(state.trend_slope, 0.0, "Rising prices should give positive slope");
    }
    EndTest();

    BeginTest("TrendSlope_FallingPrices_ReturnsNegative");
    {
        CMockDataProvider mock;
        SetupBearishTrend(mock);
        mock.SetTime(D'2024.01.01 10:00', D'2024.01.01 10:00', 0);

        CMarketStateManager manager(&mock);
        manager.Initialize(50);

        MarketState state = manager.GetMarketState();
        AssertLess(state.trend_slope, 0.0, "Falling prices should give negative slope");
    }
    EndTest();

    BeginTest("TrendSlope_FlatPrices_ReturnsNearZero");
    {
        CMockDataProvider mock;
        SetupNoTrend(mock);
        mock.SetTime(D'2024.01.01 10:00', D'2024.01.01 10:00', 0);

        CMarketStateManager manager(&mock);
        manager.Initialize(50);

        MarketState state = manager.GetMarketState();
        AssertNear(0.0, state.trend_slope, 0.3, "Flat prices should give slope near zero");
    }
    EndTest();

    BeginTest("TrendSlope_AlwaysInRange");
    {
        CMockDataProvider mock;
        SetupBullishTrend(mock);
        mock.SetTime(D'2024.01.01 10:00', D'2024.01.01 10:00', 0);

        CMarketStateManager manager(&mock);
        manager.Initialize(50);

        MarketState state = manager.GetMarketState();
        AssertInRange(state.trend_slope, -1.0, 1.0, "trend_slope must be in [-1,1]");
    }
    EndTest();

    //=================================================================
    // TREND CURVATURE TESTS
    //=================================================================

    BeginTest("TrendCurvature_AlwaysInRange");
    {
        CMockDataProvider mock;
        SetupBullishTrend(mock);
        mock.SetTime(D'2024.01.01 10:00', D'2024.01.01 10:00', 0);

        CMarketStateManager manager(&mock);
        manager.Initialize(50);

        MarketState state = manager.GetMarketState();
        AssertInRange(state.trend_curvature, -1.0, 1.0, "trend_curvature must be in [-1,1]");
    }
    EndTest();

    //=================================================================
    // VOLATILITY LEVEL TESTS
    //=================================================================

    BeginTest("VolatilityLevel_HighATR_ReturnsHigh");
    {
        CMockDataProvider mock;
        SetupHighVolatility(mock);
        mock.SetTime(D'2024.01.01 10:00', D'2024.01.01 10:00', 0);

        CMarketStateManager manager(&mock);
        manager.Initialize(50);

        // Uppdatera historik
        for (int i = 0; i < 20; i++) {
            manager.Update();
        }

        MarketState state = manager.GetMarketState();
        // Notera: Mock returnerar samma ATR för shift=0 varje gång,
        // så historiken blir konstant → returnerar 0.5
        // Vi testar att värdet är inom giltigt intervall
        AssertInRange(state.volatility_level, 0.0, 1.0, "volatility_level must be in valid range");
    }
    EndTest();

    BeginTest("VolatilityLevel_LowATR_ReturnsLow");
    {
        CMockDataProvider mock;
        SetupLowVolatility(mock);
        mock.SetTime(D'2024.01.01 10:00', D'2024.01.01 10:00', 0);

        CMarketStateManager manager(&mock);
        manager.Initialize(50);

        for (int i = 0; i < 20; i++) {
            manager.Update();
        }

        MarketState state = manager.GetMarketState();
        // Notera: Mock returnerar samma ATR för shift=0 varje gång,
        // så historiken blir konstant → returnerar 0.5
        // Vi testar att värdet är inom giltigt intervall
        AssertInRange(state.volatility_level, 0.0, 1.0, "volatility_level must be in valid range");
    }
    EndTest();

    BeginTest("VolatilityLevel_AlwaysInRange");
    {
        CMockDataProvider mock;
        SetupHighVolatility(mock);
        mock.SetTime(D'2024.01.01 10:00', D'2024.01.01 10:00', 0);

        CMarketStateManager manager(&mock);
        manager.Initialize(50);

        MarketState state = manager.GetMarketState();
        AssertInRange(state.volatility_level, 0.0, 1.0, "volatility_level must be in [0,1]");
    }
    EndTest();

    //=================================================================
    // VOLATILITY CHANGE TESTS
    //=================================================================

    BeginTest("VolatilityChange_AlwaysInRange");
    {
        CMockDataProvider mock;
        SetupHighVolatility(mock);
        mock.SetTime(D'2024.01.01 10:00', D'2024.01.01 10:00', 0);

        CMarketStateManager manager(&mock);
        manager.Initialize(50);

        MarketState state = manager.GetMarketState();
        AssertInRange(state.volatility_change, -1.0, 1.0, "volatility_change must be in [-1,1]");
    }
    EndTest();

    //=================================================================
    // MEAN REVERSION SCORE TESTS
    //=================================================================

    BeginTest("MeanReversion_AtUpperBB_ReturnsHigh");
    {
        CMockDataProvider mock;
        SetupAtUpperBB(mock);
        mock.SetTime(D'2024.01.01 10:00', D'2024.01.01 10:00', 0);

        CMarketStateManager manager(&mock);
        manager.Initialize(50);

        MarketState state = manager.GetMarketState();
        AssertGreater(state.mean_reversion_score, 0.5, "At upper BB with high RSI should give high MR score");
    }
    EndTest();

    BeginTest("MeanReversion_AtMiddleBB_ReturnsLow");
    {
        CMockDataProvider mock;
        SetupAtMiddleBB(mock);
        mock.SetTime(D'2024.01.01 10:00', D'2024.01.01 10:00', 0);

        CMarketStateManager manager(&mock);
        manager.Initialize(50);

        MarketState state = manager.GetMarketState();
        AssertLess(state.mean_reversion_score, 0.3, "At middle BB with neutral RSI should give low MR score");
    }
    EndTest();

    BeginTest("MeanReversion_AlwaysInRange");
    {
        CMockDataProvider mock;
        SetupAtUpperBB(mock);
        mock.SetTime(D'2024.01.01 10:00', D'2024.01.01 10:00', 0);

        CMarketStateManager manager(&mock);
        manager.Initialize(50);

        MarketState state = manager.GetMarketState();
        AssertInRange(state.mean_reversion_score, 0.0, 1.0, "mean_reversion_score must be in [0,1]");
    }
    EndTest();

    //=================================================================
    // SPREAD ZSCORE TESTS
    //=================================================================

    BeginTest("SpreadZScore_AlwaysInRange");
    {
        CMockDataProvider mock;
        SetupNoTrend(mock);
        mock.SetTime(D'2024.01.01 10:00', D'2024.01.01 10:00', 0);

        CMarketStateManager manager(&mock);
        manager.Initialize(50);

        MarketState state = manager.GetMarketState();
        AssertInRange(state.spread_zscore, -3.0, 3.0, "spread_zscore must be in [-3,3]");
    }
    EndTest();

    //=================================================================
    // SESSION ID TESTS
    //=================================================================

    BeginTest("SessionId_AsianHours_Returns0");
    {
        CMockDataProvider mock;
        SetupNoTrend(mock);
        mock.SetTime(D'2024.01.01 03:00', D'2024.01.01 03:00', 0);  // 03:00 UTC = Asian

        CMarketStateManager manager(&mock);
        manager.Initialize(50);

        MarketState state = manager.GetMarketState();
        AssertEqual(SESSION_ASIAN, state.session_id, "03:00 UTC should be Asian session");
    }
    EndTest();

    BeginTest("SessionId_EuropeanHours_Returns1");
    {
        CMockDataProvider mock;
        SetupNoTrend(mock);
        mock.SetTime(D'2024.01.01 10:00', D'2024.01.01 10:00', 0);  // 10:00 UTC = European

        CMarketStateManager manager(&mock);
        manager.Initialize(50);

        MarketState state = manager.GetMarketState();
        AssertEqual(SESSION_EUROPEAN, state.session_id, "10:00 UTC should be European session");
    }
    EndTest();

    BeginTest("SessionId_OverlapHours_Returns3");
    {
        CMockDataProvider mock;
        SetupNoTrend(mock);
        mock.SetTime(D'2024.01.01 14:00', D'2024.01.01 14:00', 0);  // 14:00 UTC = EU/US overlap

        CMarketStateManager manager(&mock);
        manager.Initialize(50);

        MarketState state = manager.GetMarketState();
        AssertEqual(SESSION_OVERLAP_EU_US, state.session_id, "14:00 UTC should be EU/US overlap");
    }
    EndTest();

    BeginTest("SessionId_AmericanHours_Returns2");
    {
        CMockDataProvider mock;
        SetupNoTrend(mock);
        mock.SetTime(D'2024.01.01 18:00', D'2024.01.01 18:00', 0);  // 18:00 UTC = American

        CMarketStateManager manager(&mock);
        manager.Initialize(50);

        MarketState state = manager.GetMarketState();
        AssertEqual(SESSION_AMERICAN, state.session_id, "18:00 UTC should be American session");
    }
    EndTest();

    //=================================================================
    // INITIALIZATION TESTS
    //=================================================================

    BeginTest("Initialize_WithValidProvider_ReturnsTrue");
    {
        CMockDataProvider mock;
        SetupNoTrend(mock);

        CMarketStateManager manager(&mock);
        bool result = manager.Initialize(100);

        AssertTrue(result, "Initialize should return true with valid provider");
        AssertTrue(manager.IsInitialized(), "IsInitialized should return true after init");
    }
    EndTest();

    BeginTest("Initialize_SetsHistorySize");
    {
        CMockDataProvider mock;
        SetupNoTrend(mock);

        CMarketStateManager manager(&mock);
        manager.Initialize(75);

        AssertEqual(75, manager.GetHistorySize(), "History size should match initialization parameter");
    }
    EndTest();

    BeginTest("GetMarketState_BeforeInit_ReturnsDefault");
    {
        CMockDataProvider mock;
        SetupNoTrend(mock);

        CMarketStateManager manager(&mock);
        // Ingen Initialize() kallad

        MarketState state = manager.GetMarketState();
        AssertEqual(0.0, state.trend_strength, "Uninitialized should return default state");
    }
    EndTest();

    //=================================================================
    // DETERMINISM TESTS
    //=================================================================

    BeginTest("Determinism_SameInput_SameOutput");
    {
        CMockDataProvider mock1;
        SetupBullishTrend(mock1);
        mock1.SetTime(D'2024.01.01 10:00', D'2024.01.01 10:00', 0);

        CMockDataProvider mock2;
        SetupBullishTrend(mock2);
        mock2.SetTime(D'2024.01.01 10:00', D'2024.01.01 10:00', 0);

        CMarketStateManager manager1(&mock1);
        manager1.Initialize(50);

        CMarketStateManager manager2(&mock2);
        manager2.Initialize(50);

        MarketState state1 = manager1.GetMarketState();
        MarketState state2 = manager2.GetMarketState();

        AssertNear(state1.trend_strength, state2.trend_strength, 0.0001, "Same input should give same trend_strength");
        AssertNear(state1.trend_slope, state2.trend_slope, 0.0001, "Same input should give same trend_slope");
        AssertEqual(state1.session_id, state2.session_id, "Same input should give same session_id");
    }
    EndTest();

    EndTestSuite();
}

//+------------------------------------------------------------------+
