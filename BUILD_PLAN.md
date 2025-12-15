# GRIDZILLA - Byggplan
## Systematisk Implementation med Faser och QA-gates

**Version:** 1.0
**Skapad:** 2024-12-14
**Status:** Redo för implementation

---

## Grundprinciper (Icke-förhandlingsbara)

Dessa regler bryts ALDRIG under utvecklingen:

| # | Princip | Motivering |
|---|---------|------------|
| 1 | En modul = ett ansvar = ett testpaket | Modularitet och testbarhet |
| 2 | Ingen AI förrän deterministiken är 100% korrekt | AI kan inte fixa buggig logik |
| 3 | Inget live-läge förrän varje modul har syntetiska tester | Skydda kapital |
| 4 | All logik ska kunna köras "offline" i replay | Reproducerbarhet |
| 5 | Varje beslut ska kunna förklaras i efterhand | Debugging och förtroende |

**Regel för progression:** Du går ALDRIG vidare till nästa fas utan att föregående är GRÖN.

---

## Projektstruktur

```
Gridzilla/
├── PROJEKTPLAN.md          # Komplett teknisk specifikation
├── BUILD_PLAN.md           # Denna fil - byggfaser
├── CLAUDE.md               # Instruktioner för AI-assistenten
│
├── src/                    # Källkod
│   ├── core/               # Kärnmoduler
│   │   ├── MarketStateManager.mqh
│   │   ├── EntryEngine.mqh
│   │   ├── PositionManager.mqh
│   │   ├── GridEngine.mqh
│   │   ├── RiskEngine.mqh
│   │   ├── SafetyController.mqh
│   │   └── ONNXBridge.mqh
│   │
│   ├── interfaces/         # Abstraktioner
│   │   ├── IDataProvider.mqh
│   │   ├── IOrderExecutor.mqh
│   │   └── ILogger.mqh
│   │
│   ├── utils/              # Hjälpfunktioner
│   │   ├── MathUtils.mqh
│   │   ├── TimeUtils.mqh
│   │   └── NormalizationUtils.mqh
│   │
│   └── Gridzilla.mq5       # Huvud-EA
│
├── tests/                  # Testramverk
│   ├── unit/               # Enhetstester per modul
│   ├── integration/        # Integrationstester
│   ├── scenario/           # Scenariobaserade tester
│   └── TestRunner.mq5      # Testkörare
│
├── logging/                # Loggningssystem
│   ├── StructuredLogger.mqh
│   └── LogAnalyzer.py
│
├── replay/                 # Replay-motor
│   ├── ReplayEngine.mqh
│   ├── DataRecorder.mqh
│   └── test_data/          # Syntetiska testdata
│
├── training/               # AI-träning (Python, offline)
│   ├── data/               # Träningsdata
│   ├── models/             # Tränade modeller
│   └── scripts/            # Träningsskript
│
└── models/                 # ONNX-modeller
    └── policy_v1.onnx
```

---

## FAS 0: Infrastruktur & Kvalitetssäkring

> **STATUS:** 🔴 Ej påbörjad
> **PRIORITET:** KRITISK - Denna fas avgör om projektet lyckas

### 0.1 Projektstruktur
**Uppgifter:**
- [ ] Skapa mappstruktur enligt ovan
- [ ] Initiera versionskontroll (git)
- [ ] Skapa `.gitignore` för MQL5-projekt

**Acceptanskriterier:**
- Alla mappar existerar
- Git-repo initierat med initial commit

---

### 0.2 Interfaces (Abstraktion från MT5)
**Uppgifter:**
- [ ] `IDataProvider.mqh` - Abstraherar marknadsdataåtkomst
- [ ] `IOrderExecutor.mqh` - Abstraherar orderläggning
- [ ] `ILogger.mqh` - Abstraherar loggning

**Syfte:** Moduler får ALDRIG direkt läsa MT5-data. Allt går via interfaces.

**Acceptanskriterier:**
- Alla interfaces definierade
- Mock-implementationer finns för testning

---

### 0.3 Structured Logging
**Uppgifter:**
- [ ] Implementera `StructuredLogger.mqh`
- [ ] JSON-liknande loggformat
- [ ] Varje loggpost innehåller: `timestamp`, `module`, `decision_type`, `inputs`, `outputs`, `confidence`

**Loggexempel:**
```json
{
  "t": "2025-01-14 10:00:00",
  "module": "GridEngine",
  "event": "ADD_LEVEL",
  "level": 3,
  "price": 1.0842,
  "total_lots": 0.47,
  "reason": "ATR_ADAPTIVE",
  "confidence": 0.68
}
```

**Regel:** Om du inte kan logga det, ska du inte koda det.

**Acceptanskriterier:**
- Logger fungerar
- Output kan parsas av extern analysverktyg
- Alla obligatoriska fält finns

---

### 0.4 Testramverk
**Uppgifter:**
- [ ] Skapa `TestRunner.mq5` - kör alla tester
- [ ] Definiera assertion-funktioner
- [ ] Setup/teardown för tester
- [ ] Rapportgenerering (pass/fail per test)

**Acceptanskriterier:**
- Kan köra tester i Strategy Tester
- Tydlig output av pass/fail
- Minst ett dummy-test passerar

---

### 0.5 Replay-motor (MVP)
**Uppgifter:**
- [ ] `ReplayEngine.mqh` - Spelar upp historisk data
- [ ] `DataRecorder.mqh` - Sparar tick/bar-data för replay
- [ ] Funktioner: pausa, spola, köra om exakt samma scenario

**QA-gate:**
```
✅ Samma input → exakt samma output varje gång
```

**Acceptanskriterier:**
- Kan spela upp sparad data
- Deterministisk - identiska resultat vid upprepad körning

---

### 0.6 Utility-funktioner
**Uppgifter:**
- [ ] `MathUtils.mqh` - Linjär regression, statistiska beräkningar
- [ ] `TimeUtils.mqh` - Session-beräkningar, tidszoner
- [ ] `NormalizationUtils.mqh` - Input/output normalisering för ONNX

**Acceptanskriterier:**
- Alla funktioner har unit-tester
- Dokumenterade in/ut-värden

---

### FAS 0 QA-GATE
```
□ Projektstruktur komplett
□ Interfaces definierade
□ Logging fungerar och är strukturerad
□ Testramverk kör tester
□ Replay-motor ger deterministiska resultat
□ Utility-funktioner testade
```

**GRÖN:** Alla punkter checkade → Fortsätt till FAS 1
**RÖD:** Någon punkt saknas → Fixa innan fortsättning

---

## FAS 1: MarketStateManager

> **STATUS:** 🔴 Ej påbörjad
> **BEROENDE:** FAS 0 måste vara GRÖN

### 1.1 Grundstruktur
**Uppgifter:**
- [ ] Skapa `MarketStateManager.mqh`
- [ ] Definiera `MarketState` struct
- [ ] Implementera via `IDataProvider` interface

---

### 1.2 Features (implementera EN i taget)

**Ordning:**

| # | Feature | Beskrivning | Testtyp |
|---|---------|-------------|---------|
| 1 | `trend_strength` | EMA-alignment + ADX + distance | Unit |
| 2 | `volatility_level` | ATR-baserad, normaliserad | Unit |
| 3 | `spread_zscore` | Spread vs historiskt medel | Unit |
| 4 | `session_id` | Tokyo/London/NY/Overlap | Unit |
| 5 | `trend_slope` | Linjär regression | Unit |
| 6 | `trend_curvature` | Slope-förändring | Unit |
| 7 | `volatility_change` | ATR-förändring | Unit |
| 8 | `mean_reversion_score` | BB + RSI kombinerat | Unit |

---

### 1.3 Testtyp: Deterministiska Unit-tester

**För varje feature:**
- Syntetisk prisserie
- Känd förväntad output

**Exempeltest för `trend_strength`:**
```
Given:
  - Linjärt stigande pris (1.0800 → 1.0900 över 20 bars)
  - Låg ATR (10 pips)
Expect:
  - trend_strength ≈ 0.8-1.0
  - Konsistent vid replay
```

---

### 1.4 MarketState får ENDAST:
- Läsa data (via interface)
- Returnera state
- INGA tradingbeslut här

---

### FAS 1 QA-GATE
```
□ Alla 8 features implementerade
□ Varje feature har minst 3 unit-tester
□ Syntetiska tester passerar
□ State är stabil och reproducerbar vid replay
□ Inga tradingbeslut i denna modul
```

---

## FAS 2: EntryEngine (UTAN Grid)

> **STATUS:** 🔴 Ej påbörjad
> **BEROENDE:** FAS 1 måste vara GRÖN

### 2.1 Börja med EXAKT 1 entry mode

**Rekommenderat:** `TREND_PULLBACK`

**Implementera:**
- [ ] Entry-logik (regeln)
- [ ] Stop Loss (ATR-baserad)
- [ ] Take Profit (konservativ)
- [ ] Position sizing (risk-baserad)

---

### 2.2 Entry Filters (alltid aktiva)
```cpp
struct EntryFilters {
    double max_spread_pips = 2.0;
    double min_volatility_atr = 5.0;
    double max_volatility_atr = 50.0;
    int    max_concurrent_entries = 1;
    bool   weekend_lockout = true;
};
```

Dessa filter kan ALDRIG åsidosättas.

---

### 2.3 Testtyper
- [ ] Replay-test på trendande marknader
- [ ] Edge-case-test: hög spread
- [ ] Edge-case-test: låg volatilitet
- [ ] Edge-case-test: news-liknande spikes

---

### 2.4 KPI:er att mäta
| KPI | Mål |
|-----|-----|
| Winrate första trade | ≥50% |
| Avg R:R | ≥1.0 |
| Time in market | Dokumenterad |

---

### FAS 2 QA-GATE
```
□ TREND_PULLBACK implementerad
□ SL/TP fungerar korrekt
□ Alla filters blockerar korrekt
□ ≥50% vinnande första trades i kontrollerade tester
□ Ingen grid-logik finns ännu
```

---

## FAS 3: PositionManager & RiskEngine

> **STATUS:** 🔴 Ej påbörjad
> **BEROENDE:** FAS 2 måste vara GRÖN

### 3.1 PositionManager
**Uppgifter:**
- [ ] Spåra `average_entry_price`
- [ ] Beräkna `breakeven_price`
- [ ] Tracka `current_drawdown_pct`
- [ ] Beräkna `max_adverse_excursion` (MAE)
- [ ] Implementera `dd_velocity` (drawdown-hastighet)

**Tester:**
- [ ] Handräknade scenarier
- [ ] Jämför kod vs Excel-beräkningar

---

### 3.2 RiskEngine (Hard Limits först)
```cpp
struct HardLimits {
    double max_drawdown_pct = 15.0;
    double max_total_lots = 5.0;
    int    max_grid_levels = 8;
    int    max_grid_age_hours = 72;
    double emergency_close_dd_pct = 20.0;
};
```

**Tester:**
- [ ] Max DD → block
- [ ] Emergency close
- [ ] Max lots

---

### FAS 3 QA-GATE
```
□ PositionManager beräknar korrekt (verifierat mot handräknade exempel)
□ RiskEngine blockerar vid alla hard limits
□ Riskregler kan ALDRIG kringgås - ens av buggar
□ Emergency close fungerar
```

---

## FAS 4: GridEngine (MINIMALT)

> **STATUS:** 🔴 Ej påbörjad
> **BEROENDE:** FAS 3 måste vara GRÖN

### 4.1 Endast 1 grid-typ: Horizontal Grid

**INGEN AI. INGA transitions. INGEN dynamik.**

**Implementera:**
- [ ] Fast spacing (t.ex. 50 pips)
- [ ] Fast lot growth (t.ex. 1.5x)
- [ ] Respektera max_levels
- [ ] Respektera max_lots
- [ ] Korrekt stängning av alla nivåer

---

### 4.2 Testscenarier
- [ ] Monoton trend mot dig (worst case)
- [ ] Range som löser sig (best case)
- [ ] Gap/spike
- [ ] Max levels nås

---

### FAS 4 QA-GATE
```
□ Horizontal Grid fungerar korrekt
□ Max nivåer respekteras
□ Max lots respekteras
□ Grid stänger korrekt (alla positioner)
□ Grid kan INTE spränga kontot ens i värsta testfall
□ INGEN AI-logik i denna fas
```

---

## FAS 5: SafetyController

> **STATUS:** 🔴 Ej påbörjad
> **BEROENDE:** FAS 4 måste vara GRÖN

### 5.1 Katastrofdetektering
**Implementera:**
- [ ] Volatility spike detection
- [ ] Spread explosion detection
- [ ] Equity cliff detection (snabb förlust)
- [ ] Connection health check

### 5.2 Safety Actions
```cpp
enum SafetyAction {
    SAFETY_OK,
    SAFETY_PAUSE_NEW_ENTRIES,
    SAFETY_FREEZE_GRID,
    SAFETY_CLOSE_ALL
};
```

### 5.3 Testscenarier (extrema fall)
- [ ] Volatility spike (ATR ratio > 2.5)
- [ ] Spread explosion (z-score > 3)
- [ ] 5% equity loss inom 10 bars
- [ ] Missade ticks > 30 sekunder

---

### FAS 5 QA-GATE
```
□ Alla safety checks implementerade
□ Safety vinner ALLTID över strategi
□ Emergency close fungerar under alla scenarion
□ Loggning av alla safety-events
```

---

## FAS 6: ONNX Integration (PASSIV)

> **STATUS:** 🔴 Ej påbörjad
> **BEROENDE:** FAS 5 måste vara GRÖN

### 6.1 ONNX som "Advisor"

**Första steget - ONNX påverkar INGENTING:**
- [ ] ONNX laddas
- [ ] Shapes verifieras
- [ ] Normalisering implementerad
- [ ] Inference körs
- [ ] Output loggas
- [ ] **MEN IGNORERAS**

### 6.2 Dummy-modell
- [ ] Skapa en enkel dummy ONNX-modell
- [ ] Verifiera att MQL5 kan ladda och köra inference
- [ ] Output är rimlig (inga NaN, inom expected ranges)

---

### FAS 6 QA-GATE
```
□ ONNX laddar utan fel
□ Input shapes korrekt (1, 12)
□ Output shapes korrekt (1, 12)
□ Normalisering fungerar
□ Inference returnerar rimliga värden
□ ONNX kan INTE krascha EA
□ Alla beslut fattas fortfarande av regelbaserad logik
```

---

## FAS 7: ONNX Aktiv (Låg påverkan)

> **STATUS:** 🔴 Ej påbörjad
> **BEROENDE:** FAS 6 måste vara GRÖN

### 7.1 Aktivera ONNX-beslut gradvis

**Släpp på (med clamping):**
- [ ] `allow_entry` (ONNX föreslår, EA validerar)
- [ ] `entry_mode` (inom tillåtna modes)
- [ ] `confidence` (påverkar aggressivitet)

**Alla filter kvar:**
- Hard limits respekteras
- Safety controller aktiv
- Alla ONNX-värden clampas

---

### 7.2 Confidence-driven adaptation
```cpp
// Låg confidence → konservativt beteende
double spacing_scaled = ScaleSpacingByConfidence(base_spacing, confidence);
double lot_growth_scaled = ScaleLotGrowthByConfidence(lot_growth, confidence);
```

---

### FAS 7 QA-GATE
```
□ ONNX entry-beslut aktivt (med validering)
□ Confidence-skalning fungerar
□ Alla hard limits fortfarande respekteras
□ Samma marknad + olika ONNX outputs → system stabilt
□ Fallback till regelbaserad om ONNX misslyckas
```

---

## FAS 8: Grid Transitions & Hysteresis

> **STATUS:** 🔴 Ej påbörjad
> **BEROENDE:** FAS 7 måste vara GRÖN

### 8.1 Lägg till fler grid-strukturer
- [ ] ATR-Adaptive Grid
- [ ] (Övriga kan läggas till senare)

### 8.2 Transition-logik
- [ ] 1 transition-typ i taget
- [ ] Lång cooldown (≥4 bars mellan transitions)
- [ ] Reverse cooldown (≥12 bars)
- [ ] State stability check (3 bars)

### 8.3 Hysteresis Gates
```cpp
bool IsTransitionAllowed(...) {
    if (confidence < 0.50) return false;
    if (bars_since_last < 4) return false;
    if (is_reverse && bars_since_last < 12) return false;
    if (!IsMarketStateStable()) return false;
    return true;
}
```

---

### FAS 8 QA-GATE
```
□ Transition mellan 2 strukturer fungerar
□ Hysteresis förhindrar flapping
□ Inga snabba strukturbyten i stökiga regimer
□ Befintliga positioner bevaras vid transition
```

---

## FAS 9: Systemtester & Validering

> **STATUS:** 🔴 Ej påbörjad
> **BEROENDE:** FAS 8 måste vara GRÖN

### 9.1 Scenariobibliotek
Bygg ett bibliotek av extrema scenarier:
- [ ] Flash crash (2-3% drop på sekunder)
- [ ] Covid-liknande trend (stark enriktad rörelse i dagar)
- [ ] Range i 3 dagar (ingen tydlig riktning)
- [ ] News-spike + reversal

### 9.2 Frågor varje test ska svara
1. Varför tog systemet denna trade?
2. Varför aktiverades grid?
3. Varför dog det / överlevde?

### 9.3 Dokumentation
- [ ] Alla testresultat dokumenterade
- [ ] Kända begränsningar listade
- [ ] Edge cases identifierade

---

### FAS 9 QA-GATE (FINAL)
```
□ Alla extremscenarier testade
□ System överlever alla testade katastrofer
□ Alla beslut kan förklaras i efterhand (via loggar)
□ Dokumentation komplett
□ Redo för demo/forward-test
```

---

## Sammanfattning: Progression

```
FAS 0  ──────►  FAS 1  ──────►  FAS 2  ──────►  FAS 3
Infra           Market         Entry           Position
& Test          State          Engine          & Risk
   │               │              │               │
   ▼               ▼              ▼               ▼
  QA             QA             QA             QA
 GATE           GATE           GATE           GATE
                                                 │
┌────────────────────────────────────────────────┘
│
▼
FAS 4  ──────►  FAS 5  ──────►  FAS 6  ──────►  FAS 7
Grid            Safety         ONNX            ONNX
(Minimal)       Controller     Passiv          Aktiv
   │               │              │               │
   ▼               ▼              ▼               ▼
  QA             QA             QA             QA
 GATE           GATE           GATE           GATE
                                                 │
┌────────────────────────────────────────────────┘
│
▼
FAS 8  ──────►  FAS 9
Transitions     System
& Hysteresis    Validation
   │               │
   ▼               ▼
  QA             FINAL
 GATE            QA
```

---

## Changelog

| Datum | Version | Ändringar |
|-------|---------|-----------|
| 2024-12-14 | 1.0 | Initial version |
