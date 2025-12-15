//+------------------------------------------------------------------+
//|                                                      ILogger.mqh  |
//|                                Copyright 2024, Gridzilla Project  |
//+------------------------------------------------------------------+
#property copyright "Gridzilla Project"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Logg-nivåer                                                       |
//+------------------------------------------------------------------+
enum ENUM_LOG_LEVEL {
    LOG_DEBUG = 0,
    LOG_INFO = 1,
    LOG_WARNING = 2,
    LOG_ERROR = 3,
    LOG_CRITICAL = 4
};

//+------------------------------------------------------------------+
//| ILogger - Abstrakt basklass för loggning                          |
//|                                                                   |
//| Syfte: Abstrahera loggning från konkret implementation.           |
//| Alla moduler ska använda detta interface istället för Print().    |
//+------------------------------------------------------------------+
class ILogger {
public:
    //--- Destruktor
    virtual ~ILogger() {}

    //--- Besluts-loggning (för AI och strategi-beslut)
    //    module: Källmodul (t.ex. "GridEngine", "EntryEngine")
    //    event: Händelsetyp (t.ex. "ADD_LEVEL", "ENTRY_SIGNAL")
    //    inputs: JSON-sträng med input-data
    //    outputs: JSON-sträng med output-data
    //    confidence: Förtroendenivå [0.0 - 1.0]
    virtual void LogDecision(string module,
                             string event,
                             string inputs,
                             string outputs,
                             double confidence) = 0;

    //--- Trade-loggning (för orderhantering)
    //    action: "OPEN", "CLOSE", "MODIFY"
    //    ticket: Order/position ticket
    //    symbol: Handelsinstrument
    //    lots: Volym
    //    price: Pris
    //    sl: Stop Loss
    //    tp: Take Profit
    virtual void LogTrade(string action,
                          long ticket,
                          string symbol,
                          double lots,
                          double price,
                          double sl,
                          double tp) = 0;

    //--- Varnings-loggning
    virtual void LogWarning(string module, string message) = 0;

    //--- Fel-loggning
    //    error_code: Valfri felkod (0 = inget specifikt fel)
    virtual void LogError(string module, string message, int error_code = 0) = 0;

    //--- Debug-loggning (filtreras baserat på log level)
    virtual void LogDebug(string module, string message) = 0;

    //--- Info-loggning
    virtual void LogInfo(string module, string message) = 0;

    //--- Sätt minsta loggnivå
    virtual void SetLogLevel(ENUM_LOG_LEVEL level) = 0;

    //--- Hämta nuvarande loggnivå
    virtual ENUM_LOG_LEVEL GetLogLevel() = 0;

    //--- Forcera skrivning till fil/output
    virtual void Flush() = 0;
};

//+------------------------------------------------------------------+
