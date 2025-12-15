//+------------------------------------------------------------------+
//|                                         CMockOrderExecutor.mqh    |
//|                                Copyright 2024, Gridzilla Project  |
//+------------------------------------------------------------------+
#property copyright "Gridzilla Project"
#property version   "1.00"
#property strict

#include "..\interfaces\IOrderExecutor.mqh"

//+------------------------------------------------------------------+
//| OrderHistoryEntry - Historik över orderoperationer                |
//+------------------------------------------------------------------+
struct OrderHistoryEntry {
    datetime time;
    string   action;          // "OPEN", "CLOSE", "MODIFY", "DELETE"
    long     ticket;
    string   symbol;
    int      type;
    double   lots;
    double   price;
    double   sl;
    double   tp;
    bool     success;
    int      error_code;
};

//+------------------------------------------------------------------+
//| CMockOrderExecutor - Mock för orderexekvering                     |
//|                                                                   |
//| Syfte: Simulera orderexekvering utan riktiga tradingoperationer.  |
//| Används i enhetstester för att verifiera orderlogik.              |
//+------------------------------------------------------------------+
class CMockOrderExecutor : public IOrderExecutor {
private:
    //--- Simulerade positioner
    PositionInfo     m_positions[];
    int              m_position_count;
    int              m_max_positions;

    //--- Simulerade pending orders
    PendingOrderInfo m_pending_orders[];
    int              m_pending_count;

    //--- Nästa ticket-nummer
    long             m_next_ticket;

    //--- Konfiguration
    double           m_slippage;         // Simulerad slippage
    double           m_fill_rate;        // 1.0 = alltid fyller
    bool             m_trade_allowed;
    bool             m_expert_enabled;

    //--- Orderhistorik
    OrderHistoryEntry m_history[];
    int              m_history_count;
    int              m_max_history;

    //--- Aktuellt pris (för P/L-beräkning)
    double           m_current_bid;
    double           m_current_ask;

    //+------------------------------------------------------------------+
    //| AddToHistory - Lägg till i orderhistorik                          |
    //+------------------------------------------------------------------+
    void AddToHistory(string action, long ticket, string symbol, int type,
                      double lots, double price, double sl, double tp,
                      bool success, int error_code = 0) {
        if (m_history_count >= m_max_history) return;

        m_history[m_history_count].time = TimeCurrent();
        m_history[m_history_count].action = action;
        m_history[m_history_count].ticket = ticket;
        m_history[m_history_count].symbol = symbol;
        m_history[m_history_count].type = type;
        m_history[m_history_count].lots = lots;
        m_history[m_history_count].price = price;
        m_history[m_history_count].sl = sl;
        m_history[m_history_count].tp = tp;
        m_history[m_history_count].success = success;
        m_history[m_history_count].error_code = error_code;
        m_history_count++;
    }

    //+------------------------------------------------------------------+
    //| FindPositionIndex - Hitta position via ticket                     |
    //+------------------------------------------------------------------+
    int FindPositionIndex(long ticket) {
        for (int i = 0; i < m_position_count; i++) {
            if (m_positions[i].ticket == ticket) {
                return i;
            }
        }
        return -1;
    }

    //+------------------------------------------------------------------+
    //| RemovePosition - Ta bort position från listan                     |
    //+------------------------------------------------------------------+
    void RemovePosition(int index) {
        if (index < 0 || index >= m_position_count) return;

        // Flytta alla efterföljande positioner ett steg
        for (int i = index; i < m_position_count - 1; i++) {
            m_positions[i] = m_positions[i + 1];
        }
        m_position_count--;
    }

public:
    //+------------------------------------------------------------------+
    //| Konstruktor                                                       |
    //+------------------------------------------------------------------+
    CMockOrderExecutor() {
        m_max_positions = 100;
        m_position_count = 0;
        ArrayResize(m_positions, m_max_positions);

        m_pending_count = 0;
        ArrayResize(m_pending_orders, m_max_positions);

        m_next_ticket = 1000;

        m_slippage = 0.0;
        m_fill_rate = 1.0;
        m_trade_allowed = true;
        m_expert_enabled = true;

        m_max_history = 1000;
        m_history_count = 0;
        ArrayResize(m_history, m_max_history);

        m_current_bid = 1.08500;
        m_current_ask = 1.08520;
    }

    //+------------------------------------------------------------------+
    //| Destruktor                                                        |
    //+------------------------------------------------------------------+
    ~CMockOrderExecutor() {
        ArrayFree(m_positions);
        ArrayFree(m_pending_orders);
        ArrayFree(m_history);
    }

    //=== SETUP-METODER (för att konfigurera mock) ===

    //+------------------------------------------------------------------+
    //| SetSlippage - Sätt simulerad slippage                             |
    //+------------------------------------------------------------------+
    void SetSlippage(double slippage) {
        m_slippage = slippage;
    }

    //+------------------------------------------------------------------+
    //| SetFillRate - Sätt fyllnadsgrad (1.0 = alltid, 0.5 = 50%)          |
    //+------------------------------------------------------------------+
    void SetFillRate(double rate) {
        m_fill_rate = MathMax(0.0, MathMin(1.0, rate));
    }

    //+------------------------------------------------------------------+
    //| SetTradeAllowed - Sätt om handel är tillåten                       |
    //+------------------------------------------------------------------+
    void SetTradeAllowed(bool allowed) {
        m_trade_allowed = allowed;
    }

    //+------------------------------------------------------------------+
    //| SetExpertEnabled - Sätt om expert är aktiverad                     |
    //+------------------------------------------------------------------+
    void SetExpertEnabled(bool enabled) {
        m_expert_enabled = enabled;
    }

    //+------------------------------------------------------------------+
    //| SetCurrentPrices - Uppdatera aktuella priser (för P/L)             |
    //+------------------------------------------------------------------+
    void SetCurrentPrices(double bid, double ask) {
        m_current_bid = bid;
        m_current_ask = ask;
        UpdatePositionProfits();
    }

    //+------------------------------------------------------------------+
    //| UpdatePositionProfits - Uppdatera P/L för alla positioner          |
    //+------------------------------------------------------------------+
    void UpdatePositionProfits() {
        for (int i = 0; i < m_position_count; i++) {
            double current_price;
            if (m_positions[i].type == POSITION_TYPE_BUY) {
                current_price = m_current_bid;
                m_positions[i].profit = (current_price - m_positions[i].open_price) *
                                        m_positions[i].lots * 100000;  // Förenklad beräkning
            } else {
                current_price = m_current_ask;
                m_positions[i].profit = (m_positions[i].open_price - current_price) *
                                        m_positions[i].lots * 100000;
            }
            m_positions[i].current_price = current_price;
        }
    }

    //+------------------------------------------------------------------+
    //| ClearHistory - Rensa orderhistorik                                 |
    //+------------------------------------------------------------------+
    void ClearHistory() {
        m_history_count = 0;
    }

    //+------------------------------------------------------------------+
    //| ClearPositions - Rensa alla positioner                             |
    //+------------------------------------------------------------------+
    void ClearPositions() {
        m_position_count = 0;
    }

    //=== VERIFIERINGSMETODER (för tester) ===

    //+------------------------------------------------------------------+
    //| GetHistoryCount - Antal historikposter                             |
    //+------------------------------------------------------------------+
    int GetHistoryCount() {
        return m_history_count;
    }

    //+------------------------------------------------------------------+
    //| GetHistoryEntry - Hämta historikpost                               |
    //+------------------------------------------------------------------+
    bool GetHistoryEntry(int index, OrderHistoryEntry &entry) {
        if (index < 0 || index >= m_history_count) return false;
        entry = m_history[index];
        return true;
    }

    //+------------------------------------------------------------------+
    //| WasOrderPlaced - Kontrollera om order med ticket placerades        |
    //+------------------------------------------------------------------+
    bool WasOrderPlaced(long ticket) {
        for (int i = 0; i < m_history_count; i++) {
            if (m_history[i].ticket == ticket && m_history[i].action == "OPEN") {
                return true;
            }
        }
        return false;
    }

    //+------------------------------------------------------------------+
    //| WasPositionClosed - Kontrollera om position stängdes               |
    //+------------------------------------------------------------------+
    bool WasPositionClosed(long ticket) {
        for (int i = 0; i < m_history_count; i++) {
            if (m_history[i].ticket == ticket && m_history[i].action == "CLOSE") {
                return true;
            }
        }
        return false;
    }

    //+------------------------------------------------------------------+
    //| CountOrdersByType - Räkna ordrar av viss typ                       |
    //+------------------------------------------------------------------+
    int CountOrdersByType(int order_type) {
        int count = 0;
        for (int i = 0; i < m_position_count; i++) {
            if (m_positions[i].type == order_type) {
                count++;
            }
        }
        return count;
    }

    //=== IOrderExecutor IMPLEMENTATION ===

    virtual OrderResult SendMarketOrder(string symbol, int type, double lots,
                                        double sl, double tp, string comment,
                                        long magic) override {
        OrderResult result;

        // Kontrollera om handel är tillåten
        if (!m_trade_allowed || !m_expert_enabled) {
            result.success = false;
            result.error_code = 4756;  // Trade is disabled
            result.error_message = "Trade is not allowed";
            AddToHistory("OPEN", -1, symbol, type, lots, 0, sl, tp, false, 4756);
            return result;
        }

        // Simulera fyllnadsgrad
        if (MathRand() / 32768.0 > m_fill_rate) {
            result.success = false;
            result.error_code = 10006;  // No prices
            result.error_message = "Order not filled";
            AddToHistory("OPEN", -1, symbol, type, lots, 0, sl, tp, false, 10006);
            return result;
        }

        // Beräkna fyllnadspris med slippage
        double fill_price;
        if (type == ORDER_TYPE_BUY) {
            fill_price = m_current_ask + m_slippage;
        } else {
            fill_price = m_current_bid - m_slippage;
        }

        // Skapa position
        if (m_position_count >= m_max_positions) {
            result.success = false;
            result.error_code = 10019;  // Too many positions
            result.error_message = "Maximum positions reached";
            return result;
        }

        long ticket = m_next_ticket++;
        int idx = m_position_count;

        m_positions[idx].ticket = ticket;
        m_positions[idx].symbol = symbol;
        m_positions[idx].type = type;
        m_positions[idx].lots = lots;
        m_positions[idx].open_price = fill_price;
        m_positions[idx].current_price = fill_price;
        m_positions[idx].sl = sl;
        m_positions[idx].tp = tp;
        m_positions[idx].profit = 0;
        m_positions[idx].swap = 0;
        m_positions[idx].commission = 0;
        m_positions[idx].open_time = TimeCurrent();
        m_positions[idx].comment = comment;
        m_positions[idx].magic = magic;
        m_position_count++;

        result.success = true;
        result.ticket = ticket;
        result.fill_price = fill_price;
        result.fill_lots = lots;
        result.error_code = 0;
        result.error_message = "";

        AddToHistory("OPEN", ticket, symbol, type, lots, fill_price, sl, tp, true);

        return result;
    }

    virtual OrderResult SendPendingOrder(string symbol, int type, double lots,
                                         double price, double sl, double tp,
                                         string comment, long magic,
                                         datetime expiration = 0) override {
        OrderResult result;

        if (!m_trade_allowed) {
            result.success = false;
            result.error_code = 4756;
            return result;
        }

        long ticket = m_next_ticket++;

        if (m_pending_count < m_max_positions) {
            m_pending_orders[m_pending_count].ticket = ticket;
            m_pending_orders[m_pending_count].symbol = symbol;
            m_pending_orders[m_pending_count].type = type;
            m_pending_orders[m_pending_count].lots = lots;
            m_pending_orders[m_pending_count].price = price;
            m_pending_orders[m_pending_count].sl = sl;
            m_pending_orders[m_pending_count].tp = tp;
            m_pending_orders[m_pending_count].time_setup = TimeCurrent();
            m_pending_orders[m_pending_count].expiration = expiration;
            m_pending_orders[m_pending_count].comment = comment;
            m_pending_orders[m_pending_count].magic = magic;
            m_pending_count++;

            result.success = true;
            result.ticket = ticket;
        }

        return result;
    }

    virtual bool DeletePendingOrder(long ticket) override {
        for (int i = 0; i < m_pending_count; i++) {
            if (m_pending_orders[i].ticket == ticket) {
                // Ta bort
                for (int j = i; j < m_pending_count - 1; j++) {
                    m_pending_orders[j] = m_pending_orders[j + 1];
                }
                m_pending_count--;
                AddToHistory("DELETE", ticket, "", 0, 0, 0, 0, 0, true);
                return true;
            }
        }
        return false;
    }

    virtual bool ClosePosition(long ticket, double lots = 0) override {
        int idx = FindPositionIndex(ticket);
        if (idx < 0) return false;

        double close_lots = (lots == 0 || lots >= m_positions[idx].lots) ?
                            m_positions[idx].lots : lots;

        double close_price;
        if (m_positions[idx].type == POSITION_TYPE_BUY) {
            close_price = m_current_bid - m_slippage;
        } else {
            close_price = m_current_ask + m_slippage;
        }

        AddToHistory("CLOSE", ticket, m_positions[idx].symbol, m_positions[idx].type,
                     close_lots, close_price, 0, 0, true);

        if (lots == 0 || lots >= m_positions[idx].lots) {
            // Stäng hela positionen
            RemovePosition(idx);
        } else {
            // Delvis stängning
            m_positions[idx].lots -= lots;
        }

        return true;
    }

    virtual bool ModifyPosition(long ticket, double sl, double tp) override {
        int idx = FindPositionIndex(ticket);
        if (idx < 0) return false;

        m_positions[idx].sl = sl;
        m_positions[idx].tp = tp;

        AddToHistory("MODIFY", ticket, m_positions[idx].symbol, m_positions[idx].type,
                     m_positions[idx].lots, m_positions[idx].open_price, sl, tp, true);

        return true;
    }

    virtual bool CloseAllPositions(string symbol = "", long magic = 0) override {
        for (int i = m_position_count - 1; i >= 0; i--) {
            bool match = true;
            if (symbol != "" && m_positions[i].symbol != symbol) match = false;
            if (magic != 0 && m_positions[i].magic != magic) match = false;

            if (match) {
                ClosePosition(m_positions[i].ticket);
            }
        }
        return true;
    }

    virtual int GetPositionCount(string symbol = "", long magic = 0) override {
        if (symbol == "" && magic == 0) return m_position_count;

        int count = 0;
        for (int i = 0; i < m_position_count; i++) {
            bool match = true;
            if (symbol != "" && m_positions[i].symbol != symbol) match = false;
            if (magic != 0 && m_positions[i].magic != magic) match = false;
            if (match) count++;
        }
        return count;
    }

    virtual bool GetPositionByTicket(long ticket, PositionInfo &info) override {
        int idx = FindPositionIndex(ticket);
        if (idx < 0) return false;
        info = m_positions[idx];
        return true;
    }

    virtual bool GetPositionByIndex(int index, PositionInfo &info) override {
        if (index < 0 || index >= m_position_count) return false;
        info = m_positions[index];
        return true;
    }

    virtual bool GetPositionBySymbolMagic(string symbol, long magic,
                                          PositionInfo &info) override {
        for (int i = 0; i < m_position_count; i++) {
            if (m_positions[i].symbol == symbol && m_positions[i].magic == magic) {
                info = m_positions[i];
                return true;
            }
        }
        return false;
    }

    virtual double GetTotalLots(string symbol = "", long magic = 0) override {
        double total = 0;
        for (int i = 0; i < m_position_count; i++) {
            bool match = true;
            if (symbol != "" && m_positions[i].symbol != symbol) match = false;
            if (magic != 0 && m_positions[i].magic != magic) match = false;
            if (match) total += m_positions[i].lots;
        }
        return total;
    }

    virtual double GetTotalProfit(string symbol = "", long magic = 0) override {
        double total = 0;
        for (int i = 0; i < m_position_count; i++) {
            bool match = true;
            if (symbol != "" && m_positions[i].symbol != symbol) match = false;
            if (magic != 0 && m_positions[i].magic != magic) match = false;
            if (match) total += m_positions[i].profit;
        }
        return total;
    }

    virtual int GetPendingOrderCount(string symbol = "", long magic = 0) override {
        if (symbol == "" && magic == 0) return m_pending_count;

        int count = 0;
        for (int i = 0; i < m_pending_count; i++) {
            bool match = true;
            if (symbol != "" && m_pending_orders[i].symbol != symbol) match = false;
            if (magic != 0 && m_pending_orders[i].magic != magic) match = false;
            if (match) count++;
        }
        return count;
    }

    virtual bool GetPendingOrderByTicket(long ticket, PendingOrderInfo &info) override {
        for (int i = 0; i < m_pending_count; i++) {
            if (m_pending_orders[i].ticket == ticket) {
                info = m_pending_orders[i];
                return true;
            }
        }
        return false;
    }

    virtual bool GetPendingOrderByIndex(int index, PendingOrderInfo &info) override {
        if (index < 0 || index >= m_pending_count) return false;
        info = m_pending_orders[index];
        return true;
    }

    virtual bool IsTradeAllowed() override {
        return m_trade_allowed;
    }

    virtual bool IsExpertEnabled() override {
        return m_expert_enabled;
    }

    virtual double NormalizeLots(string symbol, double lots) override {
        // Enkel normalisering till 0.01 steg
        return MathFloor(lots * 100) / 100.0;
    }

    virtual double NormalizePrice(string symbol, double price) override {
        // Normalisera till 5 decimaler
        return NormalizeDouble(price, 5);
    }

    virtual bool ValidateStopLevel(string symbol, double price,
                                   double sl, double tp) override {
        // Enkel validering - minst 10 points avstånd
        double min_distance = 0.0010;
        if (sl != 0 && MathAbs(price - sl) < min_distance) return false;
        if (tp != 0 && MathAbs(price - tp) < min_distance) return false;
        return true;
    }
};

//+------------------------------------------------------------------+
