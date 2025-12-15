# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Projektöversikt

Gridzilla är en adaptiv, AI-driven grid/martingale Expert Advisor (EA) för MetaTrader 5. Systemet kombinerar deterministisk MQL5-exekveringslogik med ONNX-baserade AI-beslut.

```
EA (MQL5) = Deterministisk exekverings- och riskmotor
ONNX      = Adaptiv besluts-, struktur- och riskpolicy
```

## Build & Test

MQL5-kod kompileras i MetaTrader 5 IDE (MetaEditor). Det finns inget kommandorads-build.

```bash
# Tester körs via Strategy Tester i MT5
# TestRunner.mq5 är test-EA:n som kör alla tester
# Replay-motor körs också inom MT5 Strategy Tester
```

## Arkitektur

### Modulstruktur
```
src/
├── core/           # Kärnmoduler (en modul = ett ansvar)
│   ├── MarketStateManager.mqh   # Analyserar marknadsläge
│   ├── EntryEngine.mqh          # Entry-beslut
│   ├── PositionManager.mqh      # Spårar positioner
│   ├── GridEngine.mqh           # Grid-logik
│   ├── RiskEngine.mqh           # Hard limits
│   ├── SafetyController.mqh     # Nödstängning
│   └── ONNXBridge.mqh           # AI-koppling
├── interfaces/     # Abstraktioner från MT5
│   ├── IDataProvider.mqh        # Marknadsdataåtkomst
│   ├── IOrderExecutor.mqh       # Orderläggning
│   └── ILogger.mqh              # Loggning
└── utils/          # Hjälpfunktioner
```

### Viktiga principer
- **Interfaces först**: Moduler får ALDRIG direkt läsa MT5-data. Allt går via `IDataProvider`, `IOrderExecutor`, `ILogger`
- **Determinism**: All logik måste vara reproducerbar. Samma input = samma output
- **Safety first**: SafetyController vinner ALLTID över strategi. Hard limits kan ALDRIG åsidosättas av AI

## Fas-progression

Projektet följer strikta faser (FAS 0-9). Se `BUILD_PLAN.md` för detaljer.

**REGEL:** Gå ALDRIG vidare till nästa fas utan att föregående är GRÖN.

## Git & GitHub

**Repository:** https://github.com/MrBigDollar/Gridzilla

### Branch-strategi

| Branch | Syfte | Merge till |
|--------|-------|------------|
| `main` | Stabil kod, endast gröna QA-gates | - |
| `develop` | Integration av färdiga faser | `main` |
| `fas-X/beskrivning` | Arbete inom specifik fas | `develop` |

### Arbetsflöde

```bash
# Starta ny fas (exempel: FAS 0)
git checkout develop
git pull origin develop
git checkout -b fas-0/infrastruktur

# Under arbetet - committa ofta med tydliga meddelanden
git add .
git commit -m "FAS 0: Implementera IDataProvider interface"

# När deluppgift är klar - pusha och skapa PR
git push -u origin fas-0/infrastruktur
# Skapa Pull Request till develop via GitHub

# När hel fas är GRÖN - merge develop till main
git checkout main
git merge develop
git push origin main
```

### Regler

1. **Kontrollera ALLTID aktuell branch innan ändringar:** `git branch`
2. **Arbeta ALDRIG direkt i `main`** - all kod går via PR
3. **En fas = en feature branch** - namngivning: `fas-X/kort-beskrivning`
4. **Commit-meddelanden** ska börja med `FAS X:` för spårbarhet
5. **Merge till `main`** endast när QA-gate är GRÖN

### .gitignore

Följande ska ignoreras:
- `*.ex5` (kompilerade filer)
- `logs/` (runtime-loggar)
- `training/data/` (stora träningsdatafiler)
- `.DS_Store`, `Thumbs.db` (OS-filer)

## Kodstandard (MQL5)

```cpp
// Struct-definitioner (CamelCase)
struct MarketState {
    double trend_strength;      // snake_case för members
};

// Funktioner (CamelCase)
double CalculateTrendStrength() { }

// Konstanter (SCREAMING_SNAKE_CASE)
#define MAX_GRID_LEVELS 8

// Klasser (CClassName med C-prefix)
class CModuleName { };
```

### Filhuvud
```cpp
//+------------------------------------------------------------------+
//|                                            ModuleName.mqh         |
//|                                Copyright 2024, Gridzilla Project  |
//+------------------------------------------------------------------+
#property copyright "Gridzilla Project"
#property version   "1.00"
```

## ONNX Tensor-specifikation

### Input (state_input): Shape [1, 12], float32
| Index | Feature | Range |
|-------|---------|-------|
| 0-2 | trend_strength, slope, curvature | [0,1], [-1,1], [-1,1] |
| 3-4 | volatility_level, change | [0,1], [-1,1] |
| 5-7 | mean_reversion, spread_zscore, session_id | [0,1], [-3,3], [0,4] |
| 8-11 | grid_active, open_levels, unrealized_dd, dd_velocity | [0,1], [0,8], [0,1], [-1,1] |

### Output (decision_output): Shape [1, 12], float32
| Index | Feature | Range |
|-------|---------|-------|
| 0-3 | allow_entry, entry_mode, direction, initial_risk | [0,1], [0,4], [-1,1], [0.5,2.0] |
| 4-6 | activate_grid, grid_structure, grid_action | [0,1], [0,5], [0,4] |
| 7-11 | base_spacing, spacing_growth, lot_growth, max_levels, confidence | [20,100], [1.0,1.5], [1.1,2.0], [3,8], [0,1] |

## Hard Limits (Ändra ALDRIG utan diskussion)

```cpp
max_drawdown_pct = 15.0        // Max 15% DD
max_total_lots = 5.0           // Max 5 lots totalt
max_grid_levels = 8            // Max 8 nivåer
max_grid_age_hours = 72        // Max 3 dagar
emergency_close_dd_pct = 20.0  // Nödstängning vid 20% DD
```

## Loggning

JSON-format är obligatoriskt. Varje loggpost ska innehålla:
```json
{"t": "2025-01-14 10:00:00", "module": "GridEngine", "event": "ADD_LEVEL", "inputs": {...}, "outputs": {...}}
```

## Dokumentation

- `PROJEKTPLAN.md` - Komplett teknisk specifikation
- `BUILD_PLAN.md` - Byggfaser och QA-gates med aktuell status
