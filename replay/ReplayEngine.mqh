//+------------------------------------------------------------------+
//|                                                ReplayEngine.mqh   |
//|                                Copyright 2024, Gridzilla Project  |
//+------------------------------------------------------------------+
#property copyright "Gridzilla Project"
#property version   "1.00"
#property strict

#include "..\src\interfaces\IDataProvider.mqh"
#include "DataRecorder.mqh"

//+------------------------------------------------------------------+
//| Replay-tillstånd                                                  |
//+------------------------------------------------------------------+
enum ENUM_REPLAY_STATE {
    REPLAY_STOPPED = 0,
    REPLAY_PLAYING = 1,
    REPLAY_PAUSED = 2,
    REPLAY_FINISHED = 3
};

//+------------------------------------------------------------------+
//| CReplayEngine - Spelar upp sparad marknaddata                     |
//|                                                                   |
//| Syfte: Möjliggöra deterministisk uppspelning av marknaddata för   |
//| testning och validering. Samma input ska ge exakt samma output.   |
//|                                                                   |
//| Implementerar IDataProvider för att kunna användas som drop-in    |
//| ersättning för live-data.                                         |
//+------------------------------------------------------------------+
class CReplayEngine : public IDataProvider {
private:
    //--- Inlästa data
    TickRecord       m_ticks[];
    int              m_tick_count;
    BarData          m_bars[];
    int              m_bar_count;

    //--- Replay-tillstånd
    ENUM_REPLAY_STATE m_state;
    int              m_current_tick_index;
    int              m_current_bar_index;
    datetime         m_replay_time;
    double           m_speed_multiplier;

    //--- Aktuella simulerade värden
    double           m_current_bid;
    double           m_current_ask;
    bool             m_new_tick;

    //--- Konfiguration
    string           m_symbol;
    double           m_point;
    int              m_digits;
    double           m_min_lot;
    double           m_max_lot;
    double           m_lot_step;

    //--- Kontosimulering
    double           m_account_balance;
    double           m_account_equity;

    //--- Determinism
    uint             m_random_seed;

    //--- Indikatorvärden (förberäknade för enkel replay)
    double           m_atr_values[];
    double           m_ema_values[];
    double           m_rsi_values[];
    int              m_indicator_count;

public:
    //+------------------------------------------------------------------+
    //| Konstruktor                                                       |
    //+------------------------------------------------------------------+
    CReplayEngine() {
        m_tick_count = 0;
        m_bar_count = 0;
        m_state = REPLAY_STOPPED;
        m_current_tick_index = 0;
        m_current_bar_index = 0;
        m_replay_time = 0;
        m_speed_multiplier = 1.0;

        m_current_bid = 0;
        m_current_ask = 0;
        m_new_tick = false;

        m_symbol = "EURUSD";
        m_point = 0.00001;
        m_digits = 5;
        m_min_lot = 0.01;
        m_max_lot = 100.0;
        m_lot_step = 0.01;

        m_account_balance = 10000.0;
        m_account_equity = 10000.0;

        m_random_seed = 12345;
        m_indicator_count = 0;
    }

    //+------------------------------------------------------------------+
    //| Destruktor                                                        |
    //+------------------------------------------------------------------+
    ~CReplayEngine() {
        ArrayFree(m_ticks);
        ArrayFree(m_bars);
        ArrayFree(m_atr_values);
        ArrayFree(m_ema_values);
        ArrayFree(m_rsi_values);
    }

    //=== DATA-LADDNING ===

    //+------------------------------------------------------------------+
    //| LoadFromArrays - Ladda data från arrays                           |
    //+------------------------------------------------------------------+
    bool LoadFromArrays(const TickRecord &ticks[], int tick_count,
                        const BarData &bars[], int bar_count) {
        // Kopiera ticks
        m_tick_count = tick_count;
        ArrayResize(m_ticks, m_tick_count);
        for (int i = 0; i < m_tick_count; i++) {
            m_ticks[i] = ticks[i];
        }

        // Kopiera bars
        m_bar_count = bar_count;
        ArrayResize(m_bars, m_bar_count);
        for (int i = 0; i < m_bar_count; i++) {
            m_bars[i] = bars[i];
        }

        Reset();
        return true;
    }

    //+------------------------------------------------------------------+
    //| LoadSyntheticTrendingUp - Generera syntetisk trendande uppåt      |
    //+------------------------------------------------------------------+
    bool LoadSyntheticTrendingUp(double start_price, double end_price,
                                  int duration_bars, datetime start_time) {
        // Generera bars
        m_bar_count = duration_bars;
        ArrayResize(m_bars, m_bar_count);

        double price_step = (end_price - start_price) / duration_bars;
        double current_price = start_price;
        datetime bar_time = start_time;

        for (int i = 0; i < m_bar_count; i++) {
            m_bars[i].time = bar_time;
            m_bars[i].open = current_price;
            m_bars[i].high = current_price + 0.0005;  // 5 pips range
            m_bars[i].low = current_price - 0.0003;
            m_bars[i].close = current_price + price_step;
            m_bars[i].tick_volume = 100;
            m_bars[i].real_volume = 0;
            m_bars[i].spread = 20;

            current_price = m_bars[i].close;
            bar_time += 60;  // M1 bars
        }

        // Generera ticks (10 per bar)
        m_tick_count = m_bar_count * 10;
        ArrayResize(m_ticks, m_tick_count);

        int tick_index = 0;
        for (int i = 0; i < m_bar_count; i++) {
            double bar_range = m_bars[i].close - m_bars[i].open;

            for (int j = 0; j < 10; j++) {
                double progress = (double)j / 10.0;
                m_ticks[tick_index].time = m_bars[i].time + j * 6;  // 6 sekunder mellan ticks
                m_ticks[tick_index].time_msc = 0;
                m_ticks[tick_index].bid = m_bars[i].open + bar_range * progress;
                m_ticks[tick_index].ask = m_ticks[tick_index].bid + 0.0002;  // 2 pip spread
                m_ticks[tick_index].volume = 10;
                m_ticks[tick_index].flags = 0;
                tick_index++;
            }
        }

        Reset();
        Print("Loaded synthetic trending up data: ", m_tick_count, " ticks, ", m_bar_count, " bars");
        return true;
    }

    //+------------------------------------------------------------------+
    //| LoadSyntheticRanging - Generera syntetisk ranging-marknad         |
    //+------------------------------------------------------------------+
    bool LoadSyntheticRanging(double center_price, double range_pips,
                               int duration_bars, datetime start_time) {
        m_bar_count = duration_bars;
        ArrayResize(m_bars, m_bar_count);

        double range = range_pips * m_point * 10;  // Konvertera pips till pris
        datetime bar_time = start_time;

        // Använd deterministisk pseudo-random baserat på seed
        MathSrand(m_random_seed);

        for (int i = 0; i < m_bar_count; i++) {
            // Oscillera runt center
            double phase = MathSin(i * 0.3);
            double noise = (MathRand() / 32768.0 - 0.5) * range * 0.2;

            double mid_price = center_price + phase * range * 0.5 + noise;

            m_bars[i].time = bar_time;
            m_bars[i].open = mid_price - 0.0002;
            m_bars[i].high = mid_price + 0.0004;
            m_bars[i].low = mid_price - 0.0004;
            m_bars[i].close = mid_price + 0.0002;
            m_bars[i].tick_volume = 100;
            m_bars[i].real_volume = 0;
            m_bars[i].spread = 20;

            bar_time += 60;
        }

        // Generera ticks
        m_tick_count = m_bar_count * 10;
        ArrayResize(m_ticks, m_tick_count);

        int tick_index = 0;
        for (int i = 0; i < m_bar_count; i++) {
            for (int j = 0; j < 10; j++) {
                double progress = (double)j / 10.0;
                m_ticks[tick_index].time = m_bars[i].time + j * 6;
                m_ticks[tick_index].time_msc = 0;
                m_ticks[tick_index].bid = m_bars[i].open +
                    (m_bars[i].close - m_bars[i].open) * progress;
                m_ticks[tick_index].ask = m_ticks[tick_index].bid + 0.0002;
                m_ticks[tick_index].volume = 10;
                m_ticks[tick_index].flags = 0;
                tick_index++;
            }
        }

        Reset();
        Print("Loaded synthetic ranging data: ", m_tick_count, " ticks, ", m_bar_count, " bars");
        return true;
    }

    //=== REPLAY-KONTROLL ===

    //+------------------------------------------------------------------+
    //| Play - Starta uppspelning                                         |
    //+------------------------------------------------------------------+
    void Play() {
        if (m_tick_count == 0) return;
        m_state = REPLAY_PLAYING;
    }

    //+------------------------------------------------------------------+
    //| Pause - Pausa uppspelning                                         |
    //+------------------------------------------------------------------+
    void Pause() {
        if (m_state == REPLAY_PLAYING) {
            m_state = REPLAY_PAUSED;
        }
    }

    //+------------------------------------------------------------------+
    //| Stop - Stoppa uppspelning                                         |
    //+------------------------------------------------------------------+
    void Stop() {
        m_state = REPLAY_STOPPED;
    }

    //+------------------------------------------------------------------+
    //| Reset - Återställ till början                                     |
    //+------------------------------------------------------------------+
    void Reset() {
        m_current_tick_index = 0;
        m_current_bar_index = 0;
        m_state = REPLAY_STOPPED;
        m_new_tick = false;

        if (m_tick_count > 0) {
            m_current_bid = m_ticks[0].bid;
            m_current_ask = m_ticks[0].ask;
            m_replay_time = m_ticks[0].time;
        }

        // Återställ random seed för determinism
        MathSrand(m_random_seed);
    }

    //+------------------------------------------------------------------+
    //| StepForward - Gå framåt ett antal ticks                           |
    //+------------------------------------------------------------------+
    bool StepForward(int ticks = 1) {
        for (int i = 0; i < ticks; i++) {
            if (!AdvanceOneTick()) {
                return false;
            }
        }
        return true;
    }

    //+------------------------------------------------------------------+
    //| AdvanceOneTick - Gå framåt en tick                                |
    //+------------------------------------------------------------------+
    bool AdvanceOneTick() {
        if (m_current_tick_index >= m_tick_count) {
            m_state = REPLAY_FINISHED;
            return false;
        }

        // Ladda nästa tick
        m_current_bid = m_ticks[m_current_tick_index].bid;
        m_current_ask = m_ticks[m_current_tick_index].ask;
        m_replay_time = m_ticks[m_current_tick_index].time;
        m_new_tick = true;

        // Uppdatera bar-index om relevant
        while (m_current_bar_index < m_bar_count - 1 &&
               m_bars[m_current_bar_index + 1].time <= m_replay_time) {
            m_current_bar_index++;
        }

        m_current_tick_index++;
        return true;
    }

    //+------------------------------------------------------------------+
    //| SeekToTime - Hoppa till specifik tid                              |
    //+------------------------------------------------------------------+
    void SeekToTime(datetime time) {
        for (int i = 0; i < m_tick_count; i++) {
            if (m_ticks[i].time >= time) {
                m_current_tick_index = i;
                if (i > 0) i--;
                m_current_bid = m_ticks[i].bid;
                m_current_ask = m_ticks[i].ask;
                m_replay_time = m_ticks[i].time;
                break;
            }
        }
    }

    //+------------------------------------------------------------------+
    //| SetSpeed - Sätt uppspelningshastighet                             |
    //+------------------------------------------------------------------+
    void SetSpeed(double multiplier) {
        m_speed_multiplier = MathMax(0.1, multiplier);
    }

    //+------------------------------------------------------------------+
    //| SetRandomSeed - Sätt random seed för determinism                  |
    //+------------------------------------------------------------------+
    void SetRandomSeed(uint seed) {
        m_random_seed = seed;
        MathSrand(seed);
    }

    //+------------------------------------------------------------------+
    //| GetRandomSeed - Hämta nuvarande random seed                       |
    //+------------------------------------------------------------------+
    uint GetRandomSeed() {
        return m_random_seed;
    }

    //=== STATUSFRÅGOR ===

    //+------------------------------------------------------------------+
    //| GetState - Hämta replay-tillstånd                                 |
    //+------------------------------------------------------------------+
    ENUM_REPLAY_STATE GetState() {
        return m_state;
    }

    //+------------------------------------------------------------------+
    //| GetCurrentTickIndex - Hämta nuvarande tick-index                  |
    //+------------------------------------------------------------------+
    int GetCurrentTickIndex() {
        return m_current_tick_index;
    }

    //+------------------------------------------------------------------+
    //| GetTotalTicks - Hämta totalt antal ticks                          |
    //+------------------------------------------------------------------+
    int GetTotalTicks() {
        return m_tick_count;
    }

    //+------------------------------------------------------------------+
    //| GetProgressPercent - Hämta framsteg i procent                     |
    //+------------------------------------------------------------------+
    double GetProgressPercent() {
        if (m_tick_count == 0) return 0;
        return (double)m_current_tick_index / m_tick_count * 100.0;
    }

    //+------------------------------------------------------------------+
    //| GetReplayTime - Hämta nuvarande replay-tid                        |
    //+------------------------------------------------------------------+
    datetime GetReplayTime() {
        return m_replay_time;
    }

    //+------------------------------------------------------------------+
    //| SetSymbolInfo - Konfigurera symbolinformation                     |
    //+------------------------------------------------------------------+
    void SetSymbolInfo(string symbol, double point, int digits) {
        m_symbol = symbol;
        m_point = point;
        m_digits = digits;
    }

    //+------------------------------------------------------------------+
    //| SetAccountInfo - Konfigurera kontoinformation                     |
    //+------------------------------------------------------------------+
    void SetAccountInfo(double balance, double equity) {
        m_account_balance = balance;
        m_account_equity = equity;
    }

    //=== IDataProvider IMPLEMENTATION ===

    virtual double GetBid() override { return m_current_bid; }
    virtual double GetAsk() override { return m_current_ask; }
    virtual double GetSpread() override { return m_current_ask - m_current_bid; }
    virtual double GetSpreadPips() override { return GetSpread() / m_point / 10.0; }
    virtual double GetPoint() override { return m_point; }
    virtual int GetDigits() override { return m_digits; }

    virtual bool GetBar(ENUM_TIMEFRAMES tf, int shift, BarData &bar) override {
        int idx = m_current_bar_index - shift;
        if (idx < 0 || idx >= m_bar_count) return false;
        bar = m_bars[idx];
        return true;
    }

    virtual double GetClose(ENUM_TIMEFRAMES tf, int shift) override {
        BarData bar;
        if (!GetBar(tf, shift, bar)) return m_current_bid;
        return bar.close;
    }

    virtual double GetOpen(ENUM_TIMEFRAMES tf, int shift) override {
        BarData bar;
        if (!GetBar(tf, shift, bar)) return m_current_bid;
        return bar.open;
    }

    virtual double GetHigh(ENUM_TIMEFRAMES tf, int shift) override {
        BarData bar;
        if (!GetBar(tf, shift, bar)) return m_current_bid;
        return bar.high;
    }

    virtual double GetLow(ENUM_TIMEFRAMES tf, int shift) override {
        BarData bar;
        if (!GetBar(tf, shift, bar)) return m_current_bid;
        return bar.low;
    }

    virtual datetime GetBarTime(ENUM_TIMEFRAMES tf, int shift) override {
        BarData bar;
        if (!GetBar(tf, shift, bar)) return m_replay_time;
        return bar.time;
    }

    virtual long GetVolume(ENUM_TIMEFRAMES tf, int shift) override {
        BarData bar;
        if (!GetBar(tf, shift, bar)) return 0;
        return bar.tick_volume;
    }

    virtual int GetBarsCount(ENUM_TIMEFRAMES tf) override {
        return m_current_bar_index + 1;
    }

    // Indikatorer returnerar rimliga standardvärden
    virtual double GetATR(ENUM_TIMEFRAMES tf, int period, int shift) override {
        return 0.0015;  // 15 pips
    }

    virtual double GetEMA(ENUM_TIMEFRAMES tf, int period,
                          ENUM_APPLIED_PRICE applied_price, int shift) override {
        return m_current_bid;
    }

    virtual double GetSMA(ENUM_TIMEFRAMES tf, int period,
                          ENUM_APPLIED_PRICE applied_price, int shift) override {
        return m_current_bid;
    }

    virtual double GetRSI(ENUM_TIMEFRAMES tf, int period,
                          ENUM_APPLIED_PRICE applied_price, int shift) override {
        return 50.0;
    }

    virtual double GetADX(ENUM_TIMEFRAMES tf, int period, int shift) override {
        return 25.0;
    }

    virtual double GetADXPlusDI(ENUM_TIMEFRAMES tf, int period, int shift) override {
        return 20.0;
    }

    virtual double GetADXMinusDI(ENUM_TIMEFRAMES tf, int period, int shift) override {
        return 20.0;
    }

    virtual double GetBBUpper(ENUM_TIMEFRAMES tf, int period,
                              double deviation, int shift) override {
        return m_current_bid + 0.0050;
    }

    virtual double GetBBLower(ENUM_TIMEFRAMES tf, int period,
                              double deviation, int shift) override {
        return m_current_bid - 0.0050;
    }

    virtual double GetBBMiddle(ENUM_TIMEFRAMES tf, int period, int shift) override {
        return m_current_bid;
    }

    virtual double GetAccountBalance() override { return m_account_balance; }
    virtual double GetAccountEquity() override { return m_account_equity; }
    virtual double GetAccountFreeMargin() override { return m_account_equity; }
    virtual string GetAccountCurrency() override { return "USD"; }
    virtual long GetAccountLeverage() override { return 100; }

    virtual datetime GetServerTime() override { return m_replay_time; }
    virtual datetime GetLocalTime() override { return m_replay_time; }
    virtual int GetGMTOffset() override { return 0; }

    virtual string GetSymbol() override { return m_symbol; }
    virtual double GetMinLot() override { return m_min_lot; }
    virtual double GetMaxLot() override { return m_max_lot; }
    virtual double GetLotStep() override { return m_lot_step; }
    virtual double GetTickValue() override { return 10.0; }
    virtual double GetTickSize() override { return m_point; }
    virtual double GetContractSize() override { return 100000; }

    virtual bool HasNewTick() override { return m_new_tick; }
    virtual void ResetTickFlag() override { m_new_tick = false; }

    virtual bool IsMarketOpen() override { return true; }
};

//+------------------------------------------------------------------+
