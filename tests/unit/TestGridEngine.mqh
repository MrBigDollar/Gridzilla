//+------------------------------------------------------------------+
//|                                              TestGridEngine.mqh   |
//|                                Copyright 2024, Gridzilla Project  |
//+------------------------------------------------------------------+
#property copyright "Gridzilla Project"
#property version   "1.00"
#property strict

#include "..\..\src\core\GridEngine.mqh"
#include "..\..\src\mocks\CMockDataProvider.mqh"
#include "..\..\src\mocks\CMockOrderExecutor.mqh"
#include "..\..\src\mocks\CMockLogger.mqh"
#include "..\TestAssertions.mqh"

//+------------------------------------------------------------------+
//| Globala testvariabler                                             |
//+------------------------------------------------------------------+
CMockDataProvider*   g_ge_data = NULL;
CMockOrderExecutor*  g_ge_executor = NULL;
CMockLogger*         g_ge_logger = NULL;
CPositionManager*    g_ge_pm = NULL;
CRiskEngine*         g_ge_risk = NULL;
CGridEngine*         g_ge_grid = NULL;

//+------------------------------------------------------------------+
//| SetupGridEngineTest - Initiera testmiljö                          |
//+------------------------------------------------------------------+
void SetupGridEngineTest() {
    // Skapa mocks
    g_ge_data = new CMockDataProvider();
    g_ge_executor = new CMockOrderExecutor();
    g_ge_logger = new CMockLogger();

    // Konfigurera mock data
    g_ge_data.SetAccountInfo(10000.0, 10000.0, 10000.0);
    g_ge_data.SetPrices(1.0850, 1.0852);
    g_ge_data.SetSymbolInfo("EURUSD", 0.00001, 5);
    g_ge_data.SetLotInfo(0.01, 100.0, 0.01);

    // Konfigurera executor
    g_ge_executor.SetTradeAllowed(true);
    g_ge_executor.SetCurrentPrices(1.0850, 1.0852);

    // Skapa PositionManager och RiskEngine
    g_ge_pm = new CPositionManager(g_ge_data, g_ge_executor, g_ge_logger);
    g_ge_pm.Initialize("EURUSD", 12345);

    g_ge_risk = new CRiskEngine(g_ge_data, g_ge_executor, g_ge_logger, g_ge_pm);
    g_ge_risk.Initialize("EURUSD", 12345);

    // Skapa GridEngine
    g_ge_grid = new CGridEngine(g_ge_data, g_ge_executor, g_ge_logger, g_ge_pm, g_ge_risk);
    g_ge_grid.Initialize("EURUSD", 12345);
}

//+------------------------------------------------------------------+
//| CleanupGridEngineTest - Städa testmiljö                           |
//+------------------------------------------------------------------+
void CleanupGridEngineTest() {
    if (g_ge_grid != NULL) { delete g_ge_grid; g_ge_grid = NULL; }
    if (g_ge_risk != NULL) { delete g_ge_risk; g_ge_risk = NULL; }
    if (g_ge_pm != NULL) { delete g_ge_pm; g_ge_pm = NULL; }
    if (g_ge_logger != NULL) { delete g_ge_logger; g_ge_logger = NULL; }
    if (g_ge_executor != NULL) { delete g_ge_executor; g_ge_executor = NULL; }
    if (g_ge_data != NULL) { delete g_ge_data; g_ge_data = NULL; }
}

//+------------------------------------------------------------------+
//|                    LOT-BERÄKNINGSTESTER                           |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Test: LotSize_Level0_ReturnsBase                                  |
//+------------------------------------------------------------------+
void Test_GE_LotSize_Level0_ReturnsBase() {
    SetupGridEngineTest();

    // Sätt konfiguration
    GridConfig config;
    config.base_lot_size = 0.01;
    config.lot_multiplier = 1.5;
    g_ge_grid.SetConfig(config);

    // Beräkna lots för nivå 0
    double lots = g_ge_grid.CalculateLotSizePublic(0);

    // Förväntat: 0.01 * 1.5^0 = 0.01
    AssertNear(lots, 0.01, 0.001, "Level 0 should return base lot size");

    CleanupGridEngineTest();
}

//+------------------------------------------------------------------+
//| Test: LotSize_Level1_ReturnsMultiplied                            |
//+------------------------------------------------------------------+
void Test_GE_LotSize_Level1_ReturnsMultiplied() {
    SetupGridEngineTest();

    GridConfig config;
    config.base_lot_size = 0.01;
    config.lot_multiplier = 1.5;
    g_ge_grid.SetConfig(config);

    // Beräkna lots för nivå 1
    double lots = g_ge_grid.CalculateLotSizePublic(1);

    // Förväntat: 0.01 * 1.5^1 = 0.015, normaliserat med MathFloor till 0.01
    AssertNear(lots, 0.01, 0.001, "Level 1 should return base * multiplier (floor normalized)");

    CleanupGridEngineTest();
}

//+------------------------------------------------------------------+
//| Test: LotSize_Level3_ReturnsCorrect                               |
//+------------------------------------------------------------------+
void Test_GE_LotSize_Level3_ReturnsCorrect() {
    SetupGridEngineTest();

    GridConfig config;
    config.base_lot_size = 0.01;
    config.lot_multiplier = 1.5;
    g_ge_grid.SetConfig(config);

    // Beräkna lots för nivå 3
    double lots = g_ge_grid.CalculateLotSizePublic(3);

    // Förväntat: 0.01 * 1.5^3 = 0.03375, normaliserat till 0.03
    AssertNear(lots, 0.03, 0.01, "Level 3 should return correct multiplied value");

    CleanupGridEngineTest();
}

//+------------------------------------------------------------------+
//| Test: LotSize_Level7_ReturnsCorrect                               |
//+------------------------------------------------------------------+
void Test_GE_LotSize_Level7_ReturnsCorrect() {
    SetupGridEngineTest();

    GridConfig config;
    config.base_lot_size = 0.1;
    config.lot_multiplier = 1.5;
    g_ge_grid.SetConfig(config);

    // Beräkna lots för nivå 7
    double lots = g_ge_grid.CalculateLotSizePublic(7);

    // Förväntat: 0.1 * 1.5^7 = 1.7086, normaliserat till ~1.71
    AssertTrue(lots >= 1.70 && lots <= 1.72, "Level 7 should be around 1.71 lots");

    CleanupGridEngineTest();
}

//+------------------------------------------------------------------+
//|                    SPACING-TESTER                                 |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Test: NextPrice_FirstLevel_CurrentPrice                           |
//+------------------------------------------------------------------+
void Test_GE_NextPrice_FirstLevel_CurrentPrice() {
    SetupGridEngineTest();

    // Aktivera grid (BUY)
    g_ge_grid.SetActive(true);
    g_ge_grid.SetDirection(POSITION_TYPE_BUY);

    // Beräkna nästa nivås pris (ingen aktiv position ännu)
    double price = g_ge_grid.CalculateNextLevelPricePublic();

    // Förväntat: Ask-pris för BUY
    AssertNear(price, 1.0852, 0.0001, "First BUY level should use Ask price");

    CleanupGridEngineTest();
}

//+------------------------------------------------------------------+
//| Test: NextPrice_BuyGrid_Below                                     |
//+------------------------------------------------------------------+
void Test_GE_NextPrice_BuyGrid_Below() {
    SetupGridEngineTest();

    // Lägg till en position
    g_ge_executor.SetCurrentPrices(1.0850, 1.0852);
    g_ge_executor.SendMarketOrder("EURUSD", POSITION_TYPE_BUY, 0.01, 0, 0, "Test", 12345);

    // Aktivera grid (BUY)
    g_ge_grid.SetActive(true);
    g_ge_grid.SetDirection(POSITION_TYPE_BUY);

    // Uppdatera state för att inkludera positionen
    GridState state = g_ge_grid.GetState();

    // Beräkna nästa nivås pris
    double price = g_ge_grid.CalculateNextLevelPricePublic();

    // Förväntat: senaste pris - 50 pips = 1.0852 - 0.0050 = 1.0802
    double expected = 1.0852 - 0.0050;
    AssertNear(price, expected, 0.0001, "BUY grid next level should be below");

    CleanupGridEngineTest();
}

//+------------------------------------------------------------------+
//| Test: NextPrice_SellGrid_Above                                    |
//+------------------------------------------------------------------+
void Test_GE_NextPrice_SellGrid_Above() {
    SetupGridEngineTest();

    // Lägg till en SELL position
    g_ge_executor.SetCurrentPrices(1.0850, 1.0852);
    g_ge_executor.SendMarketOrder("EURUSD", POSITION_TYPE_SELL, 0.01, 0, 0, "Test", 12345);

    // Aktivera grid (SELL)
    g_ge_grid.SetActive(true);
    g_ge_grid.SetDirection(POSITION_TYPE_SELL);

    // Uppdatera state
    GridState state = g_ge_grid.GetState();

    // Beräkna nästa nivås pris
    double price = g_ge_grid.CalculateNextLevelPricePublic();

    // Förväntat: senaste pris + 50 pips = 1.0850 + 0.0050 = 1.0900
    double expected = 1.0850 + 0.0050;
    AssertNear(price, expected, 0.0001, "SELL grid next level should be above");

    CleanupGridEngineTest();
}

//+------------------------------------------------------------------+
//| Test: NextPrice_50PipsSpacing                                     |
//+------------------------------------------------------------------+
void Test_GE_NextPrice_50PipsSpacing() {
    SetupGridEngineTest();

    // Konfigurera 50 pips spacing
    GridConfig config;
    config.spacing_pips = 50.0;
    g_ge_grid.SetConfig(config);

    // Lägg till en position
    g_ge_executor.SetCurrentPrices(1.1000, 1.1002);
    g_ge_executor.SendMarketOrder("EURUSD", POSITION_TYPE_BUY, 0.01, 0, 0, "Test", 12345);

    g_ge_grid.SetActive(true);
    g_ge_grid.SetDirection(POSITION_TYPE_BUY);

    GridState state = g_ge_grid.GetState();

    double price = g_ge_grid.CalculateNextLevelPricePublic();

    // 50 pips = 0.0050 för 5-decimal
    double expected = 1.1002 - 0.0050;
    AssertNear(price, expected, 0.0001, "Spacing should be exactly 50 pips");

    CleanupGridEngineTest();
}

//+------------------------------------------------------------------+
//|                    HARD LIMIT-TESTER                              |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Test: CanAdd_MaxLevelsReached_Blocks                              |
//+------------------------------------------------------------------+
void Test_GE_CanAdd_MaxLevelsReached_Blocks() {
    SetupGridEngineTest();

    // Konfigurera max 3 levels för enklare test
    GridConfig config;
    config.max_levels = 3;
    config.base_lot_size = 0.01;
    g_ge_grid.SetConfig(config);

    // Lägg till 3 positioner
    for (int i = 0; i < 3; i++) {
        g_ge_executor.SendMarketOrder("EURUSD", POSITION_TYPE_BUY, 0.01, 0, 0, "Test", 12345);
    }

    g_ge_grid.SetActive(true);
    g_ge_grid.SetDirection(POSITION_TYPE_BUY);

    // Uppdatera state
    GridState state = g_ge_grid.GetState();

    // Försök lägga till nivå
    string reason = "";
    bool can_add = g_ge_grid.CanAddLevelPublic(reason);

    AssertFalse(can_add, "Should not allow adding when max levels reached");
    AssertTrue(StringFind(reason, "Max levels") >= 0, "Reason should mention max levels");

    CleanupGridEngineTest();
}

//+------------------------------------------------------------------+
//| Test: CanAdd_MaxLotsExceeded_Blocks                               |
//+------------------------------------------------------------------+
void Test_GE_CanAdd_MaxLotsExceeded_Blocks() {
    SetupGridEngineTest();

    // Konfigurera max 1.0 lots
    GridConfig config;
    config.max_total_lots = 1.0;
    config.base_lot_size = 0.5;  // Stor base lot
    config.lot_multiplier = 1.5;
    config.max_levels = 8;
    g_ge_grid.SetConfig(config);

    // Lägg till position som tar upp nästan all kapacitet
    g_ge_executor.SendMarketOrder("EURUSD", POSITION_TYPE_BUY, 0.6, 0, 0, "Test", 12345);

    g_ge_grid.SetActive(true);
    g_ge_grid.SetDirection(POSITION_TYPE_BUY);

    GridState state = g_ge_grid.GetState();

    // Nästa nivå skulle vara 0.5 * 1.5 = 0.75 lots, totalt 1.35 > 1.0
    string reason = "";
    bool can_add = g_ge_grid.CanAddLevelPublic(reason);

    AssertFalse(can_add, "Should not allow adding when would exceed max lots");
    AssertTrue(StringFind(reason, "max lots") >= 0, "Reason should mention max lots");

    CleanupGridEngineTest();
}

//+------------------------------------------------------------------+
//| Test: CanAdd_DDLimit_Blocks                                       |
//+------------------------------------------------------------------+
void Test_GE_CanAdd_DDLimit_Blocks() {
    SetupGridEngineTest();

    // Simulera 16% drawdown (över 15% gräns)
    g_ge_data.SetAccountInfo(10000.0, 8400.0, 8400.0);  // 16% DD
    g_ge_pm.SetPeakEquity(10000.0);

    g_ge_grid.SetActive(true);
    g_ge_grid.SetDirection(POSITION_TYPE_BUY);

    string reason = "";
    bool can_add = g_ge_grid.CanAddLevelPublic(reason);

    AssertFalse(can_add, "Should not allow adding when DD exceeds limit");
    AssertTrue(StringFind(reason, "Drawdown") >= 0 || StringFind(reason, "DD") >= 0,
               "Reason should mention drawdown");

    CleanupGridEngineTest();
}

//+------------------------------------------------------------------+
//| Test: CanAdd_AllOK_Allows                                         |
//+------------------------------------------------------------------+
void Test_GE_CanAdd_AllOK_Allows() {
    SetupGridEngineTest();

    g_ge_grid.SetActive(true);
    g_ge_grid.SetDirection(POSITION_TYPE_BUY);

    string reason = "";
    bool can_add = g_ge_grid.CanAddLevelPublic(reason);

    AssertTrue(can_add, "Should allow adding when all limits OK");
    AssertTrue(reason == "", "Reason should be empty when allowed");

    CleanupGridEngineTest();
}

//+------------------------------------------------------------------+
//|                    GRID-AKTIVERINGSTESTER                         |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Test: Activate_Buy_CreatesFirstLevel                              |
//+------------------------------------------------------------------+
void Test_GE_Activate_Buy_CreatesFirstLevel() {
    SetupGridEngineTest();

    bool activated = g_ge_grid.ActivateGrid(POSITION_TYPE_BUY);

    AssertTrue(activated, "Grid should activate successfully");

    GridState state = g_ge_grid.GetState();
    AssertTrue(state.is_active, "Grid should be active");
    AssertEqual(state.active_levels, 1, "Should have 1 level");
    AssertEqual(state.direction, (int)POSITION_TYPE_BUY, "Direction should be BUY");

    CleanupGridEngineTest();
}

//+------------------------------------------------------------------+
//| Test: Activate_Sell_CreatesFirstLevel                             |
//+------------------------------------------------------------------+
void Test_GE_Activate_Sell_CreatesFirstLevel() {
    SetupGridEngineTest();

    bool activated = g_ge_grid.ActivateGrid(POSITION_TYPE_SELL);

    AssertTrue(activated, "Grid should activate successfully");

    GridState state = g_ge_grid.GetState();
    AssertTrue(state.is_active, "Grid should be active");
    AssertEqual(state.active_levels, 1, "Should have 1 level");
    AssertEqual(state.direction, (int)POSITION_TYPE_SELL, "Direction should be SELL");

    CleanupGridEngineTest();
}

//+------------------------------------------------------------------+
//| Test: Activate_AlreadyActive_ReturnsFalse                         |
//+------------------------------------------------------------------+
void Test_GE_Activate_AlreadyActive_ReturnsFalse() {
    SetupGridEngineTest();

    // Aktivera första gången
    g_ge_grid.ActivateGrid(POSITION_TYPE_BUY);

    // Försök aktivera igen
    bool activated = g_ge_grid.ActivateGrid(POSITION_TYPE_SELL);

    AssertFalse(activated, "Should not activate when already active");

    CleanupGridEngineTest();
}

//+------------------------------------------------------------------+
//|                    STÄNGNINGSTESTER                               |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Test: CloseAll_SingleLevel_Closes                                 |
//+------------------------------------------------------------------+
void Test_GE_CloseAll_SingleLevel_Closes() {
    SetupGridEngineTest();

    // Aktivera och lägg till en nivå
    g_ge_grid.ActivateGrid(POSITION_TYPE_BUY);

    GridState state_before = g_ge_grid.GetState();
    AssertEqual(state_before.active_levels, 1, "Should have 1 level before close");

    // Stäng alla
    bool closed = g_ge_grid.CloseAllLevels();

    AssertTrue(closed, "Should close successfully");

    GridState state_after = g_ge_grid.GetState();
    AssertEqual(state_after.active_levels, 0, "Should have 0 levels after close");
    AssertFalse(state_after.is_active, "Grid should not be active");

    CleanupGridEngineTest();
}

//+------------------------------------------------------------------+
//| Test: CloseAll_MultipleLevels_ClosesAll                           |
//+------------------------------------------------------------------+
void Test_GE_CloseAll_MultipleLevels_ClosesAll() {
    SetupGridEngineTest();

    // Aktivera och lägg till flera nivåer
    g_ge_grid.ActivateGrid(POSITION_TYPE_BUY);
    g_ge_grid.AddLevel();
    g_ge_grid.AddLevel();

    GridState state_before = g_ge_grid.GetState();
    AssertEqual(state_before.active_levels, 3, "Should have 3 levels before close");

    // Stäng alla
    bool closed = g_ge_grid.CloseAllLevels();

    AssertTrue(closed, "Should close successfully");

    GridState state_after = g_ge_grid.GetState();
    AssertEqual(state_after.active_levels, 0, "Should have 0 levels after close");

    CleanupGridEngineTest();
}

//+------------------------------------------------------------------+
//| Test: CloseAll_UpdatesState                                       |
//+------------------------------------------------------------------+
void Test_GE_CloseAll_UpdatesState() {
    SetupGridEngineTest();

    g_ge_grid.ActivateGrid(POSITION_TYPE_BUY);
    g_ge_grid.AddLevel();

    g_ge_grid.CloseAllLevels();

    GridState state = g_ge_grid.GetState();
    AssertFalse(state.is_active, "is_active should be false");
    AssertEqual(state.active_levels, 0, "active_levels should be 0");
    AssertNear(state.total_grid_lots, 0.0, 0.001, "total_grid_lots should be 0");

    CleanupGridEngineTest();
}

//+------------------------------------------------------------------+
//|                    EMERGENCY CLOSE-TESTER                         |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Test: Emergency_20PctDD_TriggersClose                             |
//+------------------------------------------------------------------+
void Test_GE_Emergency_20PctDD_TriggersClose() {
    SetupGridEngineTest();

    // Aktivera grid
    g_ge_grid.ActivateGrid(POSITION_TYPE_BUY);

    // Simulera 21% drawdown (över 20% emergency gräns)
    g_ge_data.SetAccountInfo(10000.0, 7900.0, 7900.0);  // 21% DD
    g_ge_pm.SetPeakEquity(10000.0);

    // Evaluera
    GridDecision decision = g_ge_grid.Evaluate();

    AssertTrue(decision.should_close_all, "Should trigger emergency close at 20%+ DD");

    CleanupGridEngineTest();
}

//+------------------------------------------------------------------+
//| Test: Emergency_Below20_NoClose (GridEngine version)              |
//+------------------------------------------------------------------+
void Test_GE_Emergency_Below20_NoClose() {
    SetupGridEngineTest();

    // Aktivera grid
    g_ge_grid.ActivateGrid(POSITION_TYPE_BUY);

    // Simulera 19% drawdown (under 20% emergency gräns)
    g_ge_data.SetAccountInfo(10000.0, 8100.0, 8100.0);  // 19% DD
    g_ge_pm.SetPeakEquity(10000.0);

    // Evaluera
    GridDecision decision = g_ge_grid.Evaluate();

    AssertFalse(decision.should_close_all, "Should not trigger emergency close at 19% DD");

    CleanupGridEngineTest();
}

//+------------------------------------------------------------------+
//|                    EVALUATE-TESTER                                |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Test: Evaluate_ReturnsNextLevelInfo                               |
//+------------------------------------------------------------------+
void Test_GE_Evaluate_ReturnsNextLevelInfo() {
    SetupGridEngineTest();

    g_ge_grid.ActivateGrid(POSITION_TYPE_BUY);

    GridDecision decision = g_ge_grid.Evaluate();

    AssertTrue(decision.can_add_level, "Should be able to add level");
    AssertTrue(decision.next_level_price > 0, "Should have next level price");
    AssertTrue(decision.next_level_lots > 0, "Should have next level lots");

    CleanupGridEngineTest();
}

//+------------------------------------------------------------------+
//| Test: Evaluate_NotInitialized_Blocks                              |
//+------------------------------------------------------------------+
void Test_GE_Evaluate_NotInitialized_Blocks() {
    // Skapa utan Initialize()
    CMockDataProvider* data = new CMockDataProvider();
    CMockOrderExecutor* exec = new CMockOrderExecutor();
    CGridEngine* grid = new CGridEngine(data, exec, NULL, NULL, NULL);

    GridDecision decision = grid.Evaluate();

    AssertFalse(decision.can_add_level, "Should not allow when not initialized");
    AssertTrue(StringFind(decision.block_reason, "not initialized") >= 0,
               "Reason should mention not initialized");

    delete grid;
    delete exec;
    delete data;
}

//+------------------------------------------------------------------+
//| RunGridEngineTests - Kör alla GridEngine-tester                   |
//+------------------------------------------------------------------+
void RunGridEngineTests() {
    Print("");
    Print("=== GRIDENGINE TESTS ===");

    // Lot-beräkningstester
    BeginTest("GE_LotSize_Level0_ReturnsBase");
    Test_GE_LotSize_Level0_ReturnsBase();
    EndTest();

    BeginTest("GE_LotSize_Level1_ReturnsMultiplied");
    Test_GE_LotSize_Level1_ReturnsMultiplied();
    EndTest();

    BeginTest("GE_LotSize_Level3_ReturnsCorrect");
    Test_GE_LotSize_Level3_ReturnsCorrect();
    EndTest();

    BeginTest("GE_LotSize_Level7_ReturnsCorrect");
    Test_GE_LotSize_Level7_ReturnsCorrect();
    EndTest();

    // Spacing-tester
    BeginTest("GE_NextPrice_FirstLevel_CurrentPrice");
    Test_GE_NextPrice_FirstLevel_CurrentPrice();
    EndTest();

    BeginTest("GE_NextPrice_BuyGrid_Below");
    Test_GE_NextPrice_BuyGrid_Below();
    EndTest();

    BeginTest("GE_NextPrice_SellGrid_Above");
    Test_GE_NextPrice_SellGrid_Above();
    EndTest();

    BeginTest("GE_NextPrice_50PipsSpacing");
    Test_GE_NextPrice_50PipsSpacing();
    EndTest();

    // Hard limit-tester
    BeginTest("GE_CanAdd_MaxLevelsReached_Blocks");
    Test_GE_CanAdd_MaxLevelsReached_Blocks();
    EndTest();

    BeginTest("GE_CanAdd_MaxLotsExceeded_Blocks");
    Test_GE_CanAdd_MaxLotsExceeded_Blocks();
    EndTest();

    BeginTest("GE_CanAdd_DDLimit_Blocks");
    Test_GE_CanAdd_DDLimit_Blocks();
    EndTest();

    BeginTest("GE_CanAdd_AllOK_Allows");
    Test_GE_CanAdd_AllOK_Allows();
    EndTest();

    // Grid-aktiveringstester
    BeginTest("GE_Activate_Buy_CreatesFirstLevel");
    Test_GE_Activate_Buy_CreatesFirstLevel();
    EndTest();

    BeginTest("GE_Activate_Sell_CreatesFirstLevel");
    Test_GE_Activate_Sell_CreatesFirstLevel();
    EndTest();

    BeginTest("GE_Activate_AlreadyActive_ReturnsFalse");
    Test_GE_Activate_AlreadyActive_ReturnsFalse();
    EndTest();

    // Stängningstester
    BeginTest("GE_CloseAll_SingleLevel_Closes");
    Test_GE_CloseAll_SingleLevel_Closes();
    EndTest();

    BeginTest("GE_CloseAll_MultipleLevels_ClosesAll");
    Test_GE_CloseAll_MultipleLevels_ClosesAll();
    EndTest();

    BeginTest("GE_CloseAll_UpdatesState");
    Test_GE_CloseAll_UpdatesState();
    EndTest();

    // Emergency close-tester
    BeginTest("GE_Emergency_20PctDD_TriggersClose");
    Test_GE_Emergency_20PctDD_TriggersClose();
    EndTest();

    BeginTest("GE_Emergency_Below20_NoClose");
    Test_GE_Emergency_Below20_NoClose();
    EndTest();

    // Evaluate-tester
    BeginTest("GE_Evaluate_ReturnsNextLevelInfo");
    Test_GE_Evaluate_ReturnsNextLevelInfo();
    EndTest();

    BeginTest("GE_Evaluate_NotInitialized_Blocks");
    Test_GE_Evaluate_NotInitialized_Blocks();
    EndTest();

    Print("=== GRIDENGINE TESTS COMPLETE ===");
    Print("");
}

//+------------------------------------------------------------------+
