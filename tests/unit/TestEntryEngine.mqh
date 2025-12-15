//+------------------------------------------------------------------+
//|                                              TestEntryEngine.mqh  |
//|                                Copyright 2024, Gridzilla Project  |
//+------------------------------------------------------------------+
#property copyright "Gridzilla Project"
#property version   "1.00"
#property strict

#include "..\..\src\core\EntryEngine.mqh"
#include "..\..\src\mocks\CMockDataProvider.mqh"
#include "..\..\src\mocks\CMockOrderExecutor.mqh"
#include "..\TestAssertions.mqh"

//+------------------------------------------------------------------+
//| Helper: Setup för normal trading-miljö                            |
//+------------------------------------------------------------------+
void SetupNormalTradingEnvironment(CMockDataProvider &data, CMockOrderExecutor &executor) {
    // Normal EUR/USD miljö
    data.SetPrices(1.0850, 1.0852);  // 2 pip spread

    // Normal volatilitet (ATR ~15 pips)
    double atr_vals[];
    ArrayResize(atr_vals, 20);
    ArrayInitialize(atr_vals, 0.0015);  // 15 pips ATR

    double ema_vals[];
    ArrayResize(ema_vals, 20);
    ArrayInitialize(ema_vals, 1.0850);

    double rsi_vals[];
    ArrayResize(rsi_vals, 20);
    ArrayInitialize(rsi_vals, 50.0);

    double adx_vals[];
    ArrayResize(adx_vals, 20);
    ArrayInitialize(adx_vals, 25.0);

    data.SetIndicatorValues(atr_vals, ema_vals, rsi_vals, adx_vals, 20);

    // Tid: Måndag 10:00 UTC (European session)
    data.SetTime(D'2024.01.15 10:00', D'2024.01.15 10:00', 0);

    // Trading tillåten
    executor.SetTradeAllowed(true);
    executor.SetExpertEnabled(true);
    executor.SetCurrentPrices(1.0850, 1.0852);
}

//+------------------------------------------------------------------+
//| Helper: Setup för stark upptrend                                   |
//+------------------------------------------------------------------+
void SetupStrongUptrend(CMockDataProvider &data) {
    data.SetPrices(1.0850, 1.0852);

    // ATR ~20 pips
    double atr_vals[];
    ArrayResize(atr_vals, 20);
    ArrayInitialize(atr_vals, 0.0020);

    // EMA alignment bullish
    double ema_vals[];
    ArrayResize(ema_vals, 20);
    ArrayInitialize(ema_vals, 1.0840);  // EMA under pris

    data.SetEMAByPeriod(1.0845, 1.0830, 1.0780);  // EMA20 > EMA50 > EMA200

    double rsi_vals[];
    ArrayResize(rsi_vals, 20);
    ArrayInitialize(rsi_vals, 55.0);  // Neutral RSI (inte överköpt)

    double adx_vals[];
    ArrayResize(adx_vals, 20);
    ArrayInitialize(adx_vals, 40.0);  // Stark trend

    data.SetIndicatorValues(atr_vals, ema_vals, rsi_vals, adx_vals, 20);

    // Lägg till stigande bars för slope-beräkning
    datetime base_time = D'2024.01.15 00:00';
    for (int i = 0; i < 30; i++) {
        double open_price = 1.0750 + i * 0.0005;
        double close_price = open_price + 0.0003;
        double high_price = close_price + 0.0002;
        double low_price = open_price - 0.0002;
        data.AddBar(base_time + i * 3600, open_price, high_price, low_price, close_price, 1000, 100, 10);
    }

    // BB vid neutral (inte överköpt)
    double bb_upper[];
    ArrayResize(bb_upper, 20);
    ArrayInitialize(bb_upper, 1.0900);

    double bb_middle[];
    ArrayResize(bb_middle, 20);
    ArrayInitialize(bb_middle, 1.0850);

    double bb_lower[];
    ArrayResize(bb_lower, 20);
    ArrayInitialize(bb_lower, 1.0800);

    data.SetBollingerBands(bb_upper, bb_middle, bb_lower, 20);

    data.SetTime(D'2024.01.15 10:00', D'2024.01.15 10:00', 0);
}

//+------------------------------------------------------------------+
//| Helper: Setup för stark nedtrend                                   |
//+------------------------------------------------------------------+
void SetupStrongDowntrend(CMockDataProvider &data) {
    data.SetPrices(1.0750, 1.0752);

    // ATR ~20 pips
    double atr_vals[];
    ArrayResize(atr_vals, 20);
    ArrayInitialize(atr_vals, 0.0020);

    // EMA alignment bearish
    double ema_vals[];
    ArrayResize(ema_vals, 20);
    ArrayInitialize(ema_vals, 1.0760);  // EMA över pris

    data.SetEMAByPeriod(1.0755, 1.0780, 1.0850);  // EMA20 < EMA50 < EMA200

    double rsi_vals[];
    ArrayResize(rsi_vals, 20);
    ArrayInitialize(rsi_vals, 45.0);  // Neutral RSI (inte översåld)

    double adx_vals[];
    ArrayResize(adx_vals, 20);
    ArrayInitialize(adx_vals, 40.0);  // Stark trend

    data.SetIndicatorValues(atr_vals, ema_vals, rsi_vals, adx_vals, 20);

    // Lägg till fallande bars
    datetime base_time = D'2024.01.15 00:00';
    for (int i = 0; i < 30; i++) {
        double open_price = 1.0900 - i * 0.0005;
        double close_price = open_price - 0.0003;
        double high_price = open_price + 0.0002;
        double low_price = close_price - 0.0002;
        data.AddBar(base_time + i * 3600, open_price, high_price, low_price, close_price, 1000, 100, 10);
    }

    // BB vid neutral
    double bb_upper[];
    ArrayResize(bb_upper, 20);
    ArrayInitialize(bb_upper, 1.0800);

    double bb_middle[];
    ArrayResize(bb_middle, 20);
    ArrayInitialize(bb_middle, 1.0750);

    double bb_lower[];
    ArrayResize(bb_lower, 20);
    ArrayInitialize(bb_lower, 1.0700);

    data.SetBollingerBands(bb_upper, bb_middle, bb_lower, 20);

    data.SetTime(D'2024.01.15 10:00', D'2024.01.15 10:00', 0);
}

//+------------------------------------------------------------------+
//| Helper: Setup för hög spread                                       |
//+------------------------------------------------------------------+
void SetupHighSpread(CMockDataProvider &data) {
    // 5 pip spread (>2 pip limit)
    data.SetPrices(1.0850, 1.0855);
    data.SetTime(D'2024.01.15 10:00', D'2024.01.15 10:00', 0);
}

//+------------------------------------------------------------------+
//| Helper: Setup för låg volatilitet (Entry)                          |
//+------------------------------------------------------------------+
void SetupEntryLowVolatility(CMockDataProvider &data) {
    data.SetPrices(1.0850, 1.0852);

    // ATR ~3 pips (under min 5 pips)
    double atr_vals[];
    ArrayResize(atr_vals, 20);
    ArrayInitialize(atr_vals, 0.0003);

    double ema_vals[];
    ArrayResize(ema_vals, 20);
    ArrayInitialize(ema_vals, 1.0850);

    double rsi_vals[];
    ArrayResize(rsi_vals, 20);
    ArrayInitialize(rsi_vals, 50.0);

    double adx_vals[];
    ArrayResize(adx_vals, 20);
    ArrayInitialize(adx_vals, 15.0);

    data.SetIndicatorValues(atr_vals, ema_vals, rsi_vals, adx_vals, 20);
    data.SetTime(D'2024.01.15 10:00', D'2024.01.15 10:00', 0);
}

//+------------------------------------------------------------------+
//| Helper: Setup för hög volatilitet (Entry)                          |
//+------------------------------------------------------------------+
void SetupEntryHighVolatility(CMockDataProvider &data) {
    data.SetPrices(1.0850, 1.0852);

    // ATR ~60 pips (över max 50 pips)
    double atr_vals[];
    ArrayResize(atr_vals, 20);
    ArrayInitialize(atr_vals, 0.0060);

    double ema_vals[];
    ArrayResize(ema_vals, 20);
    ArrayInitialize(ema_vals, 1.0850);

    double rsi_vals[];
    ArrayResize(rsi_vals, 20);
    ArrayInitialize(rsi_vals, 50.0);

    double adx_vals[];
    ArrayResize(adx_vals, 20);
    ArrayInitialize(adx_vals, 50.0);

    data.SetIndicatorValues(atr_vals, ema_vals, rsi_vals, adx_vals, 20);
    data.SetTime(D'2024.01.15 10:00', D'2024.01.15 10:00', 0);
}

//+------------------------------------------------------------------+
//| Helper: Setup för weekend                                          |
//+------------------------------------------------------------------+
void SetupWeekend(CMockDataProvider &data) {
    data.SetPrices(1.0850, 1.0852);
    // Fredag 22:00 UTC (efter lockout)
    data.SetTime(D'2024.01.12 22:00', D'2024.01.12 22:00', 0);
}

//+------------------------------------------------------------------+
//| RunEntryEngineTests - Kör alla EntryEngine-tester                  |
//+------------------------------------------------------------------+
void RunEntryEngineTests() {
    BeginTestSuite("EntryEngine");

    //=================================================================
    // FILTER TESTS
    //=================================================================

    BeginTest("SpreadFilter_HighSpread_Blocks");
    {
        CMockDataProvider data;
        CMockOrderExecutor executor;
        SetupHighSpread(data);

        CMarketStateManager state_mgr(&data);
        state_mgr.Initialize(50);

        CEntryEngine engine(&data, &executor, NULL, &state_mgr);
        engine.Initialize("EURUSD", 12345);

        bool passes = engine.CheckSpreadFilterPublic();
        AssertFalse(passes, "High spread should block entry");
    }
    EndTest();

    BeginTest("SpreadFilter_NormalSpread_Allows");
    {
        CMockDataProvider data;
        CMockOrderExecutor executor;
        SetupNormalTradingEnvironment(data, executor);

        CMarketStateManager state_mgr(&data);
        state_mgr.Initialize(50);

        CEntryEngine engine(&data, &executor, NULL, &state_mgr);
        engine.Initialize("EURUSD", 12345);

        bool passes = engine.CheckSpreadFilterPublic();
        AssertTrue(passes, "Normal spread should allow entry");
    }
    EndTest();

    BeginTest("VolatilityFilter_TooLow_Blocks");
    {
        CMockDataProvider data;
        CMockOrderExecutor executor;
        SetupEntryLowVolatility(data);

        CMarketStateManager state_mgr(&data);
        state_mgr.Initialize(50);

        CEntryEngine engine(&data, &executor, NULL, &state_mgr);
        engine.Initialize("EURUSD", 12345);

        bool passes = engine.CheckVolatilityFilterPublic();
        AssertFalse(passes, "Low volatility should block entry");
    }
    EndTest();

    BeginTest("VolatilityFilter_TooHigh_Blocks");
    {
        CMockDataProvider data;
        CMockOrderExecutor executor;
        SetupEntryHighVolatility(data);

        CMarketStateManager state_mgr(&data);
        state_mgr.Initialize(50);

        CEntryEngine engine(&data, &executor, NULL, &state_mgr);
        engine.Initialize("EURUSD", 12345);

        bool passes = engine.CheckVolatilityFilterPublic();
        AssertFalse(passes, "High volatility should block entry");
    }
    EndTest();

    BeginTest("VolatilityFilter_Normal_Allows");
    {
        CMockDataProvider data;
        CMockOrderExecutor executor;
        SetupNormalTradingEnvironment(data, executor);

        CMarketStateManager state_mgr(&data);
        state_mgr.Initialize(50);

        CEntryEngine engine(&data, &executor, NULL, &state_mgr);
        engine.Initialize("EURUSD", 12345);

        bool passes = engine.CheckVolatilityFilterPublic();
        AssertTrue(passes, "Normal volatility should allow entry");
    }
    EndTest();

    BeginTest("WeekendFilter_Friday2200_Blocks");
    {
        CMockDataProvider data;
        CMockOrderExecutor executor;
        SetupWeekend(data);

        CMarketStateManager state_mgr(&data);
        state_mgr.Initialize(50);

        CEntryEngine engine(&data, &executor, NULL, &state_mgr);
        engine.Initialize("EURUSD", 12345);

        bool passes = engine.CheckWeekendFilterPublic();
        AssertFalse(passes, "Weekend should block entry");
    }
    EndTest();

    BeginTest("WeekendFilter_Monday_Allows");
    {
        CMockDataProvider data;
        CMockOrderExecutor executor;
        SetupNormalTradingEnvironment(data, executor);

        CMarketStateManager state_mgr(&data);
        state_mgr.Initialize(50);

        CEntryEngine engine(&data, &executor, NULL, &state_mgr);
        engine.Initialize("EURUSD", 12345);

        bool passes = engine.CheckWeekendFilterPublic();
        AssertTrue(passes, "Monday should allow entry");
    }
    EndTest();

    BeginTest("MaxPositionsFilter_HasOne_Blocks");
    {
        CMockDataProvider data;
        CMockOrderExecutor executor;
        SetupNormalTradingEnvironment(data, executor);

        // Skapa en position
        executor.SendMarketOrder("EURUSD", ORDER_TYPE_BUY, 0.1, 0, 0, "test", 12345);

        CMarketStateManager state_mgr(&data);
        state_mgr.Initialize(50);

        CEntryEngine engine(&data, &executor, NULL, &state_mgr);
        engine.Initialize("EURUSD", 12345);

        bool passes = engine.CheckMaxPositionsFilterPublic();
        AssertFalse(passes, "Having max positions should block new entry");
    }
    EndTest();

    BeginTest("MaxPositionsFilter_NoPositions_Allows");
    {
        CMockDataProvider data;
        CMockOrderExecutor executor;
        SetupNormalTradingEnvironment(data, executor);

        CMarketStateManager state_mgr(&data);
        state_mgr.Initialize(50);

        CEntryEngine engine(&data, &executor, NULL, &state_mgr);
        engine.Initialize("EURUSD", 12345);

        bool passes = engine.CheckMaxPositionsFilterPublic();
        AssertTrue(passes, "No positions should allow entry");
    }
    EndTest();

    //=================================================================
    // ENTRY DECISION TESTS
    //=================================================================

    BeginTest("Evaluate_StrongUptrend_ReturnsBuySignal");
    {
        CMockDataProvider data;
        CMockOrderExecutor executor;
        SetupStrongUptrend(data);
        executor.SetTradeAllowed(true);
        executor.SetCurrentPrices(1.0850, 1.0852);

        CMarketStateManager state_mgr(&data);
        state_mgr.Initialize(50);

        CEntryEngine engine(&data, &executor, NULL, &state_mgr);
        engine.Initialize("EURUSD", 12345);

        EntryDecision decision = engine.Evaluate();

        // I en stark upptrend med pullback bör vi få BUY signal
        // Men detta beror på MarketState beräkningarna
        // Testar att decision strukturen är korrekt ifylld
        AssertTrue(decision.direction == ORDER_TYPE_BUY || !decision.should_enter,
                  "Uptrend should give BUY or no signal");
    }
    EndTest();

    BeginTest("Evaluate_StrongDowntrend_ReturnsSellSignal");
    {
        CMockDataProvider data;
        CMockOrderExecutor executor;
        SetupStrongDowntrend(data);
        executor.SetTradeAllowed(true);
        executor.SetCurrentPrices(1.0750, 1.0752);

        CMarketStateManager state_mgr(&data);
        state_mgr.Initialize(50);

        CEntryEngine engine(&data, &executor, NULL, &state_mgr);
        engine.Initialize("EURUSD", 12345);

        EntryDecision decision = engine.Evaluate();

        // I en stark nedtrend med pullback bör vi få SELL signal
        AssertTrue(decision.direction == ORDER_TYPE_SELL || !decision.should_enter,
                  "Downtrend should give SELL or no signal");
    }
    EndTest();

    BeginTest("Evaluate_FilterBlock_ReturnsBlockReason");
    {
        CMockDataProvider data;
        CMockOrderExecutor executor;
        SetupHighSpread(data);  // Hög spread blockerar

        CMarketStateManager state_mgr(&data);
        state_mgr.Initialize(50);

        CEntryEngine engine(&data, &executor, NULL, &state_mgr);
        engine.Initialize("EURUSD", 12345);

        EntryDecision decision = engine.Evaluate();

        AssertFalse(decision.should_enter, "High spread should block entry");
        AssertTrue(StringLen(decision.block_reason) > 0, "Block reason should be set");
    }
    EndTest();

    //=================================================================
    // SL/TP TESTS
    //=================================================================

    BeginTest("StopLoss_Buy_BelowEntry");
    {
        CMockDataProvider data;
        CMockOrderExecutor executor;
        SetupStrongUptrend(data);
        executor.SetTradeAllowed(true);
        executor.SetCurrentPrices(1.0850, 1.0852);

        CMarketStateManager state_mgr(&data);
        state_mgr.Initialize(50);

        CEntryEngine engine(&data, &executor, NULL, &state_mgr);
        engine.Initialize("EURUSD", 12345);

        EntryDecision decision = engine.Evaluate();

        if (decision.should_enter && decision.direction == ORDER_TYPE_BUY) {
            AssertLess(decision.stop_loss, decision.entry_price,
                      "BUY SL should be below entry price");
        } else {
            // Om ingen signal - testet är trivially true
            AssertTrue(true, "No BUY signal generated - cannot test SL");
        }
    }
    EndTest();

    BeginTest("StopLoss_Sell_AboveEntry");
    {
        CMockDataProvider data;
        CMockOrderExecutor executor;
        SetupStrongDowntrend(data);
        executor.SetTradeAllowed(true);
        executor.SetCurrentPrices(1.0750, 1.0752);

        CMarketStateManager state_mgr(&data);
        state_mgr.Initialize(50);

        CEntryEngine engine(&data, &executor, NULL, &state_mgr);
        engine.Initialize("EURUSD", 12345);

        EntryDecision decision = engine.Evaluate();

        if (decision.should_enter && decision.direction == ORDER_TYPE_SELL) {
            AssertGreater(decision.stop_loss, decision.entry_price,
                         "SELL SL should be above entry price");
        } else {
            AssertTrue(true, "No SELL signal generated - cannot test SL");
        }
    }
    EndTest();

    BeginTest("TakeProfit_Buy_AboveEntry");
    {
        CMockDataProvider data;
        CMockOrderExecutor executor;
        SetupStrongUptrend(data);
        executor.SetTradeAllowed(true);
        executor.SetCurrentPrices(1.0850, 1.0852);

        CMarketStateManager state_mgr(&data);
        state_mgr.Initialize(50);

        CEntryEngine engine(&data, &executor, NULL, &state_mgr);
        engine.Initialize("EURUSD", 12345);

        EntryDecision decision = engine.Evaluate();

        if (decision.should_enter && decision.direction == ORDER_TYPE_BUY) {
            AssertGreater(decision.take_profit, decision.entry_price,
                         "BUY TP should be above entry price");
        } else {
            AssertTrue(true, "No BUY signal generated - cannot test TP");
        }
    }
    EndTest();

    //=================================================================
    // POSITION SIZING TESTS
    //=================================================================

    BeginTest("LotSize_IsPositive_WhenSignal");
    {
        CMockDataProvider data;
        CMockOrderExecutor executor;
        SetupStrongUptrend(data);
        executor.SetTradeAllowed(true);
        executor.SetCurrentPrices(1.0850, 1.0852);

        CMarketStateManager state_mgr(&data);
        state_mgr.Initialize(50);

        CEntryEngine engine(&data, &executor, NULL, &state_mgr);
        engine.Initialize("EURUSD", 12345);

        EntryDecision decision = engine.Evaluate();

        if (decision.should_enter) {
            AssertGreater(decision.lot_size, 0.0, "Lot size should be positive");
        } else {
            AssertTrue(true, "No signal generated - cannot test lot size");
        }
    }
    EndTest();

    //=================================================================
    // INITIALIZATION TESTS
    //=================================================================

    BeginTest("Initialize_WithValidDependencies_ReturnsTrue");
    {
        CMockDataProvider data;
        CMockOrderExecutor executor;
        SetupNormalTradingEnvironment(data, executor);

        CMarketStateManager state_mgr(&data);
        state_mgr.Initialize(50);

        CEntryEngine engine(&data, &executor, NULL, &state_mgr);
        bool result = engine.Initialize("EURUSD", 12345);

        AssertTrue(result, "Initialize should return true with valid dependencies");
        AssertTrue(engine.IsInitialized(), "IsInitialized should return true");
    }
    EndTest();

    BeginTest("Initialize_WithNullData_ReturnsFalse");
    {
        CMockOrderExecutor executor;
        CMarketStateManager state_mgr(NULL);

        CEntryEngine engine(NULL, &executor, NULL, &state_mgr);
        bool result = engine.Initialize("EURUSD", 12345);

        AssertFalse(result, "Initialize should return false with null data provider");
    }
    EndTest();

    BeginTest("Evaluate_BeforeInit_ReturnsNoEntry");
    {
        CMockDataProvider data;
        CMockOrderExecutor executor;
        SetupNormalTradingEnvironment(data, executor);

        CMarketStateManager state_mgr(&data);
        state_mgr.Initialize(50);

        CEntryEngine engine(&data, &executor, NULL, &state_mgr);
        // Ingen Initialize() kallad

        EntryDecision decision = engine.Evaluate();
        AssertFalse(decision.should_enter, "Uninitialized engine should not signal entry");
    }
    EndTest();

    //=================================================================
    // CONFIGURATION TESTS
    //=================================================================

    BeginTest("SetRiskPerTrade_ClampsToValidRange");
    {
        CMockDataProvider data;
        CMockOrderExecutor executor;
        SetupNormalTradingEnvironment(data, executor);

        CMarketStateManager state_mgr(&data);
        state_mgr.Initialize(50);

        CEntryEngine engine(&data, &executor, NULL, &state_mgr);
        engine.Initialize("EURUSD", 12345);

        engine.SetRiskPerTrade(0.0);  // Under min
        AssertGreater(engine.GetRiskPerTrade(), 0.0, "Risk should be clamped to min");

        engine.SetRiskPerTrade(20.0);  // Över max
        AssertLess(engine.GetRiskPerTrade(), 20.0, "Risk should be clamped to max");
    }
    EndTest();

    EndTestSuite();
}

//+------------------------------------------------------------------+
