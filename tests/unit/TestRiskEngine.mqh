//+------------------------------------------------------------------+
//|                                              TestRiskEngine.mqh   |
//|                                Copyright 2024, Gridzilla Project  |
//+------------------------------------------------------------------+
#property copyright "Gridzilla Project"
#property version   "1.00"
#property strict

#include "..\TestAssertions.mqh"
#include "..\..\src\core\RiskEngine.mqh"
#include "..\..\src\mocks\CMockDataProvider.mqh"
#include "..\..\src\mocks\CMockOrderExecutor.mqh"
#include "..\..\src\mocks\CMockLogger.mqh"

//+------------------------------------------------------------------+
//| Globala testvariabler                                             |
//+------------------------------------------------------------------+
CMockDataProvider*   g_re_data = NULL;
CMockOrderExecutor*  g_re_executor = NULL;
CMockLogger*         g_re_logger = NULL;
CPositionManager*    g_re_pm = NULL;
CRiskEngine*         g_re = NULL;

//+------------------------------------------------------------------+
//| SetupRiskEngineTest - Initiera test-environment                   |
//+------------------------------------------------------------------+
void SetupRiskEngineTest() {
    // Rensa tidigare
    if (g_re != NULL) { delete g_re; g_re = NULL; }
    if (g_re_pm != NULL) { delete g_re_pm; g_re_pm = NULL; }
    if (g_re_data != NULL) { delete g_re_data; g_re_data = NULL; }
    if (g_re_executor != NULL) { delete g_re_executor; g_re_executor = NULL; }
    if (g_re_logger != NULL) { delete g_re_logger; g_re_logger = NULL; }

    // Skapa nya instanser
    g_re_data = new CMockDataProvider();
    g_re_executor = new CMockOrderExecutor();
    g_re_logger = new CMockLogger();

    // Konfigurera standardvärden
    g_re_data.SetPrices(1.0850, 1.0852);
    g_re_data.SetAccountInfo(10000.0, 10000.0, 10000.0);
    g_re_data.SetSymbolInfo("EURUSD", 0.00001, 5);
    g_re_data.SetTime(D'2024.01.15 10:00', D'2024.01.15 10:00', 0);

    g_re_executor.SetTradeAllowed(true);
    g_re_executor.SetCurrentPrices(1.0850, 1.0852);  // Synka med dataprovider

    // Skapa PositionManager
    g_re_pm = new CPositionManager(g_re_data, g_re_executor, g_re_logger);
    g_re_pm.Initialize("EURUSD", 12345);

    // Skapa RiskEngine
    g_re = new CRiskEngine(g_re_data, g_re_executor, g_re_logger, g_re_pm);
    g_re.Initialize("EURUSD", 12345);
}

//+------------------------------------------------------------------+
//| CleanupRiskEngineTest - Städa upp efter test                      |
//+------------------------------------------------------------------+
void CleanupRiskEngineTest() {
    if (g_re != NULL) { delete g_re; g_re = NULL; }
    if (g_re_pm != NULL) { delete g_re_pm; g_re_pm = NULL; }
    if (g_re_data != NULL) { delete g_re_data; g_re_data = NULL; }
    if (g_re_executor != NULL) { delete g_re_executor; g_re_executor = NULL; }
    if (g_re_logger != NULL) { delete g_re_logger; g_re_logger = NULL; }
}

//+------------------------------------------------------------------+
//| CreateTestState - Skapa teststate med specifika värden            |
//+------------------------------------------------------------------+
PositionManagerState CreateTestState(double dd_pct, double total_lots,
                                     int position_count, int age_hours) {
    PositionManagerState state;
    state.current_drawdown_pct = dd_pct;
    state.total_lots = total_lots;
    state.position_count = position_count;
    state.position_age_hours = age_hours;
    return state;
}

//=== DRAWDOWN LIMIT TESTER ===

//+------------------------------------------------------------------+
//| Test_DDLimit_Below15_AllowsEntry                                  |
//+------------------------------------------------------------------+
void Test_DDLimit_Below15_AllowsEntry() {
    BeginTest("DDLimit_Below15_AllowsEntry");

    SetupRiskEngineTest();

    PositionManagerState state = CreateTestState(14.9, 0.0, 0, 0);
    string reason = "";

    bool allowed = g_re.CheckDDLimitPublic(state, reason);

    AssertTrue(allowed, "14.9% DD should allow entry");
    AssertEqual("", reason, "No reason should be set");

    CleanupRiskEngineTest();
    EndTest();
}

//+------------------------------------------------------------------+
//| Test_DDLimit_At15_BlocksEntry                                     |
//+------------------------------------------------------------------+
void Test_DDLimit_At15_BlocksEntry() {
    BeginTest("DDLimit_At15_BlocksEntry");

    SetupRiskEngineTest();

    PositionManagerState state = CreateTestState(15.0, 0.0, 0, 0);
    string reason = "";

    bool allowed = g_re.CheckDDLimitPublic(state, reason);

    AssertFalse(allowed, "15.0% DD should block entry");
    AssertTrue(StringLen(reason) > 0, "Reason should be set");

    CleanupRiskEngineTest();
    EndTest();
}

//+------------------------------------------------------------------+
//| Test_DDLimit_Above15_BlocksEntry                                  |
//+------------------------------------------------------------------+
void Test_DDLimit_Above15_BlocksEntry() {
    BeginTest("DDLimit_Above15_BlocksEntry");

    SetupRiskEngineTest();

    PositionManagerState state = CreateTestState(16.0, 0.0, 0, 0);
    string reason = "";

    bool allowed = g_re.CheckDDLimitPublic(state, reason);

    AssertFalse(allowed, "16.0% DD should block entry");

    CleanupRiskEngineTest();
    EndTest();
}

//=== MAX LOTS TESTER ===

//+------------------------------------------------------------------+
//| Test_MaxLots_Below5_AllowsEntry                                   |
//+------------------------------------------------------------------+
void Test_MaxLots_Below5_AllowsEntry() {
    BeginTest("MaxLots_Below5_AllowsEntry");

    SetupRiskEngineTest();

    PositionManagerState state = CreateTestState(0.0, 4.9, 0, 0);
    string reason = "";

    bool allowed = g_re.CheckMaxLotsPublic(state, reason);

    AssertTrue(allowed, "4.9 lots should allow entry");

    CleanupRiskEngineTest();
    EndTest();
}

//+------------------------------------------------------------------+
//| Test_MaxLots_At5_BlocksEntry                                      |
//+------------------------------------------------------------------+
void Test_MaxLots_At5_BlocksEntry() {
    BeginTest("MaxLots_At5_BlocksEntry");

    SetupRiskEngineTest();

    PositionManagerState state = CreateTestState(0.0, 5.0, 0, 0);
    string reason = "";

    bool allowed = g_re.CheckMaxLotsPublic(state, reason);

    AssertFalse(allowed, "5.0 lots should block entry");
    AssertTrue(StringLen(reason) > 0, "Reason should be set");

    CleanupRiskEngineTest();
    EndTest();
}

//+------------------------------------------------------------------+
//| Test_MaxLots_Above5_BlocksEntry                                   |
//+------------------------------------------------------------------+
void Test_MaxLots_Above5_BlocksEntry() {
    BeginTest("MaxLots_Above5_BlocksEntry");

    SetupRiskEngineTest();

    PositionManagerState state = CreateTestState(0.0, 5.5, 0, 0);
    string reason = "";

    bool allowed = g_re.CheckMaxLotsPublic(state, reason);

    AssertFalse(allowed, "5.5 lots should block entry");

    CleanupRiskEngineTest();
    EndTest();
}

//=== MAX GRID LEVELS TESTER ===

//+------------------------------------------------------------------+
//| Test_MaxLevels_Below8_AllowsEntry                                 |
//+------------------------------------------------------------------+
void Test_MaxLevels_Below8_AllowsEntry() {
    BeginTest("MaxLevels_Below8_AllowsEntry");

    SetupRiskEngineTest();

    PositionManagerState state = CreateTestState(0.0, 0.0, 7, 0);
    string reason = "";

    bool allowed = g_re.CheckMaxLevelsPublic(state, reason);

    AssertTrue(allowed, "7 positions should allow entry");

    CleanupRiskEngineTest();
    EndTest();
}

//+------------------------------------------------------------------+
//| Test_MaxLevels_At8_BlocksEntry                                    |
//+------------------------------------------------------------------+
void Test_MaxLevels_At8_BlocksEntry() {
    BeginTest("MaxLevels_At8_BlocksEntry");

    SetupRiskEngineTest();

    PositionManagerState state = CreateTestState(0.0, 0.0, 8, 0);
    string reason = "";

    bool allowed = g_re.CheckMaxLevelsPublic(state, reason);

    AssertFalse(allowed, "8 positions should block entry");
    AssertTrue(StringLen(reason) > 0, "Reason should be set");

    CleanupRiskEngineTest();
    EndTest();
}

//=== EMERGENCY CLOSE TESTER ===

//+------------------------------------------------------------------+
//| Test_Emergency_Below20_NoClose                                    |
//+------------------------------------------------------------------+
void Test_Emergency_Below20_NoClose() {
    BeginTest("Emergency_Below20_NoClose");

    SetupRiskEngineTest();

    PositionManagerState state = CreateTestState(19.0, 0.0, 0, 0);

    bool emergency = g_re.CheckEmergencyPublic(state);

    AssertFalse(emergency, "19% DD should NOT trigger emergency close");

    CleanupRiskEngineTest();
    EndTest();
}

//+------------------------------------------------------------------+
//| Test_Emergency_At20_RequiresClose                                 |
//+------------------------------------------------------------------+
void Test_Emergency_At20_RequiresClose() {
    BeginTest("Emergency_At20_RequiresClose");

    SetupRiskEngineTest();

    PositionManagerState state = CreateTestState(20.0, 0.0, 0, 0);

    bool emergency = g_re.CheckEmergencyPublic(state);

    AssertTrue(emergency, "20% DD should trigger emergency close");

    CleanupRiskEngineTest();
    EndTest();
}

//+------------------------------------------------------------------+
//| Test_Emergency_Above20_RequiresClose                              |
//+------------------------------------------------------------------+
void Test_Emergency_Above20_RequiresClose() {
    BeginTest("Emergency_Above20_RequiresClose");

    SetupRiskEngineTest();

    PositionManagerState state = CreateTestState(25.0, 0.0, 0, 0);

    bool emergency = g_re.CheckEmergencyPublic(state);

    AssertTrue(emergency, "25% DD should trigger emergency close");

    CleanupRiskEngineTest();
    EndTest();
}

//=== GRID AGE TESTER ===

//+------------------------------------------------------------------+
//| Test_GridAge_Below72h_Allows                                      |
//+------------------------------------------------------------------+
void Test_GridAge_Below72h_Allows() {
    BeginTest("GridAge_Below72h_Allows");

    SetupRiskEngineTest();

    PositionManagerState state = CreateTestState(0.0, 0.0, 1, 71);
    string reason = "";

    bool allowed = g_re.CheckAgePublic(state, reason);

    AssertTrue(allowed, "71 hours should allow");

    CleanupRiskEngineTest();
    EndTest();
}

//+------------------------------------------------------------------+
//| Test_GridAge_At72h_Blocks                                         |
//+------------------------------------------------------------------+
void Test_GridAge_At72h_Blocks() {
    BeginTest("GridAge_At72h_Blocks");

    SetupRiskEngineTest();

    PositionManagerState state = CreateTestState(0.0, 0.0, 1, 72);
    string reason = "";

    bool allowed = g_re.CheckAgePublic(state, reason);

    AssertFalse(allowed, "72 hours should block");
    AssertTrue(StringLen(reason) > 0, "Reason should be set");

    CleanupRiskEngineTest();
    EndTest();
}

//=== KOMBINERADE TESTER ===

//+------------------------------------------------------------------+
//| Test_AllLimitsOK_AllowsEntry                                      |
//+------------------------------------------------------------------+
void Test_AllLimitsOK_AllowsEntry() {
    BeginTest("AllLimitsOK_AllowsEntry");

    SetupRiskEngineTest();

    // Alla värden inom gränser
    PositionManagerState state = CreateTestState(5.0, 1.0, 2, 24);

    RiskDecision decision = g_re.EvaluateWithState(state);

    AssertTrue(decision.allow_new_entry, "All limits OK should allow entry");
    AssertTrue(decision.allow_grid_expansion, "All limits OK should allow grid expansion");
    AssertFalse(decision.require_emergency_close, "Should NOT require emergency close");
    AssertEqual("", decision.block_reason, "No block reason");

    CleanupRiskEngineTest();
    EndTest();
}

//+------------------------------------------------------------------+
//| Test_OneLimitBreached_Blocks                                      |
//+------------------------------------------------------------------+
void Test_OneLimitBreached_Blocks() {
    BeginTest("OneLimitBreached_Blocks");

    SetupRiskEngineTest();

    // DD över gräns, resten OK
    PositionManagerState state = CreateTestState(16.0, 1.0, 2, 24);

    RiskDecision decision = g_re.EvaluateWithState(state);

    AssertFalse(decision.allow_new_entry, "One limit breached should block entry");
    AssertFalse(decision.allow_grid_expansion, "One limit breached should block expansion");
    AssertTrue(StringLen(decision.block_reason) > 0, "Should have block reason");

    CleanupRiskEngineTest();
    EndTest();
}

//+------------------------------------------------------------------+
//| Test_EmergencyOverridesAll                                        |
//+------------------------------------------------------------------+
void Test_EmergencyOverridesAll() {
    BeginTest("EmergencyOverridesAll");

    SetupRiskEngineTest();

    // Emergency DD (20%+)
    PositionManagerState state = CreateTestState(22.0, 1.0, 2, 24);

    RiskDecision decision = g_re.EvaluateWithState(state);

    AssertTrue(decision.require_emergency_close, "Should require emergency close");
    AssertNear(1.0, decision.current_risk_score, 0.01, "Risk score should be 1.0");
    AssertTrue(StringFind(decision.block_reason, "EMERGENCY") >= 0, "Reason should mention EMERGENCY");

    CleanupRiskEngineTest();
    EndTest();
}

//+------------------------------------------------------------------+
//| Test_RiskScore_IncreasesWithRisk                                  |
//+------------------------------------------------------------------+
void Test_RiskScore_IncreasesWithRisk() {
    BeginTest("RiskScore_IncreasesWithRisk");

    SetupRiskEngineTest();

    // Låg risk
    PositionManagerState low_risk = CreateTestState(2.0, 0.5, 1, 12);
    RiskDecision decision_low = g_re.EvaluateWithState(low_risk);

    // Hög risk (men under emergency)
    PositionManagerState high_risk = CreateTestState(14.0, 4.5, 7, 70);
    RiskDecision decision_high = g_re.EvaluateWithState(high_risk);

    AssertTrue(decision_high.current_risk_score > decision_low.current_risk_score,
              "Higher risk should have higher score");
    AssertTrue(decision_low.current_risk_score < 0.5, "Low risk should have low score");
    AssertTrue(decision_high.current_risk_score > 0.5, "High risk should have high score");

    CleanupRiskEngineTest();
    EndTest();
}

//+------------------------------------------------------------------+
//| Test_CustomLimits_AreRespected                                    |
//+------------------------------------------------------------------+
void Test_CustomLimits_AreRespected() {
    BeginTest("CustomLimits_AreRespected");

    SetupRiskEngineTest();

    // Sätt strängare limits
    HardLimits strict_limits;
    strict_limits.max_drawdown_pct = 10.0;  // Strängare än default 15%
    strict_limits.max_total_lots = 2.0;     // Strängare än default 5.0
    strict_limits.max_grid_levels = 4;      // Strängare än default 8
    strict_limits.max_grid_age_hours = 24;  // Strängare än default 72
    strict_limits.emergency_close_dd_pct = 15.0;  // Strängare än default 20%

    g_re.SetLimits(strict_limits);

    // Skapa state som passerar default limits men inte strängare
    PositionManagerState state = CreateTestState(12.0, 2.5, 5, 48);

    RiskDecision decision = g_re.EvaluateWithState(state);

    AssertFalse(decision.allow_new_entry, "Should be blocked with stricter limits");

    CleanupRiskEngineTest();
    EndTest();
}

//+------------------------------------------------------------------+
//| RunRiskEngineTests - Kör alla RiskEngine-tester                   |
//+------------------------------------------------------------------+
void RunRiskEngineTests() {
    BeginTestSuite("RiskEngine");

    // DD-limit tester
    Test_DDLimit_Below15_AllowsEntry();
    Test_DDLimit_At15_BlocksEntry();
    Test_DDLimit_Above15_BlocksEntry();

    // Max lots tester
    Test_MaxLots_Below5_AllowsEntry();
    Test_MaxLots_At5_BlocksEntry();
    Test_MaxLots_Above5_BlocksEntry();

    // Max levels tester
    Test_MaxLevels_Below8_AllowsEntry();
    Test_MaxLevels_At8_BlocksEntry();

    // Emergency close tester
    Test_Emergency_Below20_NoClose();
    Test_Emergency_At20_RequiresClose();
    Test_Emergency_Above20_RequiresClose();

    // Grid age tester
    Test_GridAge_Below72h_Allows();
    Test_GridAge_At72h_Blocks();

    // Kombinerade tester
    Test_AllLimitsOK_AllowsEntry();
    Test_OneLimitBreached_Blocks();
    Test_EmergencyOverridesAll();
    Test_RiskScore_IncreasesWithRisk();
    Test_CustomLimits_AreRespected();

    EndTestSuite();
}

//+------------------------------------------------------------------+
