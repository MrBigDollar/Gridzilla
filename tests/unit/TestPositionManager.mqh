//+------------------------------------------------------------------+
//|                                          TestPositionManager.mqh  |
//|                                Copyright 2024, Gridzilla Project  |
//+------------------------------------------------------------------+
#property copyright "Gridzilla Project"
#property version   "1.00"
#property strict

#include "..\TestAssertions.mqh"
#include "..\..\src\core\PositionManager.mqh"
#include "..\..\src\mocks\CMockDataProvider.mqh"
#include "..\..\src\mocks\CMockOrderExecutor.mqh"
#include "..\..\src\mocks\CMockLogger.mqh"

//+------------------------------------------------------------------+
//| Globala testvariabler                                             |
//+------------------------------------------------------------------+
CMockDataProvider*   g_pm_data = NULL;
CMockOrderExecutor*  g_pm_executor = NULL;
CMockLogger*         g_pm_logger = NULL;
CPositionManager*    g_pm = NULL;

//+------------------------------------------------------------------+
//| SetupPositionManagerTest - Initiera test-environment              |
//+------------------------------------------------------------------+
void SetupPositionManagerTest() {
    // Rensa tidigare
    if (g_pm != NULL) { delete g_pm; g_pm = NULL; }
    if (g_pm_data != NULL) { delete g_pm_data; g_pm_data = NULL; }
    if (g_pm_executor != NULL) { delete g_pm_executor; g_pm_executor = NULL; }
    if (g_pm_logger != NULL) { delete g_pm_logger; g_pm_logger = NULL; }

    // Skapa nya instanser
    g_pm_data = new CMockDataProvider();
    g_pm_executor = new CMockOrderExecutor();
    g_pm_logger = new CMockLogger();

    // Konfigurera standardvärden
    g_pm_data.SetPrices(1.0850, 1.0852);
    g_pm_data.SetAccountInfo(10000.0, 10000.0, 10000.0);
    g_pm_data.SetSymbolInfo("EURUSD", 0.00001, 5);
    g_pm_data.SetTime(D'2024.01.15 10:00', D'2024.01.15 10:00', 0);

    g_pm_executor.SetTradeAllowed(true);
    g_pm_executor.SetCurrentPrices(1.0850, 1.0852);  // Synka med dataprovider

    // Skapa PositionManager
    g_pm = new CPositionManager(g_pm_data, g_pm_executor, g_pm_logger);
    g_pm.Initialize("EURUSD", 12345);
}

//+------------------------------------------------------------------+
//| CleanupPositionManagerTest - Städa upp efter test                 |
//+------------------------------------------------------------------+
void CleanupPositionManagerTest() {
    if (g_pm != NULL) { delete g_pm; g_pm = NULL; }
    if (g_pm_data != NULL) { delete g_pm_data; g_pm_data = NULL; }
    if (g_pm_executor != NULL) { delete g_pm_executor; g_pm_executor = NULL; }
    if (g_pm_logger != NULL) { delete g_pm_logger; g_pm_logger = NULL; }
}

//+------------------------------------------------------------------+
//| AddTestPosition - Hjälpfunktion för att lägga till position       |
//+------------------------------------------------------------------+
void AddTestPosition(double lots, double open_price, int type, datetime open_time = 0) {
    if (open_time == 0) open_time = D'2024.01.15 10:00';

    OrderResult result = g_pm_executor.SendMarketOrder(
        "EURUSD",
        type,
        lots,
        0.0,  // SL
        0.0,  // TP
        "Test",
        12345
    );

    // Justera öppningspris och tid manuellt
    if (result.success) {
        // MockExecutor har redan lagt till positionen, vi behöver uppdatera den
        // Detta är en förenkling - i verkligheten skulle vi behöva en setter
    }
}

//=== AVERAGE ENTRY PRICE TESTER ===

//+------------------------------------------------------------------+
//| Test_AvgEntry_SinglePosition_ReturnsPrice                         |
//+------------------------------------------------------------------+
void Test_AvgEntry_SinglePosition_ReturnsPrice() {
    BeginTest("AvgEntry_SinglePosition_ReturnsPrice");

    SetupPositionManagerTest();

    // Lägg till en BUY-position
    g_pm_executor.SendMarketOrder("EURUSD", ORDER_TYPE_BUY, 0.1, 0, 0, "Test", 12345);

    double avg = g_pm.GetAverageEntryPrice();

    // Avg ska vara nära ask-priset (1.0852)
    AssertNear(1.0852, avg, 0.0001, "Single position avg should be entry price");

    CleanupPositionManagerTest();
    EndTest();
}

//+------------------------------------------------------------------+
//| Test_AvgEntry_TwoEqualLots_ReturnsMiddle                          |
//+------------------------------------------------------------------+
void Test_AvgEntry_TwoEqualLots_ReturnsMiddle() {
    BeginTest("AvgEntry_TwoEqualLots_ReturnsMiddle");

    SetupPositionManagerTest();

    // Simulera två positioner med olika priser
    // Position 1: 0.1 lots @ 1.0850 (executor använder sina egna priser)
    g_pm_executor.SetCurrentPrices(1.0848, 1.0850);
    g_pm_executor.SendMarketOrder("EURUSD", ORDER_TYPE_BUY, 0.1, 0, 0, "Test1", 12345);

    // Position 2: 0.1 lots @ 1.0860
    g_pm_executor.SetCurrentPrices(1.0858, 1.0860);
    g_pm_executor.SendMarketOrder("EURUSD", ORDER_TYPE_BUY, 0.1, 0, 0, "Test2", 12345);

    double avg = g_pm.GetAverageEntryPrice();

    // Med lika lots blir avg = (1.0850 + 1.0860) / 2 = 1.0855
    AssertNear(1.0855, avg, 0.0001, "Two equal lots should give middle price");

    CleanupPositionManagerTest();
    EndTest();
}

//+------------------------------------------------------------------+
//| Test_AvgEntry_UnequalLots_WeightedAvg                             |
//+------------------------------------------------------------------+
void Test_AvgEntry_UnequalLots_WeightedAvg() {
    BeginTest("AvgEntry_UnequalLots_WeightedAvg");

    SetupPositionManagerTest();

    // Position 1: 0.1 lots @ 1.0850 (executor använder sina egna priser)
    g_pm_executor.SetCurrentPrices(1.0848, 1.0850);
    g_pm_executor.SendMarketOrder("EURUSD", ORDER_TYPE_BUY, 0.1, 0, 0, "Test1", 12345);

    // Position 2: 0.2 lots @ 1.0800
    g_pm_executor.SetCurrentPrices(1.0798, 1.0800);
    g_pm_executor.SendMarketOrder("EURUSD", ORDER_TYPE_BUY, 0.2, 0, 0, "Test2", 12345);

    double avg = g_pm.GetAverageEntryPrice();

    // Viktad avg = (0.1 * 1.0850 + 0.2 * 1.0800) / 0.3 = 1.08167
    double expected = (0.1 * 1.0850 + 0.2 * 1.0800) / 0.3;
    AssertNear(expected, avg, 0.0001, "Unequal lots should give weighted average");

    CleanupPositionManagerTest();
    EndTest();
}

//+------------------------------------------------------------------+
//| Test_AvgEntry_NoPositions_ReturnsZero                             |
//+------------------------------------------------------------------+
void Test_AvgEntry_NoPositions_ReturnsZero() {
    BeginTest("AvgEntry_NoPositions_ReturnsZero");

    SetupPositionManagerTest();

    // Ingen position
    double avg = g_pm.GetAverageEntryPrice();

    AssertEqual(0.0, avg, "No positions should return zero");

    CleanupPositionManagerTest();
    EndTest();
}

//=== DRAWDOWN TESTER ===

//+------------------------------------------------------------------+
//| Test_Drawdown_AtPeak_ReturnsZero                                  |
//+------------------------------------------------------------------+
void Test_Drawdown_AtPeak_ReturnsZero() {
    BeginTest("Drawdown_AtPeak_ReturnsZero");

    SetupPositionManagerTest();

    // Equity = peak equity = 10000
    g_pm_data.SetAccountInfo(10000.0, 10000.0, 10000.0);
    g_pm.SetPeakEquity(10000.0);

    double dd = g_pm.GetCurrentDrawdownPct();

    AssertNear(0.0, dd, 0.01, "At peak equity, DD should be 0%");

    CleanupPositionManagerTest();
    EndTest();
}

//+------------------------------------------------------------------+
//| Test_Drawdown_10PctLoss_Returns10                                 |
//+------------------------------------------------------------------+
void Test_Drawdown_10PctLoss_Returns10() {
    BeginTest("Drawdown_10PctLoss_Returns10");

    SetupPositionManagerTest();

    // Peak = 10000, current = 9000 → 10% DD
    g_pm.SetPeakEquity(10000.0);
    g_pm_data.SetAccountInfo(10000.0, 9000.0, 9000.0);

    double dd = g_pm.GetCurrentDrawdownPct();

    AssertNear(10.0, dd, 0.01, "10% equity loss should give 10% DD");

    CleanupPositionManagerTest();
    EndTest();
}

//+------------------------------------------------------------------+
//| Test_Drawdown_15PctLoss_Returns15                                 |
//+------------------------------------------------------------------+
void Test_Drawdown_15PctLoss_Returns15() {
    BeginTest("Drawdown_15PctLoss_Returns15");

    SetupPositionManagerTest();

    // Peak = 10000, current = 8500 → 15% DD
    g_pm.SetPeakEquity(10000.0);
    g_pm_data.SetAccountInfo(10000.0, 8500.0, 8500.0);

    double dd = g_pm.GetCurrentDrawdownPct();

    AssertNear(15.0, dd, 0.01, "15% equity loss should give 15% DD");

    CleanupPositionManagerTest();
    EndTest();
}

//=== MAE TESTER ===

//+------------------------------------------------------------------+
//| Test_MAE_TracksWorstPoint                                         |
//+------------------------------------------------------------------+
void Test_MAE_TracksWorstPoint() {
    BeginTest("MAE_TracksWorstPoint");

    SetupPositionManagerTest();

    g_pm.SetPeakEquity(10000.0);

    // Första uppdatering - 5% DD
    g_pm_data.SetAccountInfo(10000.0, 9500.0, 9500.0);
    g_pm.Update();
    double mae1 = g_pm.GetMAE();

    // Andra uppdatering - 10% DD (värre)
    g_pm_data.SetAccountInfo(10000.0, 9000.0, 9000.0);
    g_pm.Update();
    double mae2 = g_pm.GetMAE();

    // Tredje uppdatering - 3% DD (bättre, men MAE ska inte minska)
    g_pm_data.SetAccountInfo(10000.0, 9700.0, 9700.0);
    g_pm.Update();
    double mae3 = g_pm.GetMAE();

    AssertNear(5.0, mae1, 0.1, "First MAE should be 5%");
    AssertNear(10.0, mae2, 0.1, "MAE should update to 10%");
    AssertNear(10.0, mae3, 0.1, "MAE should NOT decrease from 10%");

    CleanupPositionManagerTest();
    EndTest();
}

//=== VELOCITY TESTER ===

//+------------------------------------------------------------------+
//| Test_Velocity_StableEquity_ReturnsZero                            |
//+------------------------------------------------------------------+
void Test_Velocity_StableEquity_ReturnsZero() {
    BeginTest("Velocity_StableEquity_ReturnsZero");

    SetupPositionManagerTest();

    // Lägg till stabil equity-historik
    for (int i = 0; i < 10; i++) {
        g_pm.AddEquityDataPoint(10000.0);
    }

    double velocity = g_pm.GetDrawdownVelocity();

    AssertNear(0.0, velocity, 0.01, "Stable equity should give zero velocity");

    CleanupPositionManagerTest();
    EndTest();
}

//+------------------------------------------------------------------+
//| Test_Velocity_RapidLoss_ReturnsNegative                           |
//+------------------------------------------------------------------+
void Test_Velocity_RapidLoss_ReturnsNegative() {
    BeginTest("Velocity_RapidLoss_ReturnsNegative");

    SetupPositionManagerTest();

    // Lägg till fallande equity-historik
    g_pm.AddEquityDataPoint(10000.0);
    g_pm.AddEquityDataPoint(9800.0);
    g_pm.AddEquityDataPoint(9600.0);
    g_pm.AddEquityDataPoint(9400.0);
    g_pm.AddEquityDataPoint(9200.0);

    double velocity = g_pm.GetDrawdownVelocity();

    AssertTrue(velocity < 0, "Rapid loss should give negative velocity");

    CleanupPositionManagerTest();
    EndTest();
}

//+------------------------------------------------------------------+
//| Test_Velocity_Normalized_ClampedTo1                               |
//+------------------------------------------------------------------+
void Test_Velocity_Normalized_ClampedTo1() {
    BeginTest("Velocity_Normalized_ClampedTo1");

    SetupPositionManagerTest();

    // Lägg till extremt snabb förlust
    g_pm.AddEquityDataPoint(10000.0);
    g_pm.AddEquityDataPoint(5000.0);  // 50% förlust på en bar

    double velocity = g_pm.GetDrawdownVelocity();

    AssertTrue(velocity >= -1.0, "Velocity should be clamped to >= -1.0");
    AssertTrue(velocity <= 1.0, "Velocity should be clamped to <= 1.0");

    CleanupPositionManagerTest();
    EndTest();
}

//=== DIRECTION TESTER ===

//+------------------------------------------------------------------+
//| Test_Direction_NoBuys_ReturnsFLAT                                 |
//+------------------------------------------------------------------+
void Test_Direction_NoPositions_ReturnsFLAT() {
    BeginTest("Direction_NoPositions_ReturnsFLAT");

    SetupPositionManagerTest();

    PositionDirection dir = g_pm.GetDirection();

    AssertEqual((int)POSITION_DIRECTION_FLAT, (int)dir, "No positions should be FLAT");

    CleanupPositionManagerTest();
    EndTest();
}

//+------------------------------------------------------------------+
//| Test_Direction_OnlyBuys_ReturnsLONG                               |
//+------------------------------------------------------------------+
void Test_Direction_OnlyBuys_ReturnsLONG() {
    BeginTest("Direction_OnlyBuys_ReturnsLONG");

    SetupPositionManagerTest();

    g_pm_executor.SendMarketOrder("EURUSD", ORDER_TYPE_BUY, 0.1, 0, 0, "Test", 12345);

    PositionDirection dir = g_pm.GetDirection();

    AssertEqual((int)POSITION_DIRECTION_LONG, (int)dir, "Only buys should be LONG");

    CleanupPositionManagerTest();
    EndTest();
}

//+------------------------------------------------------------------+
//| Test_Direction_OnlySells_ReturnsSHORT                             |
//+------------------------------------------------------------------+
void Test_Direction_OnlySells_ReturnsSHORT() {
    BeginTest("Direction_OnlySells_ReturnsSHORT");

    SetupPositionManagerTest();

    g_pm_executor.SendMarketOrder("EURUSD", ORDER_TYPE_SELL, 0.1, 0, 0, "Test", 12345);

    PositionDirection dir = g_pm.GetDirection();

    AssertEqual((int)POSITION_DIRECTION_SHORT, (int)dir, "Only sells should be SHORT");

    CleanupPositionManagerTest();
    EndTest();
}

//=== UPDATE STATE TESTER ===

//+------------------------------------------------------------------+
//| Test_Update_ReturnsCompleteState                                  |
//+------------------------------------------------------------------+
void Test_Update_ReturnsCompleteState() {
    BeginTest("Update_ReturnsCompleteState");

    SetupPositionManagerTest();

    // Lägg till en position
    g_pm_executor.SendMarketOrder("EURUSD", ORDER_TYPE_BUY, 0.1, 0, 0, "Test", 12345);

    PositionManagerState state = g_pm.Update();

    AssertEqual(1, state.position_count, "Should have 1 position");
    AssertNear(0.1, state.total_lots, 0.001, "Should have 0.1 lots");
    AssertEqual((int)POSITION_DIRECTION_LONG, (int)state.direction, "Should be LONG");
    AssertTrue(state.average_entry_price > 0, "Avg entry should be positive");

    CleanupPositionManagerTest();
    EndTest();
}

//+------------------------------------------------------------------+
//| RunPositionManagerTests - Kör alla PositionManager-tester         |
//+------------------------------------------------------------------+
void RunPositionManagerTests() {
    BeginTestSuite("PositionManager");

    // Average Entry Price tester
    Test_AvgEntry_SinglePosition_ReturnsPrice();
    Test_AvgEntry_TwoEqualLots_ReturnsMiddle();
    Test_AvgEntry_UnequalLots_WeightedAvg();
    Test_AvgEntry_NoPositions_ReturnsZero();

    // Drawdown tester
    Test_Drawdown_AtPeak_ReturnsZero();
    Test_Drawdown_10PctLoss_Returns10();
    Test_Drawdown_15PctLoss_Returns15();

    // MAE tester
    Test_MAE_TracksWorstPoint();

    // Velocity tester
    Test_Velocity_StableEquity_ReturnsZero();
    Test_Velocity_RapidLoss_ReturnsNegative();
    Test_Velocity_Normalized_ClampedTo1();

    // Direction tester
    Test_Direction_NoPositions_ReturnsFLAT();
    Test_Direction_OnlyBuys_ReturnsLONG();
    Test_Direction_OnlySells_ReturnsSHORT();

    // Update state tester
    Test_Update_ReturnsCompleteState();

    EndTestSuite();
}

//+------------------------------------------------------------------+
