//+------------------------------------------------------------------+
//|                                          MarketStateManager.mqh   |
//|                                Copyright 2024, Gridzilla Project  |
//+------------------------------------------------------------------+
#property copyright "Gridzilla Project"
#property version   "1.00"
#property strict

#include "..\interfaces\IDataProvider.mqh"
#include "..\utils\MathUtils.mqh"
#include "..\utils\TimeUtils.mqh"

//+------------------------------------------------------------------+
//| MarketState - Aggregerat marknadsstate                            |
//|                                                                   |
//| Alla features normaliserade till ONNX-kompatibla intervall.       |
//+------------------------------------------------------------------+
struct MarketState {
    double trend_strength;       // 0.0 - 1.0
    double trend_slope;          // -1.0 - 1.0
    double trend_curvature;      // -1.0 - 1.0
    double volatility_level;     // 0.0 - 1.0
    double volatility_change;    // -1.0 - 1.0
    double mean_reversion_score; // 0.0 - 1.0
    double spread_zscore;        // -3.0 - 3.0
    int    session_id;           // 0-4

    MarketState() {
        trend_strength = 0.0;
        trend_slope = 0.0;
        trend_curvature = 0.0;
        volatility_level = 0.0;
        volatility_change = 0.0;
        mean_reversion_score = 0.0;
        spread_zscore = 0.0;
        session_id = 0;
    }
};

//+------------------------------------------------------------------+
//| CMarketStateManager - Analyserar och aggregerar marknadsdata      |
//|                                                                   |
//| Syfte: Samla all marknadsinformation som behövs för beslut.       |
//| Denna modul är "ögonen" för systemet.                             |
//|                                                                   |
//| REGEL: Endast läsa data och returnera state. INGA tradingbeslut.  |
//+------------------------------------------------------------------+
class CMarketStateManager {
private:
    IDataProvider*   m_data;
    bool             m_initialized;

    //--- Ringbuffers för historik
    double           m_spread_history[];
    double           m_atr_history[];
    int              m_history_size;
    int              m_history_index;

    //--- Konfiguration
    ENUM_TIMEFRAMES  m_primary_tf;
    int              m_trend_period;
    int              m_atr_period;
    int              m_rsi_period;
    int              m_bb_period;
    double           m_bb_deviation;

    //+------------------------------------------------------------------+
    //| UpdateHistoryBuffers - Uppdatera ringbuffers med nya värden       |
    //+------------------------------------------------------------------+
    void UpdateHistoryBuffers() {
        if (m_data == NULL) return;

        // Uppdatera spread-historik
        double current_spread = m_data.GetSpreadPips();
        m_spread_history[m_history_index] = current_spread;

        // Uppdatera ATR-historik
        double current_atr = m_data.GetATR(m_primary_tf, m_atr_period, 0);
        m_atr_history[m_history_index] = current_atr;

        // Flytta index (cirkulär buffer)
        m_history_index = (m_history_index + 1) % m_history_size;
    }

    //+------------------------------------------------------------------+
    //| GetValidHistoryCount - Antal giltiga historiska värden            |
    //+------------------------------------------------------------------+
    int GetValidHistoryCount() {
        int count = 0;
        for (int i = 0; i < m_history_size; i++) {
            if (m_spread_history[i] > 0) count++;
        }
        return count;
    }

    //+------------------------------------------------------------------+
    //| CalculateTrendStrength - EMA alignment + ADX + price distance     |
    //|                                                                   |
    //| Returnerar: 0.0 (ingen trend) - 1.0 (stark trend)                 |
    //+------------------------------------------------------------------+
    double CalculateTrendStrength() {
        if (m_data == NULL) return 0.0;

        // Komponent 1: EMA alignment (40%)
        double ema20 = m_data.GetEMA(m_primary_tf, 20, PRICE_CLOSE, 0);
        double ema50 = m_data.GetEMA(m_primary_tf, 50, PRICE_CLOSE, 0);
        double ema200 = m_data.GetEMA(m_primary_tf, 200, PRICE_CLOSE, 0);

        double ema_alignment = 0.0;
        // Bullish alignment: EMA20 > EMA50 > EMA200
        if (ema20 > ema50 && ema50 > ema200) ema_alignment = 1.0;
        // Bearish alignment: EMA20 < EMA50 < EMA200
        else if (ema20 < ema50 && ema50 < ema200) ema_alignment = 1.0;
        // Partial alignment
        else if ((ema20 > ema50 && ema50 < ema200) ||
                 (ema20 < ema50 && ema50 > ema200)) ema_alignment = 0.5;

        // Komponent 2: ADX styrka (40%)
        double adx = m_data.GetADX(m_primary_tf, 14, 0);
        double adx_normalized = MathMin(adx / 50.0, 1.0);

        // Komponent 3: Price distance from EMA200 (20%)
        double price = m_data.GetBid();
        double distance_pct = 0.0;
        if (ema200 > 0) {
            distance_pct = MathAbs(price - ema200) / ema200 * 100;
        }
        double distance_score = MathMin(distance_pct / 2.0, 1.0);

        // Viktat genomsnitt
        double strength = ema_alignment * 0.4 + adx_normalized * 0.4 + distance_score * 0.2;
        return CMathUtils::Clamp(strength, 0.0, 1.0);
    }

    //+------------------------------------------------------------------+
    //| CalculateTrendSlope - Linjär regression på close-priser           |
    //|                                                                   |
    //| Returnerar: -1.0 (stark nedtrend) - 1.0 (stark upptrend)          |
    //+------------------------------------------------------------------+
    double CalculateTrendSlope() {
        if (m_data == NULL) return 0.0;

        // Hämta senaste closes
        double closes[];
        ArrayResize(closes, m_trend_period);

        for (int i = 0; i < m_trend_period; i++) {
            closes[i] = m_data.GetClose(m_primary_tf, m_trend_period - 1 - i);
        }

        // Linjär regression
        LinearRegressionResult lr = CMathUtils::LinearRegression(closes, m_trend_period);

        // Normalisera slope baserat på ATR
        double atr = m_data.GetATR(m_primary_tf, m_atr_period, 0);
        if (atr <= 0) return 0.0;

        double slope_normalized = lr.slope / atr;
        return CMathUtils::Clamp(slope_normalized, -1.0, 1.0);
    }

    //+------------------------------------------------------------------+
    //| CalculateSlopeForPeriod - Hjälpfunktion för curvature              |
    //+------------------------------------------------------------------+
    double CalculateSlopeForPeriod(int start_shift, int end_shift) {
        if (m_data == NULL) return 0.0;

        int period = end_shift - start_shift;
        if (period <= 1) return 0.0;

        double closes[];
        ArrayResize(closes, period);

        for (int i = 0; i < period; i++) {
            closes[i] = m_data.GetClose(m_primary_tf, end_shift - 1 - i);
        }

        LinearRegressionResult lr = CMathUtils::LinearRegression(closes, period);
        return lr.slope;
    }

    //+------------------------------------------------------------------+
    //| CalculateTrendCurvature - Förändring av slope                     |
    //|                                                                   |
    //| Returnerar: -1.0 (bromsande) - 1.0 (accelererande)                |
    //+------------------------------------------------------------------+
    double CalculateTrendCurvature() {
        if (m_data == NULL) return 0.0;

        int half_period = m_trend_period / 2;

        // Slope för senaste halvan
        double slope_recent = CalculateSlopeForPeriod(0, half_period);

        // Slope för äldre halvan
        double slope_older = CalculateSlopeForPeriod(half_period, m_trend_period);

        // Normalisera med ATR
        double atr = m_data.GetATR(m_primary_tf, m_atr_period, 0);
        if (atr <= 0) return 0.0;

        double curvature = (slope_recent - slope_older) / atr;
        return CMathUtils::Clamp(curvature * 5.0, -1.0, 1.0);
    }

    //+------------------------------------------------------------------+
    //| CalculateVolatilityLevel - ATR normaliserad mot historik          |
    //|                                                                   |
    //| Returnerar: 0.0 (låg volatilitet) - 1.0 (hög volatilitet)         |
    //+------------------------------------------------------------------+
    double CalculateVolatilityLevel() {
        if (m_data == NULL) return 0.0;

        double current_atr = m_data.GetATR(m_primary_tf, m_atr_period, 0);

        int valid_count = GetValidHistoryCount();
        if (valid_count < 10) {
            // Inte tillräckligt med historik - returnera 0.5
            return 0.5;
        }

        // Hitta min/max ATR från historik
        double atr_min = m_atr_history[0];
        double atr_max = m_atr_history[0];

        for (int i = 1; i < m_history_size; i++) {
            if (m_atr_history[i] > 0) {
                if (m_atr_history[i] < atr_min) atr_min = m_atr_history[i];
                if (m_atr_history[i] > atr_max) atr_max = m_atr_history[i];
            }
        }

        // Undvik division med 0
        if (atr_max - atr_min < 0.00001) return 0.5;

        double level = CMathUtils::NormalizeToRange(current_atr, atr_min, atr_max, 0.0, 1.0);
        return CMathUtils::Clamp(level, 0.0, 1.0);
    }

    //+------------------------------------------------------------------+
    //| CalculateVolatilityChange - ATR-förändring vs tidigare            |
    //|                                                                   |
    //| Returnerar: -1.0 (minskande) - 1.0 (ökande)                        |
    //+------------------------------------------------------------------+
    double CalculateVolatilityChange() {
        if (m_data == NULL) return 0.0;

        double current_atr = m_data.GetATR(m_primary_tf, m_atr_period, 0);
        double prev_atr = m_data.GetATR(m_primary_tf, m_atr_period, 10);

        if (prev_atr <= 0) return 0.0;

        double change_pct = (current_atr - prev_atr) / prev_atr;
        return CMathUtils::Clamp(change_pct, -1.0, 1.0);
    }

    //+------------------------------------------------------------------+
    //| CalculateMeanReversionScore - BB position + RSI                   |
    //|                                                                   |
    //| Returnerar: 0.0 (neutral) - 1.0 (extrem - mean reversion likely)  |
    //+------------------------------------------------------------------+
    double CalculateMeanReversionScore() {
        if (m_data == NULL) return 0.0;

        double price = m_data.GetBid();
        double bb_upper = m_data.GetBBUpper(m_primary_tf, m_bb_period, m_bb_deviation, 0);
        double bb_lower = m_data.GetBBLower(m_primary_tf, m_bb_period, m_bb_deviation, 0);

        // Undvik division med 0
        double bb_range = bb_upper - bb_lower;
        if (bb_range < 0.00001) return 0.0;

        // BB position: 0 = vid lower, 0.5 = vid middle, 1 = vid upper
        double bb_position = (price - bb_lower) / bb_range;
        bb_position = CMathUtils::Clamp(bb_position, 0.0, 1.0);

        // RSI deviation from 50
        double rsi = m_data.GetRSI(m_primary_tf, m_rsi_period, PRICE_CLOSE, 0);
        double rsi_deviation = MathAbs(rsi - 50.0) / 50.0;
        rsi_deviation = CMathUtils::Clamp(rsi_deviation, 0.0, 1.0);

        // Mean reversion score: hög vid extremer
        double bb_extreme_score = MathAbs(bb_position - 0.5) * 2.0;

        // Kombinera: båda måste vara extrema för hög score
        double score = (bb_extreme_score + rsi_deviation) / 2.0;
        return CMathUtils::Clamp(score, 0.0, 1.0);
    }

    //+------------------------------------------------------------------+
    //| CalculateSpreadZScore - Z-score av spread vs historik             |
    //|                                                                   |
    //| Returnerar: -3.0 - 3.0 (clampad)                                  |
    //+------------------------------------------------------------------+
    double CalculateSpreadZScore() {
        if (m_data == NULL) return 0.0;

        double current_spread = m_data.GetSpreadPips();

        int valid_count = GetValidHistoryCount();
        if (valid_count < 10) {
            // Inte tillräckligt med historik
            return 0.0;
        }

        // Beräkna mean och stddev från historik
        double mean_spread = CMathUtils::Mean(m_spread_history, m_history_size);
        double std_spread = CMathUtils::StdDev(m_spread_history, m_history_size);

        if (std_spread < 0.0001) return 0.0;

        double zscore = CMathUtils::ZScore(current_spread, mean_spread, std_spread);
        return CMathUtils::Clamp(zscore, -3.0, 3.0);
    }

public:
    //+------------------------------------------------------------------+
    //| Konstruktor                                                       |
    //+------------------------------------------------------------------+
    CMarketStateManager(IDataProvider* data_provider) {
        m_data = data_provider;
        m_initialized = false;
        m_history_size = 100;
        m_history_index = 0;

        // Standardkonfiguration
        m_primary_tf = PERIOD_H1;
        m_trend_period = 20;
        m_atr_period = 14;
        m_rsi_period = 14;
        m_bb_period = 20;
        m_bb_deviation = 2.0;
    }

    //+------------------------------------------------------------------+
    //| Destruktor                                                        |
    //+------------------------------------------------------------------+
    ~CMarketStateManager() {
        ArrayFree(m_spread_history);
        ArrayFree(m_atr_history);
    }

    //+------------------------------------------------------------------+
    //| Initialize - Initiera med historikstorlek                         |
    //+------------------------------------------------------------------+
    bool Initialize(int history_bars = 100) {
        if (m_data == NULL) return false;

        m_history_size = history_bars;
        m_history_index = 0;

        ArrayResize(m_spread_history, m_history_size);
        ArrayResize(m_atr_history, m_history_size);

        // Initiera med 0
        ArrayInitialize(m_spread_history, 0.0);
        ArrayInitialize(m_atr_history, 0.0);

        // Fyll historik med befintliga data
        for (int i = m_history_size - 1; i >= 0; i--) {
            // Spread-historik (ungefärlig, baserat på nuvarande)
            m_spread_history[i] = m_data.GetSpreadPips();

            // ATR-historik
            m_atr_history[i] = m_data.GetATR(m_primary_tf, m_atr_period, i);
        }

        m_initialized = true;
        return true;
    }

    //+------------------------------------------------------------------+
    //| SetTimeframe - Ändra primär timeframe                              |
    //+------------------------------------------------------------------+
    void SetTimeframe(ENUM_TIMEFRAMES tf) {
        m_primary_tf = tf;
    }

    //+------------------------------------------------------------------+
    //| SetParameters - Konfigurera beräkningsparametrar                  |
    //+------------------------------------------------------------------+
    void SetParameters(int trend_period, int atr_period, int rsi_period,
                       int bb_period, double bb_deviation) {
        m_trend_period = trend_period;
        m_atr_period = atr_period;
        m_rsi_period = rsi_period;
        m_bb_period = bb_period;
        m_bb_deviation = bb_deviation;
    }

    //+------------------------------------------------------------------+
    //| Update - Uppdatera historikbuffers (kalla varje tick/bar)         |
    //+------------------------------------------------------------------+
    void Update() {
        if (!m_initialized) return;
        UpdateHistoryBuffers();
    }

    //+------------------------------------------------------------------+
    //| GetMarketState - Hämta aktuellt marknadsstate                      |
    //|                                                                   |
    //| Returnerar aggregerat state med alla features.                    |
    //+------------------------------------------------------------------+
    MarketState GetMarketState() {
        MarketState state;

        if (!m_initialized || m_data == NULL) {
            return state;
        }

        // Beräkna alla features
        state.trend_strength = CalculateTrendStrength();
        state.trend_slope = CalculateTrendSlope();
        state.trend_curvature = CalculateTrendCurvature();
        state.volatility_level = CalculateVolatilityLevel();
        state.volatility_change = CalculateVolatilityChange();
        state.mean_reversion_score = CalculateMeanReversionScore();
        state.spread_zscore = CalculateSpreadZScore();

        // Session ID direkt från TimeUtils
        datetime server_time = m_data.GetServerTime();
        state.session_id = (int)CTimeUtils::GetCurrentSession(server_time);

        return state;
    }

    //+------------------------------------------------------------------+
    //| IsInitialized - Kontrollera om manager är initierad               |
    //+------------------------------------------------------------------+
    bool IsInitialized() {
        return m_initialized;
    }

    //+------------------------------------------------------------------+
    //| GetHistorySize - Hämta historikstorlek                            |
    //+------------------------------------------------------------------+
    int GetHistorySize() {
        return m_history_size;
    }
};

//+------------------------------------------------------------------+
