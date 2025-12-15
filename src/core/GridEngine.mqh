//+------------------------------------------------------------------+
//|                                                   GridEngine.mqh |
//|                                Copyright 2024, Gridzilla Project  |
//+------------------------------------------------------------------+
#property copyright "Gridzilla Project"
#property version   "1.00"
#property strict

#include "..\interfaces\IDataProvider.mqh"
#include "..\interfaces\IOrderExecutor.mqh"
#include "..\interfaces\ILogger.mqh"
#include "PositionManager.mqh"
#include "RiskEngine.mqh"

//+------------------------------------------------------------------+
//| Konstanter                                                        |
//+------------------------------------------------------------------+
#define MAX_GRID_LEVELS 8

//+------------------------------------------------------------------+
//| GridLevel - En enskild grid-nivå                                  |
//+------------------------------------------------------------------+
struct GridLevel {
    int      level_number;      // 0, 1, 2, ... 7
    double   open_price;        // Entry-pris för denna nivå
    double   lot_size;          // Volym för denna nivå
    long     ticket;            // Positionens ticket
    datetime open_time;         // När nivån öppnades
    bool     is_active;         // Är nivån öppen?

    //--- Konstruktor
    GridLevel() {
        level_number = 0;
        open_price = 0.0;
        lot_size = 0.0;
        ticket = 0;
        open_time = 0;
        is_active = false;
    }
};

//+------------------------------------------------------------------+
//| GridConfig - Konfiguration för grid                               |
//+------------------------------------------------------------------+
struct GridConfig {
    double spacing_pips;        // Avstånd mellan nivåer i pips
    double lot_multiplier;      // Multiplikator för lots per nivå
    double base_lot_size;       // Bas lot size för nivå 0
    int    max_levels;          // Max antal nivåer
    double max_total_lots;      // Max total volym

    //--- Konstruktor med standardvärden
    GridConfig() {
        spacing_pips = 50.0;        // 50 pips mellan nivåer
        lot_multiplier = 1.5;       // 1.5x per nivå
        base_lot_size = 0.01;       // Starta med 0.01 lots
        max_levels = 8;             // Max 8 nivåer
        max_total_lots = 5.0;       // Max 5.0 lots totalt
    }
};

//+------------------------------------------------------------------+
//| GridState - Aggregerat state för grid                             |
//+------------------------------------------------------------------+
struct GridState {
    bool   is_active;               // Är grid aktiv?
    int    direction;               // POSITION_TYPE_BUY eller SELL
    int    active_levels;           // Antal öppna nivåer
    double total_grid_lots;         // Total volym
    double average_entry_price;     // Viktat snittpris
    double unrealized_pnl;          // Orealiserad P/L
    GridLevel levels[MAX_GRID_LEVELS]; // Max 8 nivåer

    //--- Konstruktor
    GridState() {
        is_active = false;
        direction = POSITION_TYPE_BUY;
        active_levels = 0;
        total_grid_lots = 0.0;
        average_entry_price = 0.0;
        unrealized_pnl = 0.0;
    }
};

//+------------------------------------------------------------------+
//| GridDecision - Resultat från Evaluate()                           |
//+------------------------------------------------------------------+
struct GridDecision {
    bool   can_add_level;           // Tillåtet att lägga till nivå?
    bool   should_close_all;        // Stäng allt?
    double next_level_price;        // Pris för nästa nivå
    double next_level_lots;         // Volym för nästa nivå
    string block_reason;            // Anledning om blockerad

    //--- Konstruktor
    GridDecision() {
        can_add_level = false;
        should_close_all = false;
        next_level_price = 0.0;
        next_level_lots = 0.0;
        block_reason = "";
    }
};

//+------------------------------------------------------------------+
//| CGridEngine - Minimal horisontell grid                            |
//|                                                                   |
//| Syfte: Hantera grid-positioner med fasta parametrar.              |
//| Respekterar alltid RiskEngine hard limits.                        |
//+------------------------------------------------------------------+
class CGridEngine {
private:
    //--- Beroenden
    IDataProvider*      m_data;
    IOrderExecutor*     m_executor;
    ILogger*            m_logger;
    CPositionManager*   m_position_manager;
    CRiskEngine*        m_risk_engine;

    //--- Konfiguration
    string              m_symbol;
    long                m_magic;
    bool                m_initialized;
    GridConfig          m_config;
    GridState           m_state;

    //=== PRIVATA METODER ===

    //+------------------------------------------------------------------+
    //| UpdateGridState - Synka state från executor                       |
    //+------------------------------------------------------------------+
    void UpdateGridState() {
        // Nollställ räknare men behåll direction och is_active
        m_state.active_levels = 0;
        m_state.total_grid_lots = 0.0;
        m_state.average_entry_price = 0.0;
        m_state.unrealized_pnl = 0.0;

        // Nollställ levels array
        for (int i = 0; i < MAX_GRID_LEVELS; i++) {
            m_state.levels[i].is_active = false;
            m_state.levels[i].ticket = 0;
            m_state.levels[i].open_price = 0.0;
            m_state.levels[i].lot_size = 0.0;
        }

        if (m_executor == NULL) return;

        // Iterera genom alla positioner
        int count = m_executor.GetPositionCount(m_symbol, m_magic);
        double total_value = 0.0;

        for (int i = 0; i < count && i < MAX_GRID_LEVELS; i++) {
            PositionInfo pos;
            if (m_executor.GetPositionByIndex(i, pos)) {
                if (pos.symbol == m_symbol && pos.magic == m_magic) {
                    // Uppdatera levels array
                    m_state.levels[m_state.active_levels].level_number = m_state.active_levels;
                    m_state.levels[m_state.active_levels].ticket = pos.ticket;
                    m_state.levels[m_state.active_levels].open_price = pos.open_price;
                    m_state.levels[m_state.active_levels].lot_size = pos.lots;
                    m_state.levels[m_state.active_levels].open_time = pos.open_time;
                    m_state.levels[m_state.active_levels].is_active = true;

                    total_value += pos.open_price * pos.lots;
                    m_state.total_grid_lots += pos.lots;
                    m_state.unrealized_pnl += pos.profit;
                    m_state.active_levels++;
                }
            }
        }

        // Beräkna viktat snittpris
        if (m_state.total_grid_lots > 0) {
            m_state.average_entry_price = total_value / m_state.total_grid_lots;
        }

        // OBS: Vi uppdaterar INTE is_active här - det kontrolleras av ActivateGrid/CloseAllLevels
    }

    //+------------------------------------------------------------------+
    //| CalculateLotSize - Beräkna lots för given nivå                    |
    //+------------------------------------------------------------------+
    double CalculateLotSize(int level) {
        // Nivå 0 = base_lot_size
        // Nivå 1 = base * multiplier
        // Nivå N = base * multiplier^N
        double lots = m_config.base_lot_size * MathPow(m_config.lot_multiplier, level);

        // Normalisera till broker-giltigt värde
        if (m_executor != NULL) {
            return m_executor.NormalizeLots(m_symbol, lots);
        }
        return lots;
    }

    //+------------------------------------------------------------------+
    //| CalculateNextLevelPrice - Beräkna pris för nästa nivå             |
    //+------------------------------------------------------------------+
    double CalculateNextLevelPrice() {
        if (m_data == NULL) return 0.0;

        if (m_state.active_levels == 0) {
            // Första nivån = aktuellt pris
            if (m_state.direction == POSITION_TYPE_BUY) {
                return m_data.GetAsk();
            } else {
                return m_data.GetBid();
            }
        }

        // Hitta senaste nivåns pris
        double last_price = m_state.levels[m_state.active_levels - 1].open_price;

        // Konvertera pips till price units
        // För 5-decimal pairs: 1 pip = 0.0001 = point * 10
        double point = m_data.GetPoint();
        double spacing = m_config.spacing_pips * point * 10;

        if (m_state.direction == POSITION_TYPE_BUY) {
            // BUY grid: nästa nivå UNDER senaste (köp billigare)
            return last_price - spacing;
        } else {
            // SELL grid: nästa nivå ÖVER senaste (sälj dyrare)
            return last_price + spacing;
        }
    }

    //+------------------------------------------------------------------+
    //| CanAddLevel - Kontrollera om vi kan lägga till nivå               |
    //+------------------------------------------------------------------+
    bool CanAddLevel(string &reason) {
        // 1. Kolla om grid är aktiv
        if (!m_state.is_active) {
            reason = "Grid not active";
            return false;
        }

        // 2. Kolla RiskEngine
        if (m_risk_engine != NULL) {
            RiskDecision risk = m_risk_engine.Evaluate();
            if (!risk.allow_grid_expansion) {
                reason = risk.block_reason;
                return false;
            }
        }

        // 3. Kolla max levels
        if (m_state.active_levels >= m_config.max_levels) {
            reason = "Max levels reached: " + IntegerToString(m_config.max_levels);
            return false;
        }

        // 4. Kolla max lots
        double next_lots = CalculateLotSize(m_state.active_levels);
        if (m_state.total_grid_lots + next_lots > m_config.max_total_lots) {
            reason = "Would exceed max lots: " + DoubleToString(m_config.max_total_lots, 2);
            return false;
        }

        return true;
    }

public:
    //+------------------------------------------------------------------+
    //| Konstruktor                                                       |
    //+------------------------------------------------------------------+
    CGridEngine(IDataProvider* data, IOrderExecutor* executor,
                ILogger* logger, CPositionManager* pm, CRiskEngine* risk) {
        m_data = data;
        m_executor = executor;
        m_logger = logger;
        m_position_manager = pm;
        m_risk_engine = risk;

        m_symbol = "";
        m_magic = 0;
        m_initialized = false;

        // Standardkonfiguration sätts av GridConfig konstruktor
    }

    //+------------------------------------------------------------------+
    //| Destruktor                                                        |
    //+------------------------------------------------------------------+
    ~CGridEngine() {
        // Inget att städa
    }

    //+------------------------------------------------------------------+
    //| Initialize - Initiera med symbol och magic                        |
    //+------------------------------------------------------------------+
    bool Initialize(string symbol, long magic) {
        if (m_data == NULL || m_executor == NULL) {
            if (m_logger != NULL) {
                m_logger.LogError("GridEngine", "Initialize failed: missing dependencies");
            }
            return false;
        }

        m_symbol = symbol;
        m_magic = magic;
        m_initialized = true;

        if (m_logger != NULL) {
            m_logger.LogInfo("GridEngine", "Initialized with config: " +
                            "spacing=" + DoubleToString(m_config.spacing_pips, 1) + " pips, " +
                            "multiplier=" + DoubleToString(m_config.lot_multiplier, 2) + ", " +
                            "base_lot=" + DoubleToString(m_config.base_lot_size, 2) + ", " +
                            "max_levels=" + IntegerToString(m_config.max_levels));
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
    //| Evaluate - Huvudmetod: evaluera om vi kan/bör agera               |
    //+------------------------------------------------------------------+
    GridDecision Evaluate() {
        GridDecision decision;

        if (!m_initialized) {
            decision.block_reason = "GridEngine not initialized";
            return decision;
        }

        // Uppdatera state
        UpdateGridState();

        // Kolla emergency close
        if (m_risk_engine != NULL) {
            RiskDecision risk = m_risk_engine.Evaluate();
            if (risk.require_emergency_close) {
                decision.should_close_all = true;
                decision.block_reason = risk.block_reason;
                return decision;
            }
        }

        // Kolla om vi kan lägga till nivå
        string reason = "";
        decision.can_add_level = CanAddLevel(reason);
        decision.block_reason = reason;

        if (decision.can_add_level) {
            decision.next_level_price = CalculateNextLevelPrice();
            decision.next_level_lots = CalculateLotSize(m_state.active_levels);
        }

        return decision;
    }

    //+------------------------------------------------------------------+
    //| ActivateGrid - Starta ny grid                                     |
    //+------------------------------------------------------------------+
    bool ActivateGrid(int direction) {
        if (!m_initialized) {
            return false;
        }

        if (m_state.is_active) {
            if (m_logger != NULL) {
                m_logger.LogWarning("GridEngine", "Grid already active");
            }
            return false; // Grid redan aktiv
        }

        // Kolla RiskEngine innan aktivering
        if (m_risk_engine != NULL) {
            RiskDecision risk = m_risk_engine.Evaluate();
            if (!risk.allow_new_entry) {
                if (m_logger != NULL) {
                    m_logger.LogWarning("GridEngine", "Cannot activate grid: " + risk.block_reason);
                }
                return false;
            }
        }

        m_state.direction = direction;
        m_state.is_active = true;

        // Lägg till första nivån
        OrderResult result = AddLevel();

        if (!result.success) {
            m_state.is_active = false;
            if (m_logger != NULL) {
                m_logger.LogError("GridEngine", "Failed to add first level: " + result.error_message);
            }
            return false;
        }

        if (m_logger != NULL) {
            string dir_str = (direction == POSITION_TYPE_BUY) ? "BUY" : "SELL";
            m_logger.LogInfo("GridEngine", "Grid activated: " + dir_str);
        }

        return true;
    }

    //+------------------------------------------------------------------+
    //| AddLevel - Lägg till en nivå                                      |
    //+------------------------------------------------------------------+
    OrderResult AddLevel() {
        OrderResult result;

        if (!m_initialized) {
            result.success = false;
            result.error_message = "GridEngine not initialized";
            return result;
        }

        // Uppdatera state först
        UpdateGridState();

        // Validera
        string reason = "";
        if (!CanAddLevel(reason)) {
            result.success = false;
            result.error_message = reason;
            return result;
        }

        // Beräkna parametrar
        double lots = CalculateLotSize(m_state.active_levels);
        int level = m_state.active_levels;

        // Skicka order
        ENUM_POSITION_TYPE type = (m_state.direction == POSITION_TYPE_BUY)
                                  ? POSITION_TYPE_BUY
                                  : POSITION_TYPE_SELL;

        string comment = "Grid L" + IntegerToString(level);
        result = m_executor.SendMarketOrder(m_symbol, type, lots, 0, 0, comment, m_magic);

        // Logga
        if (m_logger != NULL) {
            if (result.success) {
                m_logger.LogInfo("GridEngine", "Added level " + IntegerToString(level) +
                                " @ " + DoubleToString(result.fill_price, 5) +
                                " lots=" + DoubleToString(lots, 2));
            } else {
                m_logger.LogError("GridEngine", "Failed to add level " + IntegerToString(level) +
                                 ": " + result.error_message);
            }
        }

        // Uppdatera state efter order
        if (result.success) {
            UpdateGridState();
        }

        return result;
    }

    //+------------------------------------------------------------------+
    //| CloseAllLevels - Stäng alla grid-nivåer                           |
    //+------------------------------------------------------------------+
    bool CloseAllLevels() {
        if (!m_initialized) {
            return false;
        }

        UpdateGridState();

        if (m_state.active_levels == 0) {
            m_state.is_active = false;
            return true; // Inget att stänga
        }

        bool all_closed = true;
        int closed_count = 0;

        for (int i = 0; i < MAX_GRID_LEVELS; i++) {
            if (m_state.levels[i].is_active && m_state.levels[i].ticket > 0) {
                bool closed = m_executor.ClosePosition(m_state.levels[i].ticket);
                if (closed) {
                    closed_count++;
                } else {
                    all_closed = false;
                }
            }
        }

        if (all_closed) {
            m_state.is_active = false;
            m_state.active_levels = 0;
            m_state.total_grid_lots = 0.0;

            if (m_logger != NULL) {
                m_logger.LogInfo("GridEngine", "All grid levels closed (" +
                                IntegerToString(closed_count) + " positions)");
            }
        } else {
            if (m_logger != NULL) {
                m_logger.LogWarning("GridEngine", "Some levels failed to close");
            }
        }

        return all_closed;
    }

    //+------------------------------------------------------------------+
    //| GetState - Hämta aktuellt state                                   |
    //+------------------------------------------------------------------+
    GridState GetState() {
        UpdateGridState();
        return m_state;
    }

    //+------------------------------------------------------------------+
    //| GetConfig - Hämta aktuell konfiguration                           |
    //+------------------------------------------------------------------+
    GridConfig GetConfig() {
        return m_config;
    }

    //+------------------------------------------------------------------+
    //| SetConfig - Sätt konfiguration                                    |
    //+------------------------------------------------------------------+
    void SetConfig(GridConfig &config) {
        m_config = config;

        if (m_logger != NULL && m_initialized) {
            m_logger.LogInfo("GridEngine", "Config updated: " +
                            "spacing=" + DoubleToString(m_config.spacing_pips, 1) + " pips, " +
                            "multiplier=" + DoubleToString(m_config.lot_multiplier, 2) + ", " +
                            "base_lot=" + DoubleToString(m_config.base_lot_size, 2));
        }
    }

    //=== PUBLIKA METODER FÖR TEST ===

    //+------------------------------------------------------------------+
    //| CalculateLotSizePublic - Public wrapper för test                  |
    //+------------------------------------------------------------------+
    double CalculateLotSizePublic(int level) {
        return CalculateLotSize(level);
    }

    //+------------------------------------------------------------------+
    //| CalculateNextLevelPricePublic - Public wrapper för test           |
    //+------------------------------------------------------------------+
    double CalculateNextLevelPricePublic() {
        return CalculateNextLevelPrice();
    }

    //+------------------------------------------------------------------+
    //| CanAddLevelPublic - Public wrapper för test                       |
    //+------------------------------------------------------------------+
    bool CanAddLevelPublic(string &reason) {
        return CanAddLevel(reason);
    }

    //+------------------------------------------------------------------+
    //| SetDirection - Sätt riktning för test                             |
    //+------------------------------------------------------------------+
    void SetDirection(int direction) {
        m_state.direction = direction;
    }

    //+------------------------------------------------------------------+
    //| SetActive - Sätt aktiv-status för test                            |
    //+------------------------------------------------------------------+
    void SetActive(bool active) {
        m_state.is_active = active;
    }
};

//+------------------------------------------------------------------+
