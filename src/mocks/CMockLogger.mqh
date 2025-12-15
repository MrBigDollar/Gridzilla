//+------------------------------------------------------------------+
//|                                                 CMockLogger.mqh   |
//|                                Copyright 2024, Gridzilla Project  |
//+------------------------------------------------------------------+
#property copyright "Gridzilla Project"
#property version   "1.00"
#property strict

#include "..\interfaces\ILogger.mqh"

//+------------------------------------------------------------------+
//| LogEntry - Struct för att spara loggposter                        |
//+------------------------------------------------------------------+
struct LogEntry {
    datetime         time;
    ENUM_LOG_LEVEL   level;
    string           module;
    string           message;
    string           event;
    string           inputs;
    string           outputs;
    double           confidence;

    LogEntry() {
        time = 0;
        level = LOG_INFO;
        module = "";
        message = "";
        event = "";
        inputs = "";
        outputs = "";
        confidence = 0.0;
    }
};

//+------------------------------------------------------------------+
//| CMockLogger - Mock-logger för testning                            |
//|                                                                   |
//| Syfte: Fånga loggposter utan att skriva till fil/konsol.          |
//| Används i enhetstester för att verifiera att rätt loggning sker.  |
//+------------------------------------------------------------------+
class CMockLogger : public ILogger {
private:
    LogEntry         m_entries[];       // Sparade loggposter
    int              m_entry_count;     // Antal poster
    int              m_max_entries;     // Max antal poster
    ENUM_LOG_LEVEL   m_log_level;       // Minsta loggnivå
    bool             m_silent;          // Om true, spara inga poster (helt tyst)

public:
    //+------------------------------------------------------------------+
    //| Konstruktor                                                       |
    //+------------------------------------------------------------------+
    CMockLogger(int max_entries = 1000, bool silent = false) {
        m_max_entries = max_entries;
        m_entry_count = 0;
        m_log_level = LOG_DEBUG;  // Fånga allt som standard
        m_silent = silent;
        ArrayResize(m_entries, m_max_entries);
    }

    //+------------------------------------------------------------------+
    //| Destruktor                                                        |
    //+------------------------------------------------------------------+
    ~CMockLogger() {
        ArrayFree(m_entries);
    }

    //+------------------------------------------------------------------+
    //| AddEntry - Lägg till loggpost internt                             |
    //+------------------------------------------------------------------+
    void AddEntry(ENUM_LOG_LEVEL level, string module, string message,
                  string event = "", string inputs = "", string outputs = "",
                  double confidence = 0.0) {
        if (m_silent) return;
        if (level < m_log_level) return;
        if (m_entry_count >= m_max_entries) return;

        m_entries[m_entry_count].time = TimeCurrent();
        m_entries[m_entry_count].level = level;
        m_entries[m_entry_count].module = module;
        m_entries[m_entry_count].message = message;
        m_entries[m_entry_count].event = event;
        m_entries[m_entry_count].inputs = inputs;
        m_entries[m_entry_count].outputs = outputs;
        m_entries[m_entry_count].confidence = confidence;
        m_entry_count++;
    }

    //+------------------------------------------------------------------+
    //| LogDecision                                                       |
    //+------------------------------------------------------------------+
    virtual void LogDecision(string module,
                             string event,
                             string inputs,
                             string outputs,
                             double confidence) override {
        AddEntry(LOG_INFO, module, "", event, inputs, outputs, confidence);
    }

    //+------------------------------------------------------------------+
    //| LogTrade                                                          |
    //+------------------------------------------------------------------+
    virtual void LogTrade(string action,
                          long ticket,
                          string symbol,
                          double lots,
                          double price,
                          double sl,
                          double tp) override {
        string message = StringFormat("Trade: %s ticket=%d symbol=%s lots=%.2f price=%.5f",
                                      action, ticket, symbol, lots, price);
        AddEntry(LOG_INFO, "Trade", message, action);
    }

    //+------------------------------------------------------------------+
    //| LogWarning                                                        |
    //+------------------------------------------------------------------+
    virtual void LogWarning(string module, string message) override {
        AddEntry(LOG_WARNING, module, message);
    }

    //+------------------------------------------------------------------+
    //| LogError                                                          |
    //+------------------------------------------------------------------+
    virtual void LogError(string module, string message, int error_code = 0) override {
        string full_message = message;
        if (error_code != 0) {
            full_message = StringFormat("%s (code: %d)", message, error_code);
        }
        AddEntry(LOG_ERROR, module, full_message);
    }

    //+------------------------------------------------------------------+
    //| LogDebug                                                          |
    //+------------------------------------------------------------------+
    virtual void LogDebug(string module, string message) override {
        AddEntry(LOG_DEBUG, module, message);
    }

    //+------------------------------------------------------------------+
    //| LogInfo                                                           |
    //+------------------------------------------------------------------+
    virtual void LogInfo(string module, string message) override {
        AddEntry(LOG_INFO, module, message);
    }

    //+------------------------------------------------------------------+
    //| SetLogLevel                                                       |
    //+------------------------------------------------------------------+
    virtual void SetLogLevel(ENUM_LOG_LEVEL level) override {
        m_log_level = level;
    }

    //+------------------------------------------------------------------+
    //| GetLogLevel                                                       |
    //+------------------------------------------------------------------+
    virtual ENUM_LOG_LEVEL GetLogLevel() override {
        return m_log_level;
    }

    //+------------------------------------------------------------------+
    //| Flush - Gör ingenting i mock                                      |
    //+------------------------------------------------------------------+
    virtual void Flush() override {
        // Ingenting att flusha i mock
    }

    //=== MOCK-SPECIFIKA METODER (för testverifiering) ===

    //+------------------------------------------------------------------+
    //| GetEntryCount - Antal loggposter                                  |
    //+------------------------------------------------------------------+
    int GetEntryCount() {
        return m_entry_count;
    }

    //+------------------------------------------------------------------+
    //| GetEntry - Hämta specifik loggpost                                |
    //+------------------------------------------------------------------+
    bool GetEntry(int index, LogEntry &entry) {
        if (index < 0 || index >= m_entry_count) return false;
        entry = m_entries[index];
        return true;
    }

    //+------------------------------------------------------------------+
    //| GetLastEntry - Hämta senaste loggpost                             |
    //+------------------------------------------------------------------+
    bool GetLastEntry(LogEntry &entry) {
        if (m_entry_count == 0) return false;
        entry = m_entries[m_entry_count - 1];
        return true;
    }

    //+------------------------------------------------------------------+
    //| Clear - Rensa alla loggposter                                     |
    //+------------------------------------------------------------------+
    void Clear() {
        m_entry_count = 0;
    }

    //+------------------------------------------------------------------+
    //| SetSilent - Aktivera/inaktivera tyst läge                         |
    //+------------------------------------------------------------------+
    void SetSilent(bool silent) {
        m_silent = silent;
    }

    //+------------------------------------------------------------------+
    //| ContainsMessage - Kontrollera om viss text finns i loggarna       |
    //+------------------------------------------------------------------+
    bool ContainsMessage(string search_text) {
        for (int i = 0; i < m_entry_count; i++) {
            if (StringFind(m_entries[i].message, search_text) >= 0) {
                return true;
            }
        }
        return false;
    }

    //+------------------------------------------------------------------+
    //| ContainsModule - Kontrollera om viss modul finns i loggarna       |
    //+------------------------------------------------------------------+
    bool ContainsModule(string module_name) {
        for (int i = 0; i < m_entry_count; i++) {
            if (m_entries[i].module == module_name) {
                return true;
            }
        }
        return false;
    }

    //+------------------------------------------------------------------+
    //| CountByLevel - Räkna poster av viss nivå                          |
    //+------------------------------------------------------------------+
    int CountByLevel(ENUM_LOG_LEVEL level) {
        int count = 0;
        for (int i = 0; i < m_entry_count; i++) {
            if (m_entries[i].level == level) {
                count++;
            }
        }
        return count;
    }

    //+------------------------------------------------------------------+
    //| HasErrors - Finns det några fel i loggen?                         |
    //+------------------------------------------------------------------+
    bool HasErrors() {
        return CountByLevel(LOG_ERROR) > 0 || CountByLevel(LOG_CRITICAL) > 0;
    }

    //+------------------------------------------------------------------+
    //| HasWarnings - Finns det några varningar i loggen?                 |
    //+------------------------------------------------------------------+
    bool HasWarnings() {
        return CountByLevel(LOG_WARNING) > 0;
    }
};

//+------------------------------------------------------------------+
//| CNullLogger - Tyst logger som ignorerar allt                       |
//|                                                                   |
//| Syfte: Användas när ingen loggning behövs alls.                   |
//+------------------------------------------------------------------+
class CNullLogger : public ILogger {
private:
    ENUM_LOG_LEVEL m_log_level;

public:
    CNullLogger() { m_log_level = LOG_CRITICAL; }
    ~CNullLogger() {}

    virtual void LogDecision(string module, string event, string inputs,
                             string outputs, double confidence) override {}
    virtual void LogTrade(string action, long ticket, string symbol,
                          double lots, double price, double sl, double tp) override {}
    virtual void LogWarning(string module, string message) override {}
    virtual void LogError(string module, string message, int error_code = 0) override {}
    virtual void LogDebug(string module, string message) override {}
    virtual void LogInfo(string module, string message) override {}
    virtual void SetLogLevel(ENUM_LOG_LEVEL level) override { m_log_level = level; }
    virtual ENUM_LOG_LEVEL GetLogLevel() override { return m_log_level; }
    virtual void Flush() override {}
};

//+------------------------------------------------------------------+
