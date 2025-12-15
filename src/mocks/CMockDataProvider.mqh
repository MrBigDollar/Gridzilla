//+------------------------------------------------------------------+
//|                                          CMockDataProvider.mqh    |
//|                                Copyright 2024, Gridzilla Project  |
//+------------------------------------------------------------------+
#property copyright "Gridzilla Project"
#property version   "1.00"
#property strict

#include "..\interfaces\IDataProvider.mqh"

//+------------------------------------------------------------------+
//| CMockDataProvider - Mock för marknadsdataåtkomst                  |
//|                                                                   |
//| Syfte: Tillhandahålla deterministisk marknaddata för testning.    |
//| Alla värden kan konfigureras för att simulera olika scenarier.    |
//+------------------------------------------------------------------+
class CMockDataProvider : public IDataProvider {
private:
    //--- Prisdata
    double           m_bid;
    double           m_ask;
    double           m_spread;
    double           m_point;
    int              m_digits;
    string           m_symbol;

    //--- Bar-data (cirkulär buffer)
    BarData          m_bars[];
    int              m_bar_count;
    int              m_max_bars;

    //--- Indikatorvärden (förberäknade)
    double           m_atr_values[];
    double           m_ema_values[];
    double           m_rsi_values[];
    double           m_adx_values[];
    double           m_bb_upper[];
    double           m_bb_lower[];
    double           m_bb_middle[];
    int              m_indicator_count;

    //--- Kontoinformation
    double           m_balance;
    double           m_equity;
    double           m_free_margin;
    string           m_account_currency;
    long             m_leverage;

    //--- Symbolinformation
    double           m_min_lot;
    double           m_max_lot;
    double           m_lot_step;
    double           m_tick_value;
    double           m_tick_size;
    double           m_contract_size;

    //--- Tid
    datetime         m_server_time;
    datetime         m_local_time;
    int              m_gmt_offset;

    //--- Tick-simulering
    bool             m_new_tick;
    bool             m_market_open;

public:
    //+------------------------------------------------------------------+
    //| Konstruktor                                                       |
    //+------------------------------------------------------------------+
    CMockDataProvider() {
        // Standardvärden för EUR/USD-liknande symbol
        m_bid = 1.08500;
        m_ask = 1.08520;
        m_spread = 0.00020;
        m_point = 0.00001;
        m_digits = 5;
        m_symbol = "EURUSD";

        // Bars
        m_bar_count = 0;
        m_max_bars = 1000;
        ArrayResize(m_bars, m_max_bars);

        // Indikatorer
        m_indicator_count = 0;
        ArrayResize(m_atr_values, m_max_bars);
        ArrayResize(m_ema_values, m_max_bars);
        ArrayResize(m_rsi_values, m_max_bars);
        ArrayResize(m_adx_values, m_max_bars);
        ArrayResize(m_bb_upper, m_max_bars);
        ArrayResize(m_bb_lower, m_max_bars);
        ArrayResize(m_bb_middle, m_max_bars);

        // Konto
        m_balance = 10000.0;
        m_equity = 10000.0;
        m_free_margin = 10000.0;
        m_account_currency = "USD";
        m_leverage = 100;

        // Symbol
        m_min_lot = 0.01;
        m_max_lot = 100.0;
        m_lot_step = 0.01;
        m_tick_value = 10.0;  // $10 per pip per lot för EUR/USD
        m_tick_size = 0.00001;
        m_contract_size = 100000;

        // Tid
        m_server_time = TimeCurrent();
        m_local_time = TimeLocal();
        m_gmt_offset = 0;

        // Status
        m_new_tick = false;
        m_market_open = true;
    }

    //+------------------------------------------------------------------+
    //| Destruktor                                                        |
    //+------------------------------------------------------------------+
    ~CMockDataProvider() {
        ArrayFree(m_bars);
        ArrayFree(m_atr_values);
        ArrayFree(m_ema_values);
        ArrayFree(m_rsi_values);
        ArrayFree(m_adx_values);
        ArrayFree(m_bb_upper);
        ArrayFree(m_bb_lower);
        ArrayFree(m_bb_middle);
    }

    //=== SETUP-METODER (för att konfigurera mock) ===

    //+------------------------------------------------------------------+
    //| SetPrices - Sätt bid/ask                                          |
    //+------------------------------------------------------------------+
    void SetPrices(double bid, double ask) {
        m_bid = bid;
        m_ask = ask;
        m_spread = ask - bid;
    }

    //+------------------------------------------------------------------+
    //| SetSymbolInfo - Sätt symbolinformation                            |
    //+------------------------------------------------------------------+
    void SetSymbolInfo(string symbol, double point, int digits) {
        m_symbol = symbol;
        m_point = point;
        m_digits = digits;
    }

    //+------------------------------------------------------------------+
    //| SetAccountInfo - Sätt kontoinformation                            |
    //+------------------------------------------------------------------+
    void SetAccountInfo(double balance, double equity, double free_margin = 0) {
        m_balance = balance;
        m_equity = equity;
        m_free_margin = (free_margin == 0) ? equity : free_margin;
    }

    //+------------------------------------------------------------------+
    //| SetLotInfo - Sätt lot-information                                 |
    //+------------------------------------------------------------------+
    void SetLotInfo(double min_lot, double max_lot, double lot_step) {
        m_min_lot = min_lot;
        m_max_lot = max_lot;
        m_lot_step = lot_step;
    }

    //+------------------------------------------------------------------+
    //| SetTime - Sätt tid                                                |
    //+------------------------------------------------------------------+
    void SetTime(datetime server_time, datetime local_time = 0, int gmt_offset = 0) {
        m_server_time = server_time;
        m_local_time = (local_time == 0) ? server_time : local_time;
        m_gmt_offset = gmt_offset;
    }

    //+------------------------------------------------------------------+
    //| AddBar - Lägg till bar-data                                       |
    //+------------------------------------------------------------------+
    void AddBar(datetime time, double open, double high, double low, double close,
                long tick_volume = 100, long real_volume = 0, int spread = 20) {
        if (m_bar_count >= m_max_bars) return;

        m_bars[m_bar_count].time = time;
        m_bars[m_bar_count].open = open;
        m_bars[m_bar_count].high = high;
        m_bars[m_bar_count].low = low;
        m_bars[m_bar_count].close = close;
        m_bars[m_bar_count].tick_volume = tick_volume;
        m_bars[m_bar_count].real_volume = real_volume;
        m_bars[m_bar_count].spread = spread;
        m_bar_count++;
    }

    //+------------------------------------------------------------------+
    //| SetIndicatorValues - Sätt förberäknade indikatorvärden            |
    //+------------------------------------------------------------------+
    void SetIndicatorValues(const double &atr[], const double &ema[],
                            const double &rsi[], const double &adx[],
                            int count) {
        m_indicator_count = MathMin(count, m_max_bars);
        for (int i = 0; i < m_indicator_count; i++) {
            m_atr_values[i] = atr[i];
            m_ema_values[i] = ema[i];
            m_rsi_values[i] = rsi[i];
            m_adx_values[i] = adx[i];
        }
    }

    //+------------------------------------------------------------------+
    //| SetBollingerBands - Sätt BB-värden                                |
    //+------------------------------------------------------------------+
    void SetBollingerBands(const double &upper[], const double &middle[],
                           const double &lower[], int count) {
        int n = MathMin(count, m_max_bars);
        for (int i = 0; i < n; i++) {
            m_bb_upper[i] = upper[i];
            m_bb_middle[i] = middle[i];
            m_bb_lower[i] = lower[i];
        }
    }

    //+------------------------------------------------------------------+
    //| SimulateTick - Simulera ny tick                                   |
    //+------------------------------------------------------------------+
    void SimulateTick(double bid = 0, double ask = 0) {
        if (bid > 0 && ask > 0) {
            SetPrices(bid, ask);
        }
        m_new_tick = true;
    }

    //+------------------------------------------------------------------+
    //| SetMarketOpen - Sätt om marknaden är öppen                        |
    //+------------------------------------------------------------------+
    void SetMarketOpen(bool open) {
        m_market_open = open;
    }

    //=== IDataProvider IMPLEMENTATION ===

    virtual double GetBid() override { return m_bid; }
    virtual double GetAsk() override { return m_ask; }
    virtual double GetSpread() override { return m_spread; }
    virtual double GetSpreadPips() override { return m_spread / m_point / 10.0; }
    virtual double GetPoint() override { return m_point; }
    virtual int GetDigits() override { return m_digits; }

    virtual bool GetBar(ENUM_TIMEFRAMES tf, int shift, BarData &bar) override {
        if (shift < 0 || shift >= m_bar_count) return false;
        // Returnera bars i omvänd ordning (shift 0 = senaste)
        int index = m_bar_count - 1 - shift;
        if (index < 0) return false;
        bar = m_bars[index];
        return true;
    }

    virtual double GetClose(ENUM_TIMEFRAMES tf, int shift) override {
        BarData bar;
        if (!GetBar(tf, shift, bar)) return 0;
        return bar.close;
    }

    virtual double GetOpen(ENUM_TIMEFRAMES tf, int shift) override {
        BarData bar;
        if (!GetBar(tf, shift, bar)) return 0;
        return bar.open;
    }

    virtual double GetHigh(ENUM_TIMEFRAMES tf, int shift) override {
        BarData bar;
        if (!GetBar(tf, shift, bar)) return 0;
        return bar.high;
    }

    virtual double GetLow(ENUM_TIMEFRAMES tf, int shift) override {
        BarData bar;
        if (!GetBar(tf, shift, bar)) return 0;
        return bar.low;
    }

    virtual datetime GetBarTime(ENUM_TIMEFRAMES tf, int shift) override {
        BarData bar;
        if (!GetBar(tf, shift, bar)) return 0;
        return bar.time;
    }

    virtual long GetVolume(ENUM_TIMEFRAMES tf, int shift) override {
        BarData bar;
        if (!GetBar(tf, shift, bar)) return 0;
        return bar.tick_volume;
    }

    virtual int GetBarsCount(ENUM_TIMEFRAMES tf) override {
        return m_bar_count;
    }

    virtual double GetATR(ENUM_TIMEFRAMES tf, int period, int shift) override {
        if (shift < 0 || shift >= m_indicator_count) return 0.0015;  // Default 15 pips
        return m_atr_values[shift];
    }

    virtual double GetEMA(ENUM_TIMEFRAMES tf, int period,
                          ENUM_APPLIED_PRICE applied_price, int shift) override {
        if (shift < 0 || shift >= m_indicator_count) return m_bid;
        return m_ema_values[shift];
    }

    virtual double GetSMA(ENUM_TIMEFRAMES tf, int period,
                          ENUM_APPLIED_PRICE applied_price, int shift) override {
        // Återanvänd EMA för enkelhet
        return GetEMA(tf, period, applied_price, shift);
    }

    virtual double GetRSI(ENUM_TIMEFRAMES tf, int period,
                          ENUM_APPLIED_PRICE applied_price, int shift) override {
        if (shift < 0 || shift >= m_indicator_count) return 50.0;  // Neutral
        return m_rsi_values[shift];
    }

    virtual double GetADX(ENUM_TIMEFRAMES tf, int period, int shift) override {
        if (shift < 0 || shift >= m_indicator_count) return 25.0;  // Moderat trend
        return m_adx_values[shift];
    }

    virtual double GetADXPlusDI(ENUM_TIMEFRAMES tf, int period, int shift) override {
        return 20.0;  // Standardvärde
    }

    virtual double GetADXMinusDI(ENUM_TIMEFRAMES tf, int period, int shift) override {
        return 20.0;  // Standardvärde
    }

    virtual double GetBBUpper(ENUM_TIMEFRAMES tf, int period,
                              double deviation, int shift) override {
        if (shift < 0 || shift >= m_indicator_count) return m_bid + 0.0050;
        return m_bb_upper[shift];
    }

    virtual double GetBBLower(ENUM_TIMEFRAMES tf, int period,
                              double deviation, int shift) override {
        if (shift < 0 || shift >= m_indicator_count) return m_bid - 0.0050;
        return m_bb_lower[shift];
    }

    virtual double GetBBMiddle(ENUM_TIMEFRAMES tf, int period, int shift) override {
        if (shift < 0 || shift >= m_indicator_count) return m_bid;
        return m_bb_middle[shift];
    }

    virtual double GetAccountBalance() override { return m_balance; }
    virtual double GetAccountEquity() override { return m_equity; }
    virtual double GetAccountFreeMargin() override { return m_free_margin; }
    virtual string GetAccountCurrency() override { return m_account_currency; }
    virtual long GetAccountLeverage() override { return m_leverage; }

    virtual datetime GetServerTime() override { return m_server_time; }
    virtual datetime GetLocalTime() override { return m_local_time; }
    virtual int GetGMTOffset() override { return m_gmt_offset; }

    virtual string GetSymbol() override { return m_symbol; }
    virtual double GetMinLot() override { return m_min_lot; }
    virtual double GetMaxLot() override { return m_max_lot; }
    virtual double GetLotStep() override { return m_lot_step; }
    virtual double GetTickValue() override { return m_tick_value; }
    virtual double GetTickSize() override { return m_tick_size; }
    virtual double GetContractSize() override { return m_contract_size; }

    virtual bool HasNewTick() override { return m_new_tick; }
    virtual void ResetTickFlag() override { m_new_tick = false; }

    virtual bool IsMarketOpen() override { return m_market_open; }
};

//+------------------------------------------------------------------+
