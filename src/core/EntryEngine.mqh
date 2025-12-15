//+------------------------------------------------------------------+
//|                                                  EntryEngine.mqh  |
//|                                Copyright 2024, Gridzilla Project  |
//+------------------------------------------------------------------+
#property copyright "Gridzilla Project"
#property version   "1.00"
#property strict

#include "..\interfaces\IDataProvider.mqh"
#include "..\interfaces\IOrderExecutor.mqh"
#include "..\interfaces\ILogger.mqh"
#include "..\utils\MathUtils.mqh"
#include "..\utils\TimeUtils.mqh"
#include "MarketStateManager.mqh"

//+------------------------------------------------------------------+
//| EntryFilters - Hard limits som ALDRIG kan kringgås                |
//+------------------------------------------------------------------+
struct EntryFilters {
    double max_spread_pips;        // Max spread för entry
    double min_volatility_atr;     // Min ATR (pips) för edge
    double max_volatility_atr;     // Max ATR (pips) för risk
    int    max_concurrent_entries; // Max samtidiga positioner
    bool   weekend_lockout;        // Blockera helg-trading

    //--- Konstruktor med standardvärden
    EntryFilters() {
        max_spread_pips = 2.0;
        min_volatility_atr = 5.0;
        max_volatility_atr = 50.0;
        max_concurrent_entries = 1;
        weekend_lockout = true;
    }
};

//+------------------------------------------------------------------+
//| EntryDecision - Resultat från entry-utvärdering                   |
//+------------------------------------------------------------------+
struct EntryDecision {
    bool   should_enter;       // Om entry ska ske
    int    direction;          // ORDER_TYPE_BUY eller ORDER_TYPE_SELL
    double entry_price;        // Föreslaget entry-pris (market)
    double stop_loss;          // SL-nivå
    double take_profit;        // TP-nivå
    double lot_size;           // Position size
    string reason;             // Anledning till beslutet
    string block_reason;       // Om blockerad - varför

    //--- Konstruktor med standardvärden
    EntryDecision() {
        should_enter = false;
        direction = -1;
        entry_price = 0.0;
        stop_loss = 0.0;
        take_profit = 0.0;
        lot_size = 0.0;
        reason = "";
        block_reason = "";
    }
};

//+------------------------------------------------------------------+
//| CEntryEngine - Entry-beslut baserat på TREND_PULLBACK              |
//|                                                                   |
//| Syfte: Utvärdera marknadsläge och ta entry-beslut.                |
//| Endast TREND_PULLBACK mode i FAS 2.                               |
//| INGEN grid-logik - endast single-entry trades.                    |
//+------------------------------------------------------------------+
class CEntryEngine {
private:
    IDataProvider*        m_data;
    IOrderExecutor*       m_executor;
    ILogger*              m_logger;
    CMarketStateManager*  m_state_manager;

    EntryFilters          m_filters;
    bool                  m_initialized;
    string                m_symbol;
    long                  m_magic;

    //--- Entry mode parameters
    double m_trend_strength_threshold;  // Min trend strength för entry
    double m_slope_threshold;           // Min slope magnitude
    double m_pullback_distance_min;     // Min ATR-distance för pullback
    double m_pullback_distance_max;     // Max ATR-distance för pullback
    double m_max_mean_reversion;        // Max MR score (ej överköpt)
    double m_risk_per_trade_pct;        // Risk % per trade
    double m_atr_sl_multiplier;         // ATR multiplikator för SL
    double m_rr_ratio;                  // Risk:Reward ratio för TP

    //--- Primär timeframe
    ENUM_TIMEFRAMES m_primary_tf;
    int m_atr_period;

    //+------------------------------------------------------------------+
    //| Filter checks                                                     |
    //+------------------------------------------------------------------+

    bool CheckSpreadFilter() {
        if (m_data == NULL) return false;
        double spread_pips = m_data.GetSpreadPips();
        return spread_pips <= m_filters.max_spread_pips;
    }

    bool CheckVolatilityFilter() {
        if (m_data == NULL) return false;
        double atr = m_data.GetATR(m_primary_tf, m_atr_period, 0);
        double point = m_data.GetPoint();
        if (point <= 0) return false;

        // Konvertera ATR till pips (5-digit broker)
        double atr_pips = atr / point / 10.0;

        return (atr_pips >= m_filters.min_volatility_atr &&
                atr_pips <= m_filters.max_volatility_atr);
    }

    bool CheckWeekendFilter() {
        if (!m_filters.weekend_lockout) return true;
        if (m_data == NULL) return false;
        datetime server_time = m_data.GetServerTime();
        return !CTimeUtils::IsWeekendLockout(server_time);
    }

    bool CheckMaxPositionsFilter() {
        if (m_executor == NULL) return false;
        int current = m_executor.GetPositionCount(m_symbol, m_magic);
        return current < m_filters.max_concurrent_entries;
    }

    bool PassesAllFilters(string &block_reason) {
        if (!CheckSpreadFilter()) {
            double spread = m_data.GetSpreadPips();
            block_reason = "Spread too high: " + DoubleToString(spread, 1) +
                          " pips (max " + DoubleToString(m_filters.max_spread_pips, 1) + ")";
            return false;
        }

        if (!CheckVolatilityFilter()) {
            double atr = m_data.GetATR(m_primary_tf, m_atr_period, 0);
            double atr_pips = atr / m_data.GetPoint() / 10.0;
            block_reason = "Volatility out of range: " + DoubleToString(atr_pips, 1) +
                          " pips (range " + DoubleToString(m_filters.min_volatility_atr, 0) +
                          "-" + DoubleToString(m_filters.max_volatility_atr, 0) + ")";
            return false;
        }

        if (!CheckWeekendFilter()) {
            block_reason = "Weekend lockout active";
            return false;
        }

        if (!CheckMaxPositionsFilter()) {
            int count = m_executor.GetPositionCount(m_symbol, m_magic);
            block_reason = "Max positions reached: " + IntegerToString(count) +
                          " (max " + IntegerToString(m_filters.max_concurrent_entries) + ")";
            return false;
        }

        return true;
    }

    //+------------------------------------------------------------------+
    //| TREND_PULLBACK Entry Logic                                        |
    //+------------------------------------------------------------------+

    bool CheckTrendPullbackEntry(MarketState &state, int &direction) {
        // Krav 1: Stark trend
        if (state.trend_strength < m_trend_strength_threshold) return false;

        // Krav 2: Tydlig riktning (slope magnitude)
        if (MathAbs(state.trend_slope) < m_slope_threshold) return false;

        // Bestäm riktning
        bool is_bullish = state.trend_slope > 0;
        direction = is_bullish ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;

        // Krav 3: Pullback - pris nära EMA20
        double price = is_bullish ? m_data.GetAsk() : m_data.GetBid();
        double ema20 = m_data.GetEMA(m_primary_tf, 20, PRICE_CLOSE, 0);
        double atr = m_data.GetATR(m_primary_tf, m_atr_period, 0);

        if (atr <= 0 || ema20 <= 0) return false;

        // Beräkna avstånd till EMA20 i ATR-enheter
        double distance_to_ema = (price - ema20) / atr;

        if (is_bullish) {
            // Bullish: pris ska vara nära eller strax under EMA20
            // Dvs distance_to_ema bör vara inom [-pullback_max, pullback_min]
            if (distance_to_ema > m_pullback_distance_min ||
                distance_to_ema < -m_pullback_distance_max) return false;
        } else {
            // Bearish: pris ska vara nära eller strax över EMA20
            // Dvs distance_to_ema bör vara inom [-pullback_min, pullback_max]
            if (distance_to_ema < -m_pullback_distance_min ||
                distance_to_ema > m_pullback_distance_max) return false;
        }

        // Krav 4: Inte överköpt/såld (mean reversion ej för hög)
        if (state.mean_reversion_score > m_max_mean_reversion) return false;

        return true;
    }

    //+------------------------------------------------------------------+
    //| Position Sizing & SL/TP                                           |
    //+------------------------------------------------------------------+

    double CalculateStopLoss(int direction, double entry_price) {
        double atr = m_data.GetATR(m_primary_tf, m_atr_period, 0);
        double sl_distance = atr * m_atr_sl_multiplier;

        double sl = 0.0;
        if (direction == ORDER_TYPE_BUY) {
            sl = entry_price - sl_distance;
        } else {
            sl = entry_price + sl_distance;
        }

        return m_executor.NormalizePrice(m_symbol, sl);
    }

    double CalculateTakeProfit(int direction, double entry_price, double sl) {
        double sl_distance = MathAbs(entry_price - sl);
        double tp_distance = sl_distance * m_rr_ratio;

        double tp = 0.0;
        if (direction == ORDER_TYPE_BUY) {
            tp = entry_price + tp_distance;
        } else {
            tp = entry_price - tp_distance;
        }

        return m_executor.NormalizePrice(m_symbol, tp);
    }

    double CalculateLotSize(double entry_price, double sl) {
        double account_balance = m_data.GetAccountBalance();
        double risk_amount = account_balance * (m_risk_per_trade_pct / 100.0);

        double sl_distance = MathAbs(entry_price - sl);
        if (sl_distance <= 0) return 0.0;

        double tick_value = m_data.GetTickValue();
        double tick_size = m_data.GetTickSize();

        if (tick_value <= 0 || tick_size <= 0) return 0.0;

        // Lotsize = Risk / (SL_distance * tick_value / tick_size)
        double lot_size = risk_amount / (sl_distance / tick_size * tick_value);

        return m_executor.NormalizeLots(m_symbol, lot_size);
    }

public:
    //+------------------------------------------------------------------+
    //| Konstruktor                                                       |
    //+------------------------------------------------------------------+
    CEntryEngine(IDataProvider* data, IOrderExecutor* executor,
                 ILogger* logger, CMarketStateManager* state_mgr) {
        m_data = data;
        m_executor = executor;
        m_logger = logger;
        m_state_manager = state_mgr;
        m_initialized = false;
        m_symbol = "";
        m_magic = 0;

        // Default parameters för TREND_PULLBACK
        m_trend_strength_threshold = 0.6;
        m_slope_threshold = 0.2;
        m_pullback_distance_min = 0.5;   // Max 0.5 ATR på "rätt" sida av EMA
        m_pullback_distance_max = 1.0;   // Max 1.0 ATR på "fel" sida av EMA
        m_max_mean_reversion = 0.7;
        m_risk_per_trade_pct = 2.0;
        m_atr_sl_multiplier = 2.0;
        m_rr_ratio = 1.0;

        m_primary_tf = PERIOD_H1;
        m_atr_period = 14;
    }

    //+------------------------------------------------------------------+
    //| Destruktor                                                        |
    //+------------------------------------------------------------------+
    ~CEntryEngine() {
        // Ingen dynamisk allokering att frigöra
    }

    //+------------------------------------------------------------------+
    //| Initialize - Initiera entry engine                                |
    //+------------------------------------------------------------------+
    bool Initialize(string symbol, long magic) {
        if (m_data == NULL || m_executor == NULL || m_state_manager == NULL) {
            if (m_logger != NULL) {
                m_logger.LogError("EntryEngine", "Missing dependencies (data/executor/state_manager)");
            }
            return false;
        }

        m_symbol = symbol;
        m_magic = magic;
        m_initialized = true;

        if (m_logger != NULL) {
            m_logger.LogInfo("EntryEngine", "Initialized for " + symbol +
                           " with magic " + IntegerToString(magic));
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
    //| Evaluate - Utvärdera om entry ska ske                             |
    //+------------------------------------------------------------------+
    EntryDecision Evaluate() {
        EntryDecision decision;

        if (!m_initialized) {
            decision.block_reason = "EntryEngine not initialized";
            return decision;
        }

        // Steg 1: Kontrollera alla filter
        string block_reason = "";
        if (!PassesAllFilters(block_reason)) {
            decision.block_reason = block_reason;

            if (m_logger != NULL) {
                m_logger.LogDebug("EntryEngine", "Entry blocked: " + block_reason);
            }

            return decision;
        }

        // Steg 2: Hämta MarketState
        MarketState state = m_state_manager.GetMarketState();

        // Steg 3: Kontrollera TREND_PULLBACK entry
        int direction = -1;
        if (!CheckTrendPullbackEntry(state, direction)) {
            decision.reason = "No TREND_PULLBACK signal";
            return decision;
        }

        // Steg 4: Beräkna entry, SL, TP, lot size
        double entry_price = (direction == ORDER_TYPE_BUY) ?
                             m_data.GetAsk() : m_data.GetBid();
        entry_price = m_executor.NormalizePrice(m_symbol, entry_price);

        double sl = CalculateStopLoss(direction, entry_price);
        double tp = CalculateTakeProfit(direction, entry_price, sl);
        double lots = CalculateLotSize(entry_price, sl);

        // Validera lot size
        if (lots <= 0) {
            decision.block_reason = "Invalid lot size calculation";
            return decision;
        }

        // Validera SL/TP levels
        if (!m_executor.ValidateStopLevel(m_symbol, entry_price, sl, tp)) {
            decision.block_reason = "SL/TP too close to price";
            return decision;
        }

        // Fyll i decision
        decision.should_enter = true;
        decision.direction = direction;
        decision.entry_price = entry_price;
        decision.stop_loss = sl;
        decision.take_profit = tp;
        decision.lot_size = lots;
        decision.reason = "TREND_PULLBACK: " +
                         (direction == ORDER_TYPE_BUY ? "BUY" : "SELL") +
                         " signal, trend_strength=" + DoubleToString(state.trend_strength, 2) +
                         ", slope=" + DoubleToString(state.trend_slope, 2);

        if (m_logger != NULL) {
            string inputs = "{\"trend_strength\":" + DoubleToString(state.trend_strength, 3) +
                           ",\"trend_slope\":" + DoubleToString(state.trend_slope, 3) +
                           ",\"mean_reversion\":" + DoubleToString(state.mean_reversion_score, 3) + "}";
            string outputs = "{\"direction\":\"" + (direction == ORDER_TYPE_BUY ? "BUY" : "SELL") +
                            "\",\"entry\":" + DoubleToString(entry_price, 5) +
                            ",\"sl\":" + DoubleToString(sl, 5) +
                            ",\"tp\":" + DoubleToString(tp, 5) +
                            ",\"lots\":" + DoubleToString(lots, 2) + "}";

            m_logger.LogDecision("EntryEngine", "TREND_PULLBACK_SIGNAL",
                                inputs, outputs, state.trend_strength);
        }

        return decision;
    }

    //+------------------------------------------------------------------+
    //| Execute - Exekvera entry-beslut                                   |
    //+------------------------------------------------------------------+
    OrderResult Execute(EntryDecision &decision) {
        OrderResult result;

        if (!decision.should_enter) {
            result.error_message = "No entry decision";
            return result;
        }

        if (!m_executor.IsTradeAllowed()) {
            result.error_message = "Trading not allowed";
            if (m_logger != NULL) {
                m_logger.LogWarning("EntryEngine", "Trade not allowed");
            }
            return result;
        }

        // Skicka marknadsorder
        string comment = "Gridzilla_Entry";
        result = m_executor.SendMarketOrder(m_symbol,
                                           decision.direction,
                                           decision.lot_size,
                                           decision.stop_loss,
                                           decision.take_profit,
                                           comment,
                                           m_magic);

        if (result.success && m_logger != NULL) {
            m_logger.LogTrade("OPEN",
                             result.ticket,
                             m_symbol,
                             decision.lot_size,
                             result.fill_price,
                             decision.stop_loss,
                             decision.take_profit);
        } else if (!result.success && m_logger != NULL) {
            m_logger.LogError("EntryEngine",
                             "Order failed: " + result.error_message,
                             result.error_code);
        }

        return result;
    }

    //+------------------------------------------------------------------+
    //| Setters för konfiguration                                         |
    //+------------------------------------------------------------------+

    void SetFilters(EntryFilters &filters) {
        m_filters = filters;
    }

    void SetRiskPerTrade(double pct) {
        m_risk_per_trade_pct = CMathUtils::Clamp(pct, 0.1, 10.0);
    }

    void SetRRRatio(double ratio) {
        m_rr_ratio = CMathUtils::Clamp(ratio, 0.5, 5.0);
    }

    void SetATRMultiplier(double multiplier) {
        m_atr_sl_multiplier = CMathUtils::Clamp(multiplier, 1.0, 5.0);
    }

    void SetTrendStrengthThreshold(double threshold) {
        m_trend_strength_threshold = CMathUtils::Clamp(threshold, 0.3, 0.9);
    }

    //+------------------------------------------------------------------+
    //| Getters för testning                                              |
    //+------------------------------------------------------------------+

    bool CheckSpreadFilterPublic() { return CheckSpreadFilter(); }
    bool CheckVolatilityFilterPublic() { return CheckVolatilityFilter(); }
    bool CheckWeekendFilterPublic() { return CheckWeekendFilter(); }
    bool CheckMaxPositionsFilterPublic() { return CheckMaxPositionsFilter(); }

    double GetRiskPerTrade() { return m_risk_per_trade_pct; }
    double GetRRRatio() { return m_rr_ratio; }
    double GetATRMultiplier() { return m_atr_sl_multiplier; }
};

//+------------------------------------------------------------------+
