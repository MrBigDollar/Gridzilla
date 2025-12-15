//+------------------------------------------------------------------+
//|                                             IOrderExecutor.mqh    |
//|                                Copyright 2024, Gridzilla Project  |
//+------------------------------------------------------------------+
#property copyright "Gridzilla Project"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| OrderResult - Resultat från orderoperation                        |
//+------------------------------------------------------------------+
struct OrderResult {
    bool     success;           // Om ordern lyckades
    long     ticket;            // Order/position ticket (-1 vid fel)
    double   fill_price;        // Faktiskt fyllnadspris
    double   fill_lots;         // Faktisk fyllnadsvolym
    int      error_code;        // MT5 felkod (0 = inget fel)
    string   error_message;     // Felbeskrivning

    //--- Konstruktor med standardvärden
    OrderResult() {
        success = false;
        ticket = -1;
        fill_price = 0.0;
        fill_lots = 0.0;
        error_code = 0;
        error_message = "";
    }
};

//+------------------------------------------------------------------+
//| PositionInfo - Information om en öppen position                   |
//+------------------------------------------------------------------+
struct PositionInfo {
    long     ticket;            // Position ticket
    string   symbol;            // Handelsinstrument
    int      type;              // POSITION_TYPE_BUY eller POSITION_TYPE_SELL
    double   lots;              // Volym
    double   open_price;        // Öppningspris
    double   current_price;     // Aktuellt pris
    double   sl;                // Stop Loss
    double   tp;                // Take Profit
    double   profit;            // Orealiserad vinst/förlust
    double   swap;              // Swap-kostnad
    double   commission;        // Kommission
    datetime open_time;         // Öppningstid
    string   comment;           // Order-kommentar
    long     magic;             // Magic number

    //--- Konstruktor med standardvärden
    PositionInfo() {
        ticket = -1;
        symbol = "";
        type = -1;
        lots = 0.0;
        open_price = 0.0;
        current_price = 0.0;
        sl = 0.0;
        tp = 0.0;
        profit = 0.0;
        swap = 0.0;
        commission = 0.0;
        open_time = 0;
        comment = "";
        magic = 0;
    }
};

//+------------------------------------------------------------------+
//| PendingOrderInfo - Information om en pending order                |
//+------------------------------------------------------------------+
struct PendingOrderInfo {
    long     ticket;            // Order ticket
    string   symbol;            // Handelsinstrument
    int      type;              // ORDER_TYPE_BUY_LIMIT, etc.
    double   lots;              // Volym
    double   price;             // Orderpris
    double   sl;                // Stop Loss
    double   tp;                // Take Profit
    datetime time_setup;        // När ordern sattes
    datetime expiration;        // Utgångstid (0 = ingen)
    string   comment;           // Order-kommentar
    long     magic;             // Magic number

    //--- Konstruktor med standardvärden
    PendingOrderInfo() {
        ticket = -1;
        symbol = "";
        type = -1;
        lots = 0.0;
        price = 0.0;
        sl = 0.0;
        tp = 0.0;
        time_setup = 0;
        expiration = 0;
        comment = "";
        magic = 0;
    }
};

//+------------------------------------------------------------------+
//| IOrderExecutor - Abstrakt basklass för orderexekvering            |
//|                                                                   |
//| Syfte: Abstrahera all orderhantering från MT5.                    |
//| Moduler får ALDRIG direkt använda OrderSend() etc. - allt går     |
//| via detta interface. Detta möjliggör testning utan riktiga ordrar.|
//+------------------------------------------------------------------+
class IOrderExecutor {
public:
    //--- Destruktor
    virtual ~IOrderExecutor() {}

    //=== MARKNADSORDRAR ===

    //--- Skicka marknadsorder (köp eller sälj direkt)
    //    symbol: Handelsinstrument
    //    type: ORDER_TYPE_BUY eller ORDER_TYPE_SELL
    //    lots: Volym
    //    sl: Stop Loss pris (0 = ingen SL)
    //    tp: Take Profit pris (0 = ingen TP)
    //    comment: Order-kommentar
    //    magic: Magic number för identifiering
    virtual OrderResult SendMarketOrder(string symbol,
                                        int type,
                                        double lots,
                                        double sl,
                                        double tp,
                                        string comment,
                                        long magic) = 0;

    //=== PENDING ORDERS ===

    //--- Skicka pending order
    //    symbol: Handelsinstrument
    //    type: ORDER_TYPE_BUY_LIMIT, ORDER_TYPE_SELL_LIMIT, etc.
    //    lots: Volym
    //    price: Orderpris
    //    sl: Stop Loss pris (0 = ingen SL)
    //    tp: Take Profit pris (0 = ingen TP)
    //    comment: Order-kommentar
    //    magic: Magic number
    //    expiration: Utgångstid (0 = ingen)
    virtual OrderResult SendPendingOrder(string symbol,
                                         int type,
                                         double lots,
                                         double price,
                                         double sl,
                                         double tp,
                                         string comment,
                                         long magic,
                                         datetime expiration = 0) = 0;

    //--- Ta bort pending order
    virtual bool DeletePendingOrder(long ticket) = 0;

    //=== POSITIONSHANTERING ===

    //--- Stäng position (helt eller delvis)
    //    ticket: Position ticket
    //    lots: Volym att stänga (0 = hela positionen)
    virtual bool ClosePosition(long ticket, double lots = 0) = 0;

    //--- Modifiera position (SL/TP)
    //    ticket: Position ticket
    //    sl: Nytt Stop Loss pris
    //    tp: Nytt Take Profit pris
    virtual bool ModifyPosition(long ticket, double sl, double tp) = 0;

    //--- Stäng alla positioner
    //    symbol: Filtrera på symbol (tom sträng = alla symboler)
    //    magic: Filtrera på magic (0 = alla magic numbers)
    virtual bool CloseAllPositions(string symbol = "", long magic = 0) = 0;

    //=== POSITIONSFRÅGOR ===

    //--- Antal öppna positioner
    //    symbol: Filtrera på symbol (tom sträng = alla)
    //    magic: Filtrera på magic (0 = alla)
    virtual int GetPositionCount(string symbol = "", long magic = 0) = 0;

    //--- Hämta position via ticket
    //    ticket: Position ticket
    //    info: Output-struct för positionsdata
    //    Returnerar true om positionen hittades
    virtual bool GetPositionByTicket(long ticket, PositionInfo &info) = 0;

    //--- Hämta position via index
    //    index: Index (0 till GetPositionCount()-1)
    //    info: Output-struct för positionsdata
    //    Returnerar true om positionen hittades
    virtual bool GetPositionByIndex(int index, PositionInfo &info) = 0;

    //--- Hämta position via symbol och magic
    //    symbol: Handelsinstrument
    //    magic: Magic number
    //    info: Output-struct för positionsdata
    //    Returnerar true om positionen hittades
    virtual bool GetPositionBySymbolMagic(string symbol, long magic,
                                          PositionInfo &info) = 0;

    //--- Total volym för alla positioner
    //    symbol: Filtrera på symbol (tom sträng = alla)
    //    magic: Filtrera på magic (0 = alla)
    virtual double GetTotalLots(string symbol = "", long magic = 0) = 0;

    //--- Total orealiserad vinst/förlust
    //    symbol: Filtrera på symbol (tom sträng = alla)
    //    magic: Filtrera på magic (0 = alla)
    virtual double GetTotalProfit(string symbol = "", long magic = 0) = 0;

    //=== PENDING ORDER-FRÅGOR ===

    //--- Antal pending orders
    virtual int GetPendingOrderCount(string symbol = "", long magic = 0) = 0;

    //--- Hämta pending order via ticket
    virtual bool GetPendingOrderByTicket(long ticket, PendingOrderInfo &info) = 0;

    //--- Hämta pending order via index
    virtual bool GetPendingOrderByIndex(int index, PendingOrderInfo &info) = 0;

    //=== VALIDERING ===

    //--- Är handel tillåten?
    virtual bool IsTradeAllowed() = 0;

    //--- Är expert trading aktiverat?
    virtual bool IsExpertEnabled() = 0;

    //--- Normalisera lot-storlek till symbolens krav
    virtual double NormalizeLots(string symbol, double lots) = 0;

    //--- Normalisera pris till symbolens decimaler
    virtual double NormalizePrice(string symbol, double price) = 0;

    //--- Validera SL/TP mot minimum distance
    virtual bool ValidateStopLevel(string symbol, double price,
                                   double sl, double tp) = 0;
};

//+------------------------------------------------------------------+
