//+------------------------------------------------------------------+
//|                                                  RiskEngine.mqh   |
//|                                Copyright 2024, Gridzilla Project  |
//+------------------------------------------------------------------+
#property copyright "Gridzilla Project"
#property version   "1.00"
#property strict

#include "..\interfaces\IDataProvider.mqh"
#include "..\interfaces\IOrderExecutor.mqh"
#include "..\interfaces\ILogger.mqh"
#include "PositionManager.mqh"

//+------------------------------------------------------------------+
//| HardLimits - Icke-förhandlingsbara gränser                        |
//|                                                                   |
//| Dessa gränser kan ALDRIG kringgås av strategi eller AI.           |
//| De existerar för att skydda kontot från katastrofala förluster.   |
//+------------------------------------------------------------------+
struct HardLimits {
    double max_drawdown_pct;        // Max DD innan nya entries blockeras
    double max_total_lots;          // Max total volym
    int    max_grid_levels;         // Max antal grid-nivåer (positioner)
    int    max_grid_age_hours;      // Max timmar en grid får vara öppen
    double emergency_close_dd_pct;  // DD-nivå för tvångsstängning

    //--- Konstruktor med säkra standardvärden
    HardLimits() {
        max_drawdown_pct = 15.0;        // Blockera nya entries vid 15% DD
        max_total_lots = 5.0;           // Max 5 lots totalt
        max_grid_levels = 8;            // Max 8 positioner
        max_grid_age_hours = 72;        // Max 3 dagar
        emergency_close_dd_pct = 20.0;  // Tvångsstäng vid 20% DD
    }
};

//+------------------------------------------------------------------+
//| RiskDecision - Resultat från riskevaluering                       |
//+------------------------------------------------------------------+
struct RiskDecision {
    bool   allow_new_entry;         // Tillåt ny position?
    bool   allow_grid_expansion;    // Tillåt fler grid-nivåer?
    bool   require_emergency_close; // Kräv omedelbar stängning av allt?
    string block_reason;            // Anledning om blockerad
    double current_risk_score;      // 0.0-1.0 riskpoäng (högre = farligare)

    //--- Konstruktor med säkra standardvärden
    RiskDecision() {
        allow_new_entry = false;        // Blockera som default
        allow_grid_expansion = false;   // Blockera som default
        require_emergency_close = false;
        block_reason = "";
        current_risk_score = 0.0;
    }
};

//+------------------------------------------------------------------+
//| CRiskEngine - Hårda gränser som ALDRIG kan kringgås               |
//|                                                                   |
//| Syfte: Skydda kontot från katastrofala förluster.                 |
//| RiskEngine vinner ALLTID över strategi och AI-beslut.             |
//+------------------------------------------------------------------+
class CRiskEngine {
private:
    //--- Beroenden
    IDataProvider*      m_data;
    IOrderExecutor*     m_executor;
    ILogger*            m_logger;
    CPositionManager*   m_position_manager;

    //--- Konfiguration
    HardLimits          m_limits;
    string              m_symbol;
    long                m_magic;
    bool                m_initialized;

    //=== PRIVATA CHECK-METODER ===

    //+------------------------------------------------------------------+
    //| CheckDrawdownLimit - Kontrollera DD-gräns                         |
    //+------------------------------------------------------------------+
    bool CheckDrawdownLimit(PositionManagerState &state, string &reason) {
        if (state.current_drawdown_pct >= m_limits.max_drawdown_pct) {
            reason = StringFormat("Drawdown %.2f%% >= limit %.2f%%",
                                 state.current_drawdown_pct,
                                 m_limits.max_drawdown_pct);
            return false;
        }
        return true;
    }

    //+------------------------------------------------------------------+
    //| CheckMaxLotsLimit - Kontrollera max lots                          |
    //+------------------------------------------------------------------+
    bool CheckMaxLotsLimit(PositionManagerState &state, string &reason) {
        if (state.total_lots >= m_limits.max_total_lots) {
            reason = StringFormat("Total lots %.2f >= limit %.2f",
                                 state.total_lots,
                                 m_limits.max_total_lots);
            return false;
        }
        return true;
    }

    //+------------------------------------------------------------------+
    //| CheckMaxGridLevels - Kontrollera max antal positioner             |
    //+------------------------------------------------------------------+
    bool CheckMaxGridLevels(PositionManagerState &state, string &reason) {
        if (state.position_count >= m_limits.max_grid_levels) {
            reason = StringFormat("Position count %d >= limit %d",
                                 state.position_count,
                                 m_limits.max_grid_levels);
            return false;
        }
        return true;
    }

    //+------------------------------------------------------------------+
    //| CheckPositionAge - Kontrollera max ålder på positioner            |
    //+------------------------------------------------------------------+
    bool CheckPositionAge(PositionManagerState &state, string &reason) {
        if (state.position_age_hours >= m_limits.max_grid_age_hours) {
            reason = StringFormat("Position age %d hours >= limit %d hours",
                                 state.position_age_hours,
                                 m_limits.max_grid_age_hours);
            return false;
        }
        return true;
    }

    //+------------------------------------------------------------------+
    //| CheckEmergencyClose - Kontrollera om nödstängning krävs           |
    //+------------------------------------------------------------------+
    bool CheckEmergencyClose(PositionManagerState &state) {
        return state.current_drawdown_pct >= m_limits.emergency_close_dd_pct;
    }

    //+------------------------------------------------------------------+
    //| CalculateRiskScore - Beräkna aggregerad riskpoäng 0-1             |
    //+------------------------------------------------------------------+
    double CalculateRiskScore(PositionManagerState &state) {
        // Kombinera flera riskfaktorer till en poäng
        double dd_risk = state.current_drawdown_pct / m_limits.emergency_close_dd_pct;
        double lots_risk = state.total_lots / m_limits.max_total_lots;
        double levels_risk = (double)state.position_count / (double)m_limits.max_grid_levels;
        double age_risk = (double)state.position_age_hours / (double)m_limits.max_grid_age_hours;

        // Viktad kombination (DD är viktigast)
        double score = dd_risk * 0.4 + lots_risk * 0.25 + levels_risk * 0.2 + age_risk * 0.15;

        // Clamp till [0, 1]
        return MathMax(0.0, MathMin(1.0, score));
    }

public:
    //+------------------------------------------------------------------+
    //| Konstruktor                                                       |
    //+------------------------------------------------------------------+
    CRiskEngine(IDataProvider* data, IOrderExecutor* executor,
                ILogger* logger, CPositionManager* pos_mgr) {
        m_data = data;
        m_executor = executor;
        m_logger = logger;
        m_position_manager = pos_mgr;

        m_symbol = "";
        m_magic = 0;
        m_initialized = false;

        // Standardlimits sätts av HardLimits konstruktor
    }

    //+------------------------------------------------------------------+
    //| Destruktor                                                        |
    //+------------------------------------------------------------------+
    ~CRiskEngine() {
        // Inget att städa
    }

    //+------------------------------------------------------------------+
    //| Initialize - Initiera med symbol och magic                        |
    //+------------------------------------------------------------------+
    bool Initialize(string symbol, long magic) {
        if (m_data == NULL || m_executor == NULL || m_position_manager == NULL) {
            if (m_logger != NULL) {
                m_logger.LogError("RiskEngine", "Initialize failed: missing dependencies");
            }
            return false;
        }

        if (!m_position_manager.IsInitialized()) {
            if (m_logger != NULL) {
                m_logger.LogError("RiskEngine", "Initialize failed: PositionManager not initialized");
            }
            return false;
        }

        m_symbol = symbol;
        m_magic = magic;
        m_initialized = true;

        if (m_logger != NULL) {
            m_logger.LogInfo("RiskEngine", "Initialized with limits: " +
                            "DD=" + DoubleToString(m_limits.max_drawdown_pct, 1) + "%, " +
                            "Lots=" + DoubleToString(m_limits.max_total_lots, 1) + ", " +
                            "Levels=" + IntegerToString(m_limits.max_grid_levels) + ", " +
                            "Age=" + IntegerToString(m_limits.max_grid_age_hours) + "h, " +
                            "EmergencyDD=" + DoubleToString(m_limits.emergency_close_dd_pct, 1) + "%");
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
    //| Evaluate - Huvudmetod: evaluera risk och returnera beslut         |
    //+------------------------------------------------------------------+
    RiskDecision Evaluate() {
        RiskDecision decision;

        if (!m_initialized) {
            decision.block_reason = "RiskEngine not initialized";
            return decision;
        }

        // Hämta aktuellt state från PositionManager
        PositionManagerState state = m_position_manager.Update();

        // Kontrollera emergency close FÖRST
        if (CheckEmergencyClose(state)) {
            decision.require_emergency_close = true;
            decision.block_reason = StringFormat("EMERGENCY: DD %.2f%% >= %.2f%%",
                                                state.current_drawdown_pct,
                                                m_limits.emergency_close_dd_pct);
            decision.current_risk_score = 1.0;

            if (m_logger != NULL) {
                m_logger.LogError("RiskEngine", decision.block_reason);
            }

            return decision;
        }

        // Kontrollera alla hard limits
        string reason = "";
        bool all_checks_pass = true;

        // DD-limit
        if (!CheckDrawdownLimit(state, reason)) {
            decision.block_reason = reason;
            all_checks_pass = false;
        }

        // Max lots
        if (all_checks_pass && !CheckMaxLotsLimit(state, reason)) {
            decision.block_reason = reason;
            all_checks_pass = false;
        }

        // Max grid levels
        if (all_checks_pass && !CheckMaxGridLevels(state, reason)) {
            decision.block_reason = reason;
            all_checks_pass = false;
        }

        // Position age
        if (all_checks_pass && !CheckPositionAge(state, reason)) {
            decision.block_reason = reason;
            all_checks_pass = false;
        }

        // Sätt beslut
        decision.allow_new_entry = all_checks_pass;
        decision.allow_grid_expansion = all_checks_pass;
        decision.current_risk_score = CalculateRiskScore(state);

        // Logga om blockerad
        if (!all_checks_pass && m_logger != NULL) {
            m_logger.LogWarning("RiskEngine", "Entry blocked: " + decision.block_reason);
        }

        return decision;
    }

    //+------------------------------------------------------------------+
    //| EvaluateWithState - Evaluera med explicit state (för test)        |
    //+------------------------------------------------------------------+
    RiskDecision EvaluateWithState(PositionManagerState &state) {
        RiskDecision decision;

        if (!m_initialized) {
            decision.block_reason = "RiskEngine not initialized";
            return decision;
        }

        // Kontrollera emergency close FÖRST
        if (CheckEmergencyClose(state)) {
            decision.require_emergency_close = true;
            decision.block_reason = StringFormat("EMERGENCY: DD %.2f%% >= %.2f%%",
                                                state.current_drawdown_pct,
                                                m_limits.emergency_close_dd_pct);
            decision.current_risk_score = 1.0;
            return decision;
        }

        // Kontrollera alla hard limits
        string reason = "";
        bool all_checks_pass = true;

        if (!CheckDrawdownLimit(state, reason)) {
            decision.block_reason = reason;
            all_checks_pass = false;
        }

        if (all_checks_pass && !CheckMaxLotsLimit(state, reason)) {
            decision.block_reason = reason;
            all_checks_pass = false;
        }

        if (all_checks_pass && !CheckMaxGridLevels(state, reason)) {
            decision.block_reason = reason;
            all_checks_pass = false;
        }

        if (all_checks_pass && !CheckPositionAge(state, reason)) {
            decision.block_reason = reason;
            all_checks_pass = false;
        }

        decision.allow_new_entry = all_checks_pass;
        decision.allow_grid_expansion = all_checks_pass;
        decision.current_risk_score = CalculateRiskScore(state);

        return decision;
    }

    //+------------------------------------------------------------------+
    //| SetLimits - Sätt nya gränser                                      |
    //+------------------------------------------------------------------+
    void SetLimits(HardLimits &limits) {
        m_limits = limits;

        if (m_logger != NULL && m_initialized) {
            m_logger.LogInfo("RiskEngine", "Limits updated: " +
                            "DD=" + DoubleToString(m_limits.max_drawdown_pct, 1) + "%, " +
                            "Lots=" + DoubleToString(m_limits.max_total_lots, 1) + ", " +
                            "Levels=" + IntegerToString(m_limits.max_grid_levels) + ", " +
                            "Age=" + IntegerToString(m_limits.max_grid_age_hours) + "h");
        }
    }

    //+------------------------------------------------------------------+
    //| GetLimits - Hämta aktuella gränser                                |
    //+------------------------------------------------------------------+
    HardLimits GetLimits() {
        return m_limits;
    }

    //=== GETTERS FÖR TEST ===

    bool CheckDDLimitPublic(PositionManagerState &state, string &reason) {
        return CheckDrawdownLimit(state, reason);
    }

    bool CheckMaxLotsPublic(PositionManagerState &state, string &reason) {
        return CheckMaxLotsLimit(state, reason);
    }

    bool CheckMaxLevelsPublic(PositionManagerState &state, string &reason) {
        return CheckMaxGridLevels(state, reason);
    }

    bool CheckAgePublic(PositionManagerState &state, string &reason) {
        return CheckPositionAge(state, reason);
    }

    bool CheckEmergencyPublic(PositionManagerState &state) {
        return CheckEmergencyClose(state);
    }
};

//+------------------------------------------------------------------+
