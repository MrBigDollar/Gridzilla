//+------------------------------------------------------------------+
//|                                                  TestRunner.mq5   |
//|                                Copyright 2024, Gridzilla Project  |
//+------------------------------------------------------------------+
#property copyright "Gridzilla Project"
#property version   "1.00"
#property description "Gridzilla Test Runner - Kör alla enhetstester"
#property strict

//--- Inkludera testramverk
#include "TestAssertions.mqh"

//--- Inkludera enhetstester
#include "unit\TestMathUtils.mqh"
#include "unit\TestTimeUtils.mqh"
#include "unit\TestNormalizationUtils.mqh"
#include "unit\TestMarketStateManager.mqh"
#include "unit\TestEntryEngine.mqh"
#include "unit\TestPositionManager.mqh"
#include "unit\TestRiskEngine.mqh"
#include "unit\TestGridEngine.mqh"

//--- Input-parametrar
input bool RUN_ALL_TESTS = true;          // Kör alla tester
input string TEST_FILTER = "";             // Filtrera på testnamn (tom = alla)
input bool VERBOSE_OUTPUT = true;          // Detaljerad output

//--- Global tidmätning
uint g_runner_start_time = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit() {
    Print("");
    Print("========================================");
    Print("GRIDZILLA TEST RUNNER");
    Print("========================================");
    Print("Starting at: ", TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS));
    Print("");

    g_runner_start_time = GetTickCount();

    // Initiera testramverket
    InitializeTestFramework();

    // Kör alla testsviter
    RunAllTestSuites();

    // Skriv ut sammanfattning
    PrintTestSummary();

    uint total_duration = GetTickCount() - g_runner_start_time;
    Print("");
    Print("Total execution time: ", total_duration, " ms");
    Print("========================================");

    // Returnera INIT_FAILED för att avsluta Strategy Tester direkt
    // Detta är avsiktligt - vi vill bara köra testerna, inte fortsätta
    return INIT_FAILED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    // Cleanup om nödvändigt
}

//+------------------------------------------------------------------+
//| Expert tick function                                               |
//+------------------------------------------------------------------+
void OnTick() {
    // Tester körs i OnInit, inte här
}

//+------------------------------------------------------------------+
//| RunAllTestSuites - Kör alla registrerade testsviter                |
//+------------------------------------------------------------------+
void RunAllTestSuites() {
    // Kör MathUtils-tester
    RunMathUtilsTests();

    // Kör TimeUtils-tester
    RunTimeUtilsTests();

    // Kör NormalizationUtils-tester
    RunNormalizationUtilsTests();

    // Kör MarketStateManager-tester (FAS 1)
    RunMarketStateManagerTests();

    // Kör EntryEngine-tester (FAS 2)
    RunEntryEngineTests();

    // Kör PositionManager-tester (FAS 3)
    RunPositionManagerTests();

    // Kör RiskEngine-tester (FAS 3)
    RunRiskEngineTests();

    // Kör GridEngine-tester (FAS 4)
    RunGridEngineTests();

    // Lägg till fler testsviter här efterhand:
    // RunStructuredLoggerTests();
    // RunMockDataProviderTests();
    // RunMockOrderExecutorTests();
    // RunReplayEngineTests();
}

//+------------------------------------------------------------------+
//| ShouldRunTest - Kontrollera om test ska köras baserat på filter    |
//+------------------------------------------------------------------+
bool ShouldRunTest(string test_name) {
    if (!RUN_ALL_TESTS) return false;
    if (TEST_FILTER == "") return true;
    return StringFind(test_name, TEST_FILTER) >= 0;
}

//+------------------------------------------------------------------+
