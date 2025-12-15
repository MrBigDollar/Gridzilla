//+------------------------------------------------------------------+
//|                                             PositionManager.mqh   |
//|                                Copyright 2024, Gridzilla Project  |
//+------------------------------------------------------------------+
#property copyright "Gridzilla Project"
#property version   "1.00"
#property strict

#include "..\interfaces\IDataProvider.mqh"
#include "..\interfaces\IOrderExecutor.mqh"
#include "..\interfaces\ILogger.mqh"

//+------------------------------------------------------------------+
//| Konstanter                                                        |
//+------------------------------------------------------------------+
#define EQUITY_HISTORY_SIZE 20     // Antal bars att spara för velocity

//+------------------------------------------------------------------+
//| PositionDirection - Netto-riktning för positioner                 |
//+------------------------------------------------------------------+
enum PositionDirection {
    POSITION_DIRECTION_FLAT = 0,   // Inga positioner
    POSITION_DIRECTION_LONG = 1,   // Netto lång
    POSITION_DIRECTION_SHORT = -1  // Netto kort
};

//+------------------------------------------------------------------+
//| PositionManagerState - Aggregerat state för positioner            |
//+------------------------------------------------------------------+
struct PositionManagerState {
    //--- Grunddata
    int                 position_count;         // Antal öppna positioner
    double              total_lots;             // Total volym
    PositionDirection   direction;              // Netto-riktning

    //--- Prisberäkningar
    double              average_entry_price;    // Volymviktad snittpris
    double              breakeven_price;        // Pris för break-even (inkl spread)
    double              current_price;          // Aktuellt pris

    //--- Drawdown-metrik
    double              unrealized_pnl;         // Orealiserad vinst/förlust i valuta
    double              unrealized_pnl_pct;     // Orealiserad som % av balance
    double              current_drawdown_pct;   // Aktuell DD från peak equity
    double              max_adverse_excursion;  // Värsta DD under sessionens livstid
    double              dd_velocity;            // DD-förändring per bar (normaliserad)

    //--- Tidsdata
    datetime            oldest_position_time;   // Äldsta positionens öppningstid
    int                 position_age_hours;     // Timmar sedan äldsta position

    //--- Konstruktor
    PositionManagerState() {
        position_count = 0;
        total_lots = 0.0;
        direction = POSITION_DIRECTION_FLAT;
        average_entry_price = 0.0;
        breakeven_price = 0.0;
        current_price = 0.0;
        unrealized_pnl = 0.0;
        unrealized_pnl_pct = 0.0;
        current_drawdown_pct = 0.0;
        max_adverse_excursion = 0.0;
        dd_velocity = 0.0;
        oldest_position_time = 0;
        position_age_hours = 0;
    }
};

//+------------------------------------------------------------------+
//| CPositionManager - Spårar och analyserar öppna positioner         |
//|                                                                   |
//| Syfte: Tillhandahålla aggregerad positionsdata för beslutsfattande|
//| Beräknar: avg entry, breakeven, drawdown, MAE, velocity           |
//+------------------------------------------------------------------+
class CPositionManager {
private:
    //--- Beroenden
    IDataProvider*      m_data;
    IOrderExecutor*     m_executor;
    ILogger*            m_logger;

    //--- Konfiguration
    string              m_symbol;
    long                m_magic;
    bool                m_initialized;

    //--- Equity-historik för velocity-beräkning
    double              m_equity_history[];
    int                 m_history_index;
    int                 m_history_count;

    //--- Peak och MAE tracking
    double              m_peak_equity;
    double              m_session_mae;

    //=== PRIVATA BERÄKNINGSMETODER ===

    //+------------------------------------------------------------------+
    //| CalculateAverageEntryPrice - Volymviktad entry price             |
    //+------------------------------------------------------------------+
    double CalculateAverageEntryPrice() {
        if (m_executor == NULL) return 0.0;

        double total_value = 0.0;
        double total_lots = 0.0;

        int count = m_executor.GetPositionCount(m_symbol, m_magic);
        for (int i = 0; i < count; i++) {
            PositionInfo pos;
            if (m_executor.GetPositionByIndex(i, pos)) {
                if (pos.symbol == m_symbol && pos.magic == m_magic) {
                    total_value += pos.open_price * pos.lots;
                    total_lots += pos.lots;
                }
            }
        }

        if (total_lots <= 0) return 0.0;
        return total_value / total_lots;
    }

    //+------------------------------------------------------------------+
    //| GetNetDirection - Bestäm netto-riktning                          |
    //+------------------------------------------------------------------+
    PositionDirection GetNetDirection() {
        if (m_executor == NULL) return POSITION_DIRECTION_FLAT;

        double buy_lots = 0.0;
        double sell_lots = 0.0;

        int count = m_executor.GetPositionCount(m_symbol, m_magic);
        for (int i = 0; i < count; i++) {
            PositionInfo pos;
            if (m_executor.GetPositionByIndex(i, pos)) {
                if (pos.symbol == m_symbol && pos.magic == m_magic) {
                    if (pos.type == POSITION_TYPE_BUY) {
                        buy_lots += pos.lots;
                    } else if (pos.type == POSITION_TYPE_SELL) {
                        sell_lots += pos.lots;
                    }
                }
            }
        }

        if (buy_lots > sell_lots) return POSITION_DIRECTION_LONG;
        if (sell_lots > buy_lots) return POSITION_DIRECTION_SHORT;
        return POSITION_DIRECTION_FLAT;
    }

    //+------------------------------------------------------------------+
    //| CalculateBreakevenPrice - Pris för break-even inkl spread        |
    //+------------------------------------------------------------------+
    double CalculateBreakevenPrice() {
        if (m_executor == NULL || m_data == NULL) return 0.0;

        double avg_entry = CalculateAverageEntryPrice();
        if (avg_entry <= 0) return 0.0;

        double total_profit = m_executor.GetTotalProfit(m_symbol, m_magic);
        double total_lots = m_executor.GetTotalLots(m_symbol, m_magic);

        if (total_lots <= 0) return avg_entry;

        // Beräkna pris-offset baserat på aktuell P/L
        double tick_value = m_data.GetTickValue();
        double tick_size = m_data.GetTickSize();

        if (tick_value <= 0 || tick_size <= 0) return avg_entry;

        // Offset = profit / (lots * tick_value / tick_size)
        double price_offset = (total_profit / total_lots) / (tick_value / tick_size);

        // Lägg till spread för att kompensera stängningskostnad
        double spread = m_data.GetSpread();

        PositionDirection dir = GetNetDirection();
        if (dir == POSITION_DIRECTION_LONG) {
            // BUY: vi stänger genom att sälja, så BE är entry - profit_offset + spread
            return avg_entry - price_offset + spread;
        } else if (dir == POSITION_DIRECTION_SHORT) {
            // SELL: vi stänger genom att köpa, så BE är entry + profit_offset + spread
            return avg_entry + price_offset + spread;
        }

        return avg_entry;
    }

    //+------------------------------------------------------------------+
    //| CalculateCurrentDrawdown - Aktuell DD% från peak                 |
    //+------------------------------------------------------------------+
    double CalculateCurrentDrawdown() {
        if (m_data == NULL) return 0.0;

        double equity = m_data.GetAccountEquity();
        if (m_peak_equity <= 0) m_peak_equity = equity;

        // Uppdatera peak om vi når ny high
        if (equity > m_peak_equity) {
            m_peak_equity = equity;
        }

        if (m_peak_equity <= 0) return 0.0;

        return (m_peak_equity - equity) / m_peak_equity * 100.0;
    }

    //+------------------------------------------------------------------+
    //| UpdateMAE - Uppdatera max adverse excursion                      |
    //+------------------------------------------------------------------+
    void UpdateMAE() {
        double current_dd = CalculateCurrentDrawdown();
        if (current_dd > m_session_mae) {
            m_session_mae = current_dd;
        }
    }

    //+------------------------------------------------------------------+
    //| UpdateEquityHistory - Lägg till equity i historik                |
    //+------------------------------------------------------------------+
    void UpdateEquityHistory() {
        if (m_data == NULL) return;

        double equity = m_data.GetAccountEquity();

        // Cirkulär buffer
        m_equity_history[m_history_index] = equity;
        m_history_index = (m_history_index + 1) % EQUITY_HISTORY_SIZE;

        if (m_history_count < EQUITY_HISTORY_SIZE) {
            m_history_count++;
        }
    }

    //+------------------------------------------------------------------+
    //| CalculateDrawdownVelocity - Hur snabbt DD förändras              |
    //+------------------------------------------------------------------+
    double CalculateDrawdownVelocity() {
        if (m_history_count < 2) return 0.0;

        // Hämta senaste N bars
        int lookback = MathMin(5, m_history_count);

        // Beräkna index för oldest och newest
        int newest_idx = (m_history_index - 1 + EQUITY_HISTORY_SIZE) % EQUITY_HISTORY_SIZE;
        int oldest_idx = (m_history_index - lookback + EQUITY_HISTORY_SIZE) % EQUITY_HISTORY_SIZE;

        double newest = m_equity_history[newest_idx];
        double oldest = m_equity_history[oldest_idx];

        if (oldest <= 0) return 0.0;

        // Beräkna förändring i % per bar
        double change_pct = (newest - oldest) / oldest * 100.0;
        double velocity = change_pct / lookback;

        // Normalisera till [-1, 1] (dividera med 2 för att 2% per bar = 1.0)
        return MathMax(-1.0, MathMin(1.0, velocity / 2.0));
    }

    //+------------------------------------------------------------------+
    //| GetOldestPositionTime - Hitta äldsta positionens tid             |
    //+------------------------------------------------------------------+
    datetime GetOldestPositionTime() {
        if (m_executor == NULL) return 0;

        datetime oldest = 0;
        int count = m_executor.GetPositionCount(m_symbol, m_magic);

        for (int i = 0; i < count; i++) {
            PositionInfo pos;
            if (m_executor.GetPositionByIndex(i, pos)) {
                if (pos.symbol == m_symbol && pos.magic == m_magic) {
                    if (oldest == 0 || pos.open_time < oldest) {
                        oldest = pos.open_time;
                    }
                }
            }
        }

        return oldest;
    }

    //+------------------------------------------------------------------+
    //| CalculatePositionAgeHours - Timmar sedan äldsta position         |
    //+------------------------------------------------------------------+
    int CalculatePositionAgeHours(datetime oldest_time) {
        if (oldest_time == 0 || m_data == NULL) return 0;

        datetime current_time = m_data.GetServerTime();
        if (current_time <= oldest_time) return 0;

        // Beräkna skillnad i sekunder, konvertera till timmar
        long seconds = (long)(current_time - oldest_time);
        return (int)(seconds / 3600);
    }

public:
    //+------------------------------------------------------------------+
    //| Konstruktor                                                       |
    //+------------------------------------------------------------------+
    CPositionManager(IDataProvider* data, IOrderExecutor* executor, ILogger* logger) {
        m_data = data;
        m_executor = executor;
        m_logger = logger;

        m_symbol = "";
        m_magic = 0;
        m_initialized = false;

        // Initiera equity-historik
        ArrayResize(m_equity_history, EQUITY_HISTORY_SIZE);
        ArrayInitialize(m_equity_history, 0.0);
        m_history_index = 0;
        m_history_count = 0;

        // Initiera peak och MAE
        m_peak_equity = 0.0;
        m_session_mae = 0.0;
    }

    //+------------------------------------------------------------------+
    //| Destruktor                                                        |
    //+------------------------------------------------------------------+
    ~CPositionManager() {
        ArrayFree(m_equity_history);
    }

    //+------------------------------------------------------------------+
    //| Initialize - Initiera med symbol och magic                        |
    //+------------------------------------------------------------------+
    bool Initialize(string symbol, long magic) {
        if (m_data == NULL || m_executor == NULL) {
            if (m_logger != NULL) {
                m_logger.LogError("PositionManager", "Initialize failed: missing dependencies");
            }
            return false;
        }

        m_symbol = symbol;
        m_magic = magic;

        // Sätt initial peak equity
        m_peak_equity = m_data.GetAccountEquity();

        m_initialized = true;

        if (m_logger != NULL) {
            m_logger.LogInfo("PositionManager", "Initialized for " + symbol +
                            " magic=" + IntegerToString(magic));
        }

        return true;
    }

    //+------------------------------------------------------------------+
    //| IsInitialized - Kontrollera om modulen är initierad               |
    //+------------------------------------------------------------------+
    bool IsInitialized() {
        return m_initialized;
    }

    //+------------------------------------------------------------------+
    //| Update - Huvudmetod: uppdatera och returnera state                |
    //+------------------------------------------------------------------+
    PositionManagerState Update() {
        PositionManagerState state;

        if (!m_initialized) {
            return state;
        }

        // Uppdatera equity-historik
        UpdateEquityHistory();

        // Uppdatera MAE
        UpdateMAE();

        // Fyll i grunddata
        state.position_count = m_executor.GetPositionCount(m_symbol, m_magic);
        state.total_lots = m_executor.GetTotalLots(m_symbol, m_magic);
        state.direction = GetNetDirection();

        // Prisberäkningar
        state.average_entry_price = CalculateAverageEntryPrice();
        state.breakeven_price = CalculateBreakevenPrice();
        state.current_price = m_data.GetBid();

        // P/L data
        state.unrealized_pnl = m_executor.GetTotalProfit(m_symbol, m_magic);
        double balance = m_data.GetAccountBalance();
        state.unrealized_pnl_pct = (balance > 0) ? (state.unrealized_pnl / balance * 100.0) : 0.0;

        // Drawdown
        state.current_drawdown_pct = CalculateCurrentDrawdown();
        state.max_adverse_excursion = m_session_mae;
        state.dd_velocity = CalculateDrawdownVelocity();

        // Tidsdata
        state.oldest_position_time = GetOldestPositionTime();
        state.position_age_hours = CalculatePositionAgeHours(state.oldest_position_time);

        return state;
    }

    //+------------------------------------------------------------------+
    //| ResetSession - Nollställ för ny session                           |
    //+------------------------------------------------------------------+
    void ResetSession() {
        // Nollställ peak equity till nuvarande
        if (m_data != NULL) {
            m_peak_equity = m_data.GetAccountEquity();
        }

        // Nollställ MAE
        m_session_mae = 0.0;

        // Nollställ equity-historik
        ArrayInitialize(m_equity_history, 0.0);
        m_history_index = 0;
        m_history_count = 0;

        if (m_logger != NULL) {
            m_logger.LogInfo("PositionManager", "Session reset");
        }
    }

    //+------------------------------------------------------------------+
    //| SetPeakEquity - Sätt peak equity manuellt (för test)              |
    //+------------------------------------------------------------------+
    void SetPeakEquity(double peak) {
        m_peak_equity = peak;
    }

    //+------------------------------------------------------------------+
    //| GetPeakEquity - Hämta peak equity                                 |
    //+------------------------------------------------------------------+
    double GetPeakEquity() {
        return m_peak_equity;
    }

    //+------------------------------------------------------------------+
    //| AddEquityDataPoint - Lägg till equity datapunkt (för test)        |
    //+------------------------------------------------------------------+
    void AddEquityDataPoint(double equity) {
        m_equity_history[m_history_index] = equity;
        m_history_index = (m_history_index + 1) % EQUITY_HISTORY_SIZE;
        if (m_history_count < EQUITY_HISTORY_SIZE) {
            m_history_count++;
        }
    }

    //=== GETTERS FÖR TEST ===

    double GetAverageEntryPrice() { return CalculateAverageEntryPrice(); }
    double GetBreakevenPrice() { return CalculateBreakevenPrice(); }
    double GetCurrentDrawdownPct() { return CalculateCurrentDrawdown(); }
    double GetMAE() { return m_session_mae; }
    double GetDrawdownVelocity() { return CalculateDrawdownVelocity(); }
    PositionDirection GetDirection() { return GetNetDirection(); }
};

//+------------------------------------------------------------------+
