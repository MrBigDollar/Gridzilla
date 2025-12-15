//+------------------------------------------------------------------+
//|                                              IDataProvider.mqh    |
//|                                Copyright 2024, Gridzilla Project  |
//+------------------------------------------------------------------+
#property copyright "Gridzilla Project"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| BarData - Struct för bar-data                                     |
//+------------------------------------------------------------------+
struct BarData {
    datetime time;
    double   open;
    double   high;
    double   low;
    double   close;
    long     tick_volume;
    long     real_volume;
    int      spread;
};

//+------------------------------------------------------------------+
//| IDataProvider - Abstrakt basklass för marknadsdataåtkomst         |
//|                                                                   |
//| Syfte: Abstrahera all marknadsdataåtkomst från MT5.               |
//| Moduler får ALDRIG direkt läsa MT5-data - allt går via detta      |
//| interface. Detta möjliggör testning med mock-data och replay.     |
//+------------------------------------------------------------------+
class IDataProvider {
public:
    //--- Destruktor
    virtual ~IDataProvider() {}

    //=== PRISDATA ===

    //--- Aktuellt bid-pris
    virtual double GetBid() = 0;

    //--- Aktuellt ask-pris
    virtual double GetAsk() = 0;

    //--- Aktuell spread i points
    virtual double GetSpread() = 0;

    //--- Spread i pips (normaliserat)
    virtual double GetSpreadPips() = 0;

    //--- Point-värde för symbolen
    virtual double GetPoint() = 0;

    //--- Antal decimaler
    virtual int GetDigits() = 0;

    //=== BAR-DATA ===

    //--- Hämta komplett bar-data
    //    tf: Timeframe (PERIOD_M1, PERIOD_H1, etc.)
    //    shift: Bar-index (0 = nuvarande, 1 = föregående, etc.)
    //    bar: Output-struct för bar-data
    //    Returnerar true om framgångsrikt
    virtual bool GetBar(ENUM_TIMEFRAMES tf, int shift, BarData &bar) = 0;

    //--- Hämta enskilda bar-värden
    virtual double GetClose(ENUM_TIMEFRAMES tf, int shift) = 0;
    virtual double GetOpen(ENUM_TIMEFRAMES tf, int shift) = 0;
    virtual double GetHigh(ENUM_TIMEFRAMES tf, int shift) = 0;
    virtual double GetLow(ENUM_TIMEFRAMES tf, int shift) = 0;
    virtual datetime GetBarTime(ENUM_TIMEFRAMES tf, int shift) = 0;
    virtual long GetVolume(ENUM_TIMEFRAMES tf, int shift) = 0;

    //--- Antal tillgängliga bars
    virtual int GetBarsCount(ENUM_TIMEFRAMES tf) = 0;

    //=== INDIKATORER ===

    //--- ATR (Average True Range)
    //    tf: Timeframe
    //    period: ATR-period (typiskt 14)
    //    shift: Bar-index
    virtual double GetATR(ENUM_TIMEFRAMES tf, int period, int shift) = 0;

    //--- EMA (Exponential Moving Average)
    //    tf: Timeframe
    //    period: EMA-period
    //    applied_price: PRICE_CLOSE, PRICE_OPEN, etc.
    //    shift: Bar-index
    virtual double GetEMA(ENUM_TIMEFRAMES tf, int period,
                          ENUM_APPLIED_PRICE applied_price, int shift) = 0;

    //--- SMA (Simple Moving Average)
    virtual double GetSMA(ENUM_TIMEFRAMES tf, int period,
                          ENUM_APPLIED_PRICE applied_price, int shift) = 0;

    //--- RSI (Relative Strength Index)
    //    tf: Timeframe
    //    period: RSI-period (typiskt 14)
    //    applied_price: PRICE_CLOSE, etc.
    //    shift: Bar-index
    virtual double GetRSI(ENUM_TIMEFRAMES tf, int period,
                          ENUM_APPLIED_PRICE applied_price, int shift) = 0;

    //--- ADX (Average Directional Index)
    //    tf: Timeframe
    //    period: ADX-period (typiskt 14)
    //    shift: Bar-index
    virtual double GetADX(ENUM_TIMEFRAMES tf, int period, int shift) = 0;

    //--- ADX +DI
    virtual double GetADXPlusDI(ENUM_TIMEFRAMES tf, int period, int shift) = 0;

    //--- ADX -DI
    virtual double GetADXMinusDI(ENUM_TIMEFRAMES tf, int period, int shift) = 0;

    //--- Bollinger Bands
    //    tf: Timeframe
    //    period: BB-period (typiskt 20)
    //    deviation: Antal standardavvikelser (typiskt 2.0)
    //    shift: Bar-index
    virtual double GetBBUpper(ENUM_TIMEFRAMES tf, int period,
                              double deviation, int shift) = 0;
    virtual double GetBBLower(ENUM_TIMEFRAMES tf, int period,
                              double deviation, int shift) = 0;
    virtual double GetBBMiddle(ENUM_TIMEFRAMES tf, int period, int shift) = 0;

    //=== KONTOINFORMATION ===

    //--- Kontobalans
    virtual double GetAccountBalance() = 0;

    //--- Kontoequity (balans + orealiserad P/L)
    virtual double GetAccountEquity() = 0;

    //--- Fri marginal
    virtual double GetAccountFreeMargin() = 0;

    //--- Kontovaluta (t.ex. "USD", "EUR")
    virtual string GetAccountCurrency() = 0;

    //--- Hävstång
    virtual long GetAccountLeverage() = 0;

    //=== TIDSINFORMATION ===

    //--- Server-tid
    virtual datetime GetServerTime() = 0;

    //--- Lokal tid
    virtual datetime GetLocalTime() = 0;

    //--- GMT-offset i sekunder
    virtual int GetGMTOffset() = 0;

    //=== SYMBOLINFORMATION ===

    //--- Aktuell symbol
    virtual string GetSymbol() = 0;

    //--- Minsta lot-storlek
    virtual double GetMinLot() = 0;

    //--- Största lot-storlek
    virtual double GetMaxLot() = 0;

    //--- Lot-steg
    virtual double GetLotStep() = 0;

    //--- Tick-värde (värde per tick i kontovaluta)
    virtual double GetTickValue() = 0;

    //--- Tick-storlek
    virtual double GetTickSize() = 0;

    //--- Kontraktsstorlek
    virtual double GetContractSize() = 0;

    //=== TICK-HANTERING (för replay) ===

    //--- Kontrollera om ny tick har anlänt
    virtual bool HasNewTick() = 0;

    //--- Återställ tick-flagga
    virtual void ResetTickFlag() = 0;

    //=== MARKNADS-STATUS ===

    //--- Är marknaden öppen för handel?
    virtual bool IsMarketOpen() = 0;
};

//+------------------------------------------------------------------+
