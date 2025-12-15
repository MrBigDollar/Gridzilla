//+------------------------------------------------------------------+
//|                                           StructuredLogger.mqh    |
//|                                Copyright 2024, Gridzilla Project  |
//+------------------------------------------------------------------+
#property copyright "Gridzilla Project"
#property version   "1.00"
#property strict

#include "..\src\interfaces\ILogger.mqh"

//+------------------------------------------------------------------+
//| CStructuredLogger - JSON-baserad logger                           |
//|                                                                   |
//| Syfte: Logga alla händelser i strukturerat JSON-format som kan    |
//| parsas av externa analysverktyg. Varje loggpost innehåller:       |
//| - t: timestamp                                                    |
//| - module: källmodul                                               |
//| - event: händelsetyp                                              |
//| - inputs/outputs: relevant data                                   |
//| - confidence: förtroendenivå (för AI-beslut)                      |
//+------------------------------------------------------------------+
class CStructuredLogger : public ILogger {
private:
    int              m_file_handle;     // Filhandle för loggfil
    string           m_file_path;       // Sökväg till loggfil
    ENUM_LOG_LEVEL   m_log_level;       // Minsta loggnivå
    bool             m_console_output;  // Skriv även till konsol
    bool             m_initialized;     // Är loggern initierad?

    //--- Buffer för batched skrivningar
    string           m_buffer[];
    int              m_buffer_count;
    int              m_buffer_max;

    //+------------------------------------------------------------------+
    //| Formatera timestamp till ISO 8601-liknande format                 |
    //+------------------------------------------------------------------+
    string FormatTimestamp(datetime time) {
        MqlDateTime dt;
        TimeToStruct(time, dt);

        return StringFormat("%04d-%02d-%02d %02d:%02d:%02d",
                            dt.year, dt.mon, dt.day,
                            dt.hour, dt.min, dt.sec);
    }

    //+------------------------------------------------------------------+
    //| Escape JSON-sträng (hantera specialtecken)                        |
    //+------------------------------------------------------------------+
    string EscapeJsonString(string input) {
        string result = input;

        // Escape backslash först
        StringReplace(result, "\\", "\\\\");
        // Escape citattecken
        StringReplace(result, "\"", "\\\"");
        // Escape newlines
        StringReplace(result, "\n", "\\n");
        StringReplace(result, "\r", "\\r");
        // Escape tabs
        StringReplace(result, "\t", "\\t");

        return result;
    }

    //+------------------------------------------------------------------+
    //| Skriv en rad till fil och/eller konsol                           |
    //+------------------------------------------------------------------+
    void WriteLogLine(string json_line) {
        // Skriv till konsol om aktiverat
        if (m_console_output) {
            Print(json_line);
        }

        // Lägg till i buffer
        if (m_buffer_count < m_buffer_max) {
            m_buffer[m_buffer_count] = json_line;
            m_buffer_count++;
        }

        // Flush om buffer är full
        if (m_buffer_count >= m_buffer_max) {
            FlushBuffer();
        }
    }

    //+------------------------------------------------------------------+
    //| Skriv buffer till fil                                            |
    //+------------------------------------------------------------------+
    void FlushBuffer() {
        if (m_file_handle == INVALID_HANDLE || m_buffer_count == 0)
            return;

        for (int i = 0; i < m_buffer_count; i++) {
            FileWriteString(m_file_handle, m_buffer[i] + "\n");
        }

        FileFlush(m_file_handle);
        m_buffer_count = 0;
    }

    //+------------------------------------------------------------------+
    //| Konvertera loggnivå till sträng                                   |
    //+------------------------------------------------------------------+
    string LogLevelToString(ENUM_LOG_LEVEL level) {
        switch (level) {
            case LOG_DEBUG:    return "DEBUG";
            case LOG_INFO:     return "INFO";
            case LOG_WARNING:  return "WARNING";
            case LOG_ERROR:    return "ERROR";
            case LOG_CRITICAL: return "CRITICAL";
            default:           return "UNKNOWN";
        }
    }

public:
    //+------------------------------------------------------------------+
    //| Konstruktor                                                       |
    //+------------------------------------------------------------------+
    CStructuredLogger() {
        m_file_handle = INVALID_HANDLE;
        m_file_path = "";
        m_log_level = LOG_INFO;
        m_console_output = true;
        m_initialized = false;
        m_buffer_count = 0;
        m_buffer_max = 100;
        ArrayResize(m_buffer, m_buffer_max);
    }

    //+------------------------------------------------------------------+
    //| Destruktor                                                        |
    //+------------------------------------------------------------------+
    ~CStructuredLogger() {
        if (m_initialized) {
            FlushBuffer();
            if (m_file_handle != INVALID_HANDLE) {
                FileClose(m_file_handle);
            }
        }
    }

    //+------------------------------------------------------------------+
    //| Initialisera loggern                                              |
    //|                                                                   |
    //| file_path: Sökväg till loggfil (relativ till MQL5/Files/)         |
    //| level: Minsta loggnivå                                            |
    //| console_output: Skriv även till konsol (Print)                    |
    //| buffer_size: Antal rader att buffra innan skrivning               |
    //+------------------------------------------------------------------+
    bool Initialize(string file_path,
                    ENUM_LOG_LEVEL level = LOG_INFO,
                    bool console_output = true,
                    int buffer_size = 100) {
        m_file_path = file_path;
        m_log_level = level;
        m_console_output = console_output;
        m_buffer_max = buffer_size;
        ArrayResize(m_buffer, m_buffer_max);
        m_buffer_count = 0;

        // Öppna loggfil (skapa om den inte finns, annars append)
        m_file_handle = FileOpen(file_path,
                                 FILE_WRITE | FILE_READ | FILE_TXT | FILE_ANSI |
                                 FILE_SHARE_READ | FILE_SHARE_WRITE);

        if (m_file_handle == INVALID_HANDLE) {
            Print("ERROR: Could not open log file: ", file_path,
                  " Error: ", GetLastError());
            return false;
        }

        // Gå till slutet av filen för append
        FileSeek(m_file_handle, 0, SEEK_END);

        m_initialized = true;

        // Logga startup
        LogInfo("StructuredLogger", "Logger initialized: " + file_path);

        return true;
    }

    //+------------------------------------------------------------------+
    //| LogDecision - Logga AI/strategi-beslut                            |
    //+------------------------------------------------------------------+
    virtual void LogDecision(string module,
                             string event,
                             string inputs,
                             string outputs,
                             double confidence) override {
        if (!m_initialized) return;

        string json = StringFormat(
            "{\"t\":\"%s\",\"level\":\"DECISION\",\"module\":\"%s\",\"event\":\"%s\",\"inputs\":%s,\"outputs\":%s,\"confidence\":%.4f}",
            FormatTimestamp(TimeCurrent()),
            EscapeJsonString(module),
            EscapeJsonString(event),
            inputs,  // Förväntas redan vara valid JSON
            outputs, // Förväntas redan vara valid JSON
            confidence
        );

        WriteLogLine(json);
    }

    //+------------------------------------------------------------------+
    //| LogTrade - Logga traderelaterade händelser                        |
    //+------------------------------------------------------------------+
    virtual void LogTrade(string action,
                          long ticket,
                          string symbol,
                          double lots,
                          double price,
                          double sl,
                          double tp) override {
        if (!m_initialized) return;

        string json = StringFormat(
            "{\"t\":\"%s\",\"level\":\"TRADE\",\"action\":\"%s\",\"ticket\":%d,\"symbol\":\"%s\",\"lots\":%.2f,\"price\":%.5f,\"sl\":%.5f,\"tp\":%.5f}",
            FormatTimestamp(TimeCurrent()),
            EscapeJsonString(action),
            ticket,
            EscapeJsonString(symbol),
            lots,
            price,
            sl,
            tp
        );

        WriteLogLine(json);
    }

    //+------------------------------------------------------------------+
    //| LogWarning - Logga varning                                        |
    //+------------------------------------------------------------------+
    virtual void LogWarning(string module, string message) override {
        if (!m_initialized) return;
        if (m_log_level > LOG_WARNING) return;

        string json = StringFormat(
            "{\"t\":\"%s\",\"level\":\"WARNING\",\"module\":\"%s\",\"message\":\"%s\"}",
            FormatTimestamp(TimeCurrent()),
            EscapeJsonString(module),
            EscapeJsonString(message)
        );

        WriteLogLine(json);
    }

    //+------------------------------------------------------------------+
    //| LogError - Logga fel                                              |
    //+------------------------------------------------------------------+
    virtual void LogError(string module, string message, int error_code = 0) override {
        if (!m_initialized) return;
        if (m_log_level > LOG_ERROR) return;

        string json = StringFormat(
            "{\"t\":\"%s\",\"level\":\"ERROR\",\"module\":\"%s\",\"message\":\"%s\",\"error_code\":%d}",
            FormatTimestamp(TimeCurrent()),
            EscapeJsonString(module),
            EscapeJsonString(message),
            error_code
        );

        WriteLogLine(json);
    }

    //+------------------------------------------------------------------+
    //| LogDebug - Logga debug-information                                |
    //+------------------------------------------------------------------+
    virtual void LogDebug(string module, string message) override {
        if (!m_initialized) return;
        if (m_log_level > LOG_DEBUG) return;

        string json = StringFormat(
            "{\"t\":\"%s\",\"level\":\"DEBUG\",\"module\":\"%s\",\"message\":\"%s\"}",
            FormatTimestamp(TimeCurrent()),
            EscapeJsonString(module),
            EscapeJsonString(message)
        );

        WriteLogLine(json);
    }

    //+------------------------------------------------------------------+
    //| LogInfo - Logga information                                       |
    //+------------------------------------------------------------------+
    virtual void LogInfo(string module, string message) override {
        if (!m_initialized) return;
        if (m_log_level > LOG_INFO) return;

        string json = StringFormat(
            "{\"t\":\"%s\",\"level\":\"INFO\",\"module\":\"%s\",\"message\":\"%s\"}",
            FormatTimestamp(TimeCurrent()),
            EscapeJsonString(module),
            EscapeJsonString(message)
        );

        WriteLogLine(json);
    }

    //+------------------------------------------------------------------+
    //| SetLogLevel - Sätt minsta loggnivå                                |
    //+------------------------------------------------------------------+
    virtual void SetLogLevel(ENUM_LOG_LEVEL level) override {
        m_log_level = level;
    }

    //+------------------------------------------------------------------+
    //| GetLogLevel - Hämta nuvarande loggnivå                            |
    //+------------------------------------------------------------------+
    virtual ENUM_LOG_LEVEL GetLogLevel() override {
        return m_log_level;
    }

    //+------------------------------------------------------------------+
    //| Flush - Forcera skrivning till fil                                |
    //+------------------------------------------------------------------+
    virtual void Flush() override {
        FlushBuffer();
    }

    //+------------------------------------------------------------------+
    //| SetConsoleOutput - Aktivera/inaktivera konsol-output              |
    //+------------------------------------------------------------------+
    void SetConsoleOutput(bool enabled) {
        m_console_output = enabled;
    }

    //+------------------------------------------------------------------+
    //| IsInitialized - Kontrollera om loggern är initierad               |
    //+------------------------------------------------------------------+
    bool IsInitialized() {
        return m_initialized;
    }

    //+------------------------------------------------------------------+
    //| LogCustom - Logga anpassat meddelande med extra data              |
    //+------------------------------------------------------------------+
    void LogCustom(string module, string event, string data_json) {
        if (!m_initialized) return;

        string json = StringFormat(
            "{\"t\":\"%s\",\"level\":\"CUSTOM\",\"module\":\"%s\",\"event\":\"%s\",\"data\":%s}",
            FormatTimestamp(TimeCurrent()),
            EscapeJsonString(module),
            EscapeJsonString(event),
            data_json
        );

        WriteLogLine(json);
    }
};

//+------------------------------------------------------------------+
