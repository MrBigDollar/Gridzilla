//+------------------------------------------------------------------+
//|                                                   Gridzilla.mq5   |
//|                                Copyright 2024, Gridzilla Project  |
//+------------------------------------------------------------------+
#property copyright "Gridzilla Project"
#property link      "https://github.com/MrBigDollar/Gridzilla"
#property version   "0.01"
#property description "Adaptive AI-Driven Grid Martingale Expert Advisor"
#property strict

//+------------------------------------------------------------------+
//| INKLUDERINGAR                                                     |
//+------------------------------------------------------------------+
// Interfaces
#include "interfaces\IDataProvider.mqh"
#include "interfaces\IOrderExecutor.mqh"
#include "interfaces\ILogger.mqh"

// Logging
#include "..\logging\StructuredLogger.mqh"

// Utils
#include "utils\MathUtils.mqh"
#include "utils\TimeUtils.mqh"
#include "utils\NormalizationUtils.mqh"

//+------------------------------------------------------------------+
//| INPUT-PARAMETRAR                                                  |
//+------------------------------------------------------------------+
input group "=== Grundinställningar ==="
input long      InpMagicNumber = 20241214;   // Magic Number
input double    InpBaseLotSize = 0.01;       // Bas lot-storlek
input string    InpLogFile = "Gridzilla.log"; // Loggfil

input group "=== Loggning ==="
input ENUM_LOG_LEVEL InpLogLevel = LOG_INFO; // Logg-nivå
input bool      InpConsoleOutput = true;     // Konsol-output

//+------------------------------------------------------------------+
//| GLOBALA VARIABLER                                                 |
//+------------------------------------------------------------------+
CStructuredLogger* g_logger = NULL;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit() {
    //--- Initiera logger
    g_logger = new CStructuredLogger();
    if (!g_logger.Initialize(InpLogFile, InpLogLevel, InpConsoleOutput)) {
        Print("ERROR: Failed to initialize logger");
        return INIT_FAILED;
    }

    g_logger.LogInfo("Gridzilla", "=== Gridzilla EA Initialized ===");
    g_logger.LogInfo("Gridzilla", StringFormat("Version: %s", "0.01"));
    g_logger.LogInfo("Gridzilla", StringFormat("Symbol: %s", _Symbol));
    g_logger.LogInfo("Gridzilla", StringFormat("Magic: %d", InpMagicNumber));

    //--- Validera symbol
    if (!SymbolSelect(_Symbol, true)) {
        g_logger.LogError("Gridzilla", "Failed to select symbol", GetLastError());
        return INIT_FAILED;
    }

    //--- FAS 0: Infrastruktur komplett
    //--- Moduler läggs till i kommande faser:
    //--- FAS 1: MarketStateManager
    //--- FAS 2: EntryEngine
    //--- FAS 3: PositionManager, RiskEngine
    //--- FAS 4: GridEngine
    //--- FAS 5: SafetyController
    //--- FAS 6-7: ONNXBridge

    g_logger.LogInfo("Gridzilla", "Initialization complete");

    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    if (g_logger != NULL) {
        g_logger.LogInfo("Gridzilla", StringFormat("Deinitializing. Reason: %d", reason));
        g_logger.Flush();
        delete g_logger;
        g_logger = NULL;
    }
}

//+------------------------------------------------------------------+
//| Expert tick function                                               |
//+------------------------------------------------------------------+
void OnTick() {
    //--- FAS 0: Skeleton - ingen tradinglogik än
    //--- Framtida implementation:
    //--- 1. Hämta MarketState
    //--- 2. Kör ONNX inference (FAS 6+)
    //--- 3. Utvärdera entry-signaler (FAS 2)
    //--- 4. Hantera grid-logik (FAS 4)
    //--- 5. Tillämpa risk-kontroller (FAS 3)
    //--- 6. Kör safety checks (FAS 5)
}

//+------------------------------------------------------------------+
//| Trade event handler                                                |
//+------------------------------------------------------------------+
void OnTrade() {
    //--- Logga trade-events för debugging
    if (g_logger != NULL) {
        g_logger.LogDebug("Gridzilla", "Trade event received");
    }
}

//+------------------------------------------------------------------+
//| Timer event handler                                                |
//+------------------------------------------------------------------+
void OnTimer() {
    //--- Framtida: Periodisk housekeeping
}

//+------------------------------------------------------------------+
