//+------------------------------------------------------------------+
//|                                               DataRecorder.mqh    |
//|                                Copyright 2024, Gridzilla Project  |
//+------------------------------------------------------------------+
#property copyright "Gridzilla Project"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| TickRecord - Struct för att spara tick-data                       |
//+------------------------------------------------------------------+
struct TickRecord {
    datetime time;              // Tid (sekundprecision)
    long     time_msc;          // Millisekunder
    double   bid;               // Bid-pris
    double   ask;               // Ask-pris
    long     volume;            // Volym
    int      flags;             // Tick-flaggor

    TickRecord() {
        time = 0;
        time_msc = 0;
        bid = 0;
        ask = 0;
        volume = 0;
        flags = 0;
    }
};

//+------------------------------------------------------------------+
//| RecordingSession - Metadata för inspelningssession                |
//+------------------------------------------------------------------+
struct RecordingSession {
    string   symbol;            // Handelsinstrument
    datetime start_time;        // Starttid
    datetime end_time;          // Sluttid
    int      tick_count;        // Antal ticks
    int      bar_count;         // Antal bars (M1)
    string   file_path;         // Sökväg till fil
    double   point;             // Point-värde
    int      digits;            // Antal decimaler

    RecordingSession() {
        symbol = "";
        start_time = 0;
        end_time = 0;
        tick_count = 0;
        bar_count = 0;
        file_path = "";
        point = 0;
        digits = 0;
    }
};

//+------------------------------------------------------------------+
//| CDataRecorder - Spelar in marknaddata för replay                  |
//|                                                                   |
//| Syfte: Spara tick- och bar-data för att senare kunna återspela    |
//| och verifiera determinism i systemet.                             |
//+------------------------------------------------------------------+
class CDataRecorder {
private:
    int              m_file_handle;
    string           m_file_path;
    string           m_symbol;
    bool             m_recording;
    RecordingSession m_session;

    //--- Buffer för effektiv skrivning
    TickRecord       m_tick_buffer[];
    int              m_buffer_index;
    int              m_buffer_size;

    //--- Bar-data (M1)
    MqlRates         m_bar_buffer[];
    int              m_bar_index;
    int              m_bar_buffer_size;

    //+------------------------------------------------------------------+
    //| FlushTickBuffer - Skriv tick-buffer till fil                      |
    //+------------------------------------------------------------------+
    void FlushTickBuffer() {
        if (m_file_handle == INVALID_HANDLE || m_buffer_index == 0)
            return;

        for (int i = 0; i < m_buffer_index; i++) {
            string line = StringFormat("%d,%d,%.5f,%.5f,%d,%d",
                                       (long)m_tick_buffer[i].time,
                                       m_tick_buffer[i].time_msc,
                                       m_tick_buffer[i].bid,
                                       m_tick_buffer[i].ask,
                                       m_tick_buffer[i].volume,
                                       m_tick_buffer[i].flags);
            FileWriteString(m_file_handle, line + "\n");
        }

        FileFlush(m_file_handle);
        m_buffer_index = 0;
    }

public:
    //+------------------------------------------------------------------+
    //| Konstruktor                                                       |
    //+------------------------------------------------------------------+
    CDataRecorder() {
        m_file_handle = INVALID_HANDLE;
        m_file_path = "";
        m_symbol = "";
        m_recording = false;
        m_buffer_index = 0;
        m_buffer_size = 1000;
        m_bar_index = 0;
        m_bar_buffer_size = 100;

        ArrayResize(m_tick_buffer, m_buffer_size);
        ArrayResize(m_bar_buffer, m_bar_buffer_size);
    }

    //+------------------------------------------------------------------+
    //| Destruktor                                                        |
    //+------------------------------------------------------------------+
    ~CDataRecorder() {
        if (m_recording) {
            StopRecording();
        }
        ArrayFree(m_tick_buffer);
        ArrayFree(m_bar_buffer);
    }

    //+------------------------------------------------------------------+
    //| StartRecording - Börja spela in data                              |
    //|                                                                   |
    //| symbol: Handelsinstrument                                         |
    //| file_path: Sökväg till fil (relativt MQL5/Files/)                 |
    //| buffer_size: Antal ticks att buffra                               |
    //+------------------------------------------------------------------+
    bool StartRecording(string symbol, string file_path, int buffer_size = 1000) {
        if (m_recording) {
            StopRecording();
        }

        m_symbol = symbol;
        m_file_path = file_path;
        m_buffer_size = buffer_size;
        m_buffer_index = 0;
        m_bar_index = 0;

        ArrayResize(m_tick_buffer, m_buffer_size);

        // Öppna fil för skrivning
        m_file_handle = FileOpen(file_path, FILE_WRITE | FILE_CSV | FILE_ANSI);
        if (m_file_handle == INVALID_HANDLE) {
            Print("ERROR: Could not open file for recording: ", file_path);
            return false;
        }

        // Skriv header
        FileWriteString(m_file_handle, "# Gridzilla Data Recording\n");
        FileWriteString(m_file_handle, "# Symbol: " + symbol + "\n");
        FileWriteString(m_file_handle, "# Start: " + TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS) + "\n");
        FileWriteString(m_file_handle, "# Format: time,time_msc,bid,ask,volume,flags\n");

        // Initiera session
        m_session.symbol = symbol;
        m_session.start_time = TimeCurrent();
        m_session.tick_count = 0;
        m_session.bar_count = 0;
        m_session.file_path = file_path;
        m_session.point = SymbolInfoDouble(symbol, SYMBOL_POINT);
        m_session.digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

        m_recording = true;
        Print("Recording started: ", file_path);

        return true;
    }

    //+------------------------------------------------------------------+
    //| StopRecording - Sluta spela in data                               |
    //+------------------------------------------------------------------+
    void StopRecording() {
        if (!m_recording) return;

        // Flusha kvarvarande data
        FlushTickBuffer();

        // Uppdatera session
        m_session.end_time = TimeCurrent();

        // Skriv footer
        FileWriteString(m_file_handle, "# End: " + TimeToString(m_session.end_time, TIME_DATE | TIME_SECONDS) + "\n");
        FileWriteString(m_file_handle, "# Ticks: " + IntegerToString(m_session.tick_count) + "\n");

        // Stäng fil
        FileClose(m_file_handle);
        m_file_handle = INVALID_HANDLE;
        m_recording = false;

        Print("Recording stopped. Ticks recorded: ", m_session.tick_count);
    }

    //+------------------------------------------------------------------+
    //| RecordTick - Spela in en tick                                     |
    //+------------------------------------------------------------------+
    void RecordTick(const MqlTick &tick) {
        if (!m_recording) return;

        // Lägg till i buffer
        if (m_buffer_index >= m_buffer_size) {
            FlushTickBuffer();
        }

        m_tick_buffer[m_buffer_index].time = tick.time;
        m_tick_buffer[m_buffer_index].time_msc = tick.time_msc;
        m_tick_buffer[m_buffer_index].bid = tick.bid;
        m_tick_buffer[m_buffer_index].ask = tick.ask;
        m_tick_buffer[m_buffer_index].volume = tick.volume;
        m_tick_buffer[m_buffer_index].flags = tick.flags;
        m_buffer_index++;

        m_session.tick_count++;
    }

    //+------------------------------------------------------------------+
    //| RecordTick - Spela in tick med individuella parametrar            |
    //+------------------------------------------------------------------+
    void RecordTick(double bid, double ask, datetime time, long time_msc = 0) {
        if (!m_recording) return;

        if (m_buffer_index >= m_buffer_size) {
            FlushTickBuffer();
        }

        m_tick_buffer[m_buffer_index].time = time;
        m_tick_buffer[m_buffer_index].time_msc = time_msc;
        m_tick_buffer[m_buffer_index].bid = bid;
        m_tick_buffer[m_buffer_index].ask = ask;
        m_tick_buffer[m_buffer_index].volume = 0;
        m_tick_buffer[m_buffer_index].flags = 0;
        m_buffer_index++;

        m_session.tick_count++;
    }

    //+------------------------------------------------------------------+
    //| RecordBar - Spela in en bar                                       |
    //+------------------------------------------------------------------+
    void RecordBar(ENUM_TIMEFRAMES tf, const MqlRates &bar) {
        if (!m_recording) return;

        // För enkelhet: skriv direkt till fil
        string line = StringFormat("BAR,%d,%d,%.5f,%.5f,%.5f,%.5f,%d",
                                   (int)tf,
                                   (long)bar.time,
                                   bar.open,
                                   bar.high,
                                   bar.low,
                                   bar.close,
                                   bar.tick_volume);
        FileWriteString(m_file_handle, line + "\n");
        m_session.bar_count++;
    }

    //+------------------------------------------------------------------+
    //| IsRecording - Är inspelning aktiv?                                |
    //+------------------------------------------------------------------+
    bool IsRecording() {
        return m_recording;
    }

    //+------------------------------------------------------------------+
    //| GetTickCount - Antal inspelade ticks                              |
    //+------------------------------------------------------------------+
    int GetTickCount() {
        return m_session.tick_count;
    }

    //+------------------------------------------------------------------+
    //| GetSessionInfo - Hämta sessionsinformation                        |
    //+------------------------------------------------------------------+
    RecordingSession GetSessionInfo() {
        return m_session;
    }

    //+------------------------------------------------------------------+
    //| Flush - Forcera skrivning till fil                                |
    //+------------------------------------------------------------------+
    void Flush() {
        FlushTickBuffer();
    }
};

//+------------------------------------------------------------------+
