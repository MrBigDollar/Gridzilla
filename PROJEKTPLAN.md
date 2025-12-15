# GRIDZILLA – Adaptive AI-Driven Grid Martingale EA
## Komplett Projektplan & Teknisk Specifikation

```
   ██████╗ ██████╗ ██╗██████╗ ███████╗██╗██╗     ██╗      █████╗
  ██╔════╝ ██╔══██╗██║██╔══██╗╚══███╔╝██║██║     ██║     ██╔══██╗
  ██║  ███╗██████╔╝██║██║  ██║  ███╔╝ ██║██║     ██║     ███████║
  ██║   ██║██╔══██╗██║██║  ██║ ███╔╝  ██║██║     ██║     ██╔══██║
  ╚██████╔╝██║  ██║██║██████╔╝███████╗██║███████╗███████╗██║  ██║
   ╚═════╝ ╚═╝  ╚═╝╚═╝╚═════╝ ╚══════╝╚═╝╚══════╝╚══════╝╚═╝  ╚═╝
```

**Version:** 2.0
**Datum:** 2024-12-13
**Status:** Planering

---

# Del 1: Vision & Grundprinciper

## 1.1 Vision

Att bygga en långsiktigt överlevnadsbar, adaptiv trading-EA som:
- Utnyttjar grid/martingale för dess statistiska edge
- Kraftigt reducerar tail risk genom AI-styrd struktur och timing
- Kör grid selektivt, inte kontinuerligt
- Inte kräver externa beroenden hos slutanvändaren
- Använder ONNX som utbytbar AI-hjärna

## 1.2 Grundprincip

```
GRIDZILLA = Deterministisk exekverings- och riskmotor
ONNX = Adaptiv besluts-, struktur- och riskpolicy
```

## 1.3 Designaxiom (icke-förhandlingsbara)

| # | Axiom | Motivering |
|---|-------|-----------|
| 1 | Ingen Python-installation hos användare | Enkelhet, inga beroenden |
| 2 | Ingen DLL eller extern exe | Säkerhet, portabilitet |
| 3 | All exekverbar logik körs i MQL5 | Determinism, testbarhet |
| 4 | ONNX är stateless | Reproducerbarhet, enkel debugging |
| 5 | Risk- och säkerhetslogik får aldrig ligga i AI | Garanti mot AI-fel |
| 6 | Grid är fallback, inte primär strategi | Minimera exponering |
| 7 | **Confidence styr aggressivitet** | AI-osäkerhet → konservativt beteende |
| 8 | **Hysteresis på alla transitions** | Förhindra flapping i stökiga regimer |

---

# Del 2: Systemarkitektur

## 2.1 Övergripande arkitektur

```
┌─────────────────────────────────────────────────────────────┐
│                        MT5 Terminal                          │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────┐    │
│  │                    EA (MQL5)                         │    │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │    │
│  │  │ MarketState │  │   Entry     │  │  Position   │  │    │
│  │  │  Manager    │  │   Engine    │  │  Manager    │  │    │
│  │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  │    │
│  │         │                │                │         │    │
│  │         └────────────────┼────────────────┘         │    │
│  │                          ▼                          │    │
│  │  ┌─────────────────────────────────────────────┐   │    │
│  │  │              State Aggregator                │   │    │
│  │  └──────────────────────┬──────────────────────┘   │    │
│  │                         │                          │    │
│  │                         ▼                          │    │
│  │  ┌─────────────────────────────────────────────┐   │    │
│  │  │            ONNX Runtime Bridge               │   │    │
│  │  └──────────────────────┬──────────────────────┘   │    │
│  │                         │                          │    │
│  │                         ▼                          │    │
│  │  ┌─────────────────────────────────────────────┐   │    │
│  │  │              Decision Parser                 │   │    │
│  │  └──────────────────────┬──────────────────────┘   │    │
│  │                         │                          │    │
│  │         ┌───────────────┼───────────────┐         │    │
│  │         ▼               ▼               ▼         │    │
│  │  ┌───────────┐   ┌───────────┐   ┌───────────┐   │    │
│  │  │   Grid    │   │   Risk    │   │  Safety   │   │    │
│  │  │  Engine   │   │  Engine   │   │Controller │   │    │
│  │  └─────┬─────┘   └─────┬─────┘   └─────┬─────┘   │    │
│  │        │               │               │         │    │
│  │        └───────────────┼───────────────┘         │    │
│  │                        ▼                          │    │
│  │  ┌─────────────────────────────────────────────┐   │    │
│  │  │             Order Executor                   │   │    │
│  │  └─────────────────────────────────────────────┘   │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐    │
│  │                  ONNX Model File                     │    │
│  │                 (policy_v1.onnx)                     │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

## 2.2 Ansvarsuppdelning

### EA (MQL5) ansvarar för:
- Insamling och aggregering av marknadsdata
- Kontostate och positionshantering
- Entry-exekvering och orderläggning
- Grid-mekanik och nivåhantering
- Hård riskbegränsning (aldrig förhandlingsbart)
- Katastrofskydd
- ONNX runtime och validering av outputs
- Loggning och diagnostik

### ONNX (AI-policy) ansvarar för:
- Beslut om entry ska tillåtas
- Val av entry-typ och riktning
- Beslut om grid ska aktiveras
- Val av grid-struktur
- Grid-transitions mellan strukturer
- Aggressivitetsnivå (spacing, lot growth)
- Beslut om grid ska stängas

---

# Del 3: EA-moduler – Detaljerad Specifikation

## 3.1 MarketStateManager

### Syfte
Samla och aggregera all marknadsinformation som behövs för beslut. Denna modul är "ögonen" för systemet.

### Multi-Timeframe Analys

```
Timeframes som används:
- M5  : Kortsiktig momentum och noise
- M15 : Entry-timing
- H1  : Huvudtrend
- H4  : Överordnad struktur
- D1  : Long-term bias
```

### Beräkningar och Formler

#### 3.1.1 Trend Strength (0.0 - 1.0)

Kombinerar flera indikatorer för att mäta hur stark trenden är:

```cpp
// Pseudokod för trend_strength beräkning
double CalculateTrendStrength() {
    // Komponent 1: EMA alignment (0-1)
    double ema_fast = iMA(symbol, H1, 20, 0, MODE_EMA, PRICE_CLOSE);
    double ema_mid  = iMA(symbol, H1, 50, 0, MODE_EMA, PRICE_CLOSE);
    double ema_slow = iMA(symbol, H1, 200, 0, MODE_EMA, PRICE_CLOSE);

    // Perfekt alignment = 1.0, ingen alignment = 0.0
    double ema_alignment = 0.0;
    if (ema_fast > ema_mid && ema_mid > ema_slow) ema_alignment = 1.0;  // Bullish
    if (ema_fast < ema_mid && ema_mid < ema_slow) ema_alignment = 1.0;  // Bearish

    // Komponent 2: ADX styrka (normaliserad)
    double adx = iADX(symbol, H1, 14, PRICE_CLOSE, MODE_MAIN);
    double adx_normalized = MathMin(adx / 50.0, 1.0);  // ADX > 50 = maximal trend

    // Komponent 3: Price vs EMA200 distance
    double price = SymbolInfoDouble(symbol, SYMBOL_BID);
    double distance_pct = MathAbs(price - ema_slow) / ema_slow * 100;
    double distance_score = MathMin(distance_pct / 2.0, 1.0);  // 2% = max score

    // Viktat genomsnitt
    return ema_alignment * 0.4 + adx_normalized * 0.4 + distance_score * 0.2;
}
```

**Exempel i praktiken:**
- EUR/USD med EMA20=1.0850, EMA50=1.0820, EMA200=1.0750, ADX=35
- EMA alignment: 1.0 (perfekt bullish alignment)
- ADX normalized: 35/50 = 0.70
- Distance: (1.0850-1.0750)/1.0750 = 0.93%, score = 0.465
- **Trend strength = 0.4×1.0 + 0.4×0.70 + 0.2×0.465 = 0.773**

#### 3.1.2 Trend Slope (Lutning)

Mäter hur snabbt trenden rör sig, normaliserad till daglig rörelse:

```cpp
double CalculateTrendSlope() {
    // Använd linjär regression över senaste 20 H1-bars
    double prices[];
    ArrayResize(prices, 20);

    for (int i = 0; i < 20; i++) {
        prices[i] = iClose(symbol, PERIOD_H1, i);
    }

    // Beräkna lutning via least squares
    double slope = LinearRegressionSlope(prices, 20);

    // Normalisera till ATR-enheter per timme
    double atr = iATR(symbol, PERIOD_H1, 14, 0);
    double normalized_slope = slope / atr;

    // Begränsa till [-1, 1]
    return MathMax(-1.0, MathMin(1.0, normalized_slope));
}
```

**Exempel:**
- Om priset rör sig +0.0015 per timme och ATR(H1) = 0.0020
- Slope = 0.0015 / 0.0020 = 0.75
- Tolkning: Priset rör sig uppåt med 75% av "normal" timvolatilitet

#### 3.1.3 Trend Curvature (Krökning)

Detekterar om trenden accelererar, decelererar, eller vänder:

```cpp
double CalculateTrendCurvature() {
    // Jämför slope nu vs slope för 10 bars sedan
    double current_slope = CalculateSlopeAtBar(0);
    double past_slope = CalculateSlopeAtBar(10);

    double curvature = current_slope - past_slope;

    // Normalisera
    double atr = iATR(symbol, PERIOD_H1, 14, 0);
    return MathMax(-1.0, MathMin(1.0, curvature / (atr * 0.1)));
}
```

**Tolkning:**
- Curvature > 0.3: Trenden accelererar (starkare momentum)
- Curvature ≈ 0: Stabil trend
- Curvature < -0.3: Trenden bromsar in (möjlig vändning)

#### 3.1.4 Volatility Level

ATR-baserad volatilitet normaliserad mot historiskt genomsnitt:

```cpp
double CalculateVolatilityLevel() {
    double current_atr = iATR(symbol, PERIOD_H1, 14, 0);
    double avg_atr = iATR(symbol, PERIOD_D1, 14, 0) / 24.0;  // Daglig ATR / 24 timmar

    // Ratio: 1.0 = normal, 2.0 = dubbel volatilitet
    double ratio = current_atr / avg_atr;

    // Normalisera till 0-1 skala där 0.5 = normal
    // ratio 0.5 -> 0.25, ratio 1.0 -> 0.5, ratio 2.0 -> 0.75
    return MathMax(0.0, MathMin(1.0, ratio / 2.5));
}
```

**Exempel:**
- Normal ATR(H1) = 15 pips
- Current ATR(H1) = 25 pips
- Ratio = 25/15 = 1.67
- Volatility level = 1.67/2.5 = 0.67 (förhöjd volatilitet)

#### 3.1.5 Volatility Change

Hur snabbt volatiliteten förändras:

```cpp
double CalculateVolatilityChange() {
    double atr_now = iATR(symbol, PERIOD_H1, 14, 0);
    double atr_4h_ago = iATR(symbol, PERIOD_H1, 14, 4);

    double change = (atr_now - atr_4h_ago) / atr_4h_ago;

    // Normalisera: +50% ökning = 1.0, -50% minskning = -1.0
    return MathMax(-1.0, MathMin(1.0, change * 2.0));
}
```

**Varför detta är viktigt:**
- Snabbt ökande volatilitet = ofta början på stor rörelse (farligt för grid)
- Sjunkande volatilitet = konsolidering (bra för range-grid)

#### 3.1.6 Mean Reversion Score

Sannolikhet för att priset ska återvända till medelvärde:

```cpp
double CalculateMeanReversionScore() {
    double price = SymbolInfoDouble(symbol, SYMBOL_BID);

    // Bollinger Bands
    double bb_middle = iBands(symbol, PERIOD_H1, 20, 2.0, 0, PRICE_CLOSE, MODE_MAIN, 0);
    double bb_upper = iBands(symbol, PERIOD_H1, 20, 2.0, 0, PRICE_CLOSE, MODE_UPPER, 0);
    double bb_lower = iBands(symbol, PERIOD_H1, 20, 2.0, 0, PRICE_CLOSE, MODE_LOWER, 0);

    // RSI
    double rsi = iRSI(symbol, PERIOD_H1, 14, PRICE_CLOSE, 0);

    // Position inom BB (-1 = vid lower, 0 = mitten, +1 = vid upper)
    double bb_position = (price - bb_middle) / (bb_upper - bb_middle);

    // RSI score (-1 = oversold, +1 = overbought)
    double rsi_score = (rsi - 50) / 50;

    // Kombinerad score
    // Hög positiv = starkt överköpt, hög sannolikhet för nedgång
    // Hög negativ = starkt översålt, hög sannolikhet för uppgång
    double combined = (bb_position * 0.6 + rsi_score * 0.4);

    // Returnera absolut score (0 = ingen MR-signal, 1 = stark MR-signal)
    return MathAbs(combined);
}
```

**Exempel:**
- Pris vid övre BB, RSI = 75
- BB position ≈ 1.0
- RSI score = (75-50)/50 = 0.5
- Combined = 0.6×1.0 + 0.4×0.5 = 0.8
- **Mean reversion score = 0.8 (stark signal för pullback)**

#### 3.1.7 Spread Z-Score

Hur ovanlig är nuvarande spread jämfört med normalt:

```cpp
double CalculateSpreadZScore() {
    double current_spread = SymbolInfoInteger(symbol, SYMBOL_SPREAD) * SymbolInfoDouble(symbol, SYMBOL_POINT);

    // Historiskt genomsnitt och stddev (från ringbuffer)
    double avg_spread = spread_buffer.Average();
    double std_spread = spread_buffer.StdDev();

    if (std_spread == 0) return 0;

    return (current_spread - avg_spread) / std_spread;
}
```

**Tolkning:**
- Z-score < 1: Normal spread
- Z-score 1-2: Förhöjd spread (var försiktig)
- Z-score > 2: Anomali (blockera trading)

#### 3.1.8 Session Identification

```cpp
enum SESSION_ID {
    SESSION_ASIAN    = 0,  // Tokyo: 00:00-09:00 UTC
    SESSION_EUROPEAN = 1,  // London: 07:00-16:00 UTC
    SESSION_AMERICAN = 2,  // New York: 13:00-22:00 UTC
    SESSION_OVERLAP_EU_US = 3,  // 13:00-16:00 UTC (högst volatilitet)
    SESSION_OFF_HOURS = 4   // Låg likviditet
};

int GetCurrentSession() {
    datetime server_time = TimeCurrent();
    MqlDateTime dt;
    TimeToStruct(server_time, dt);
    int hour = dt.hour;

    // Overlap har högst prioritet
    if (hour >= 13 && hour < 16) return SESSION_OVERLAP_EU_US;
    if (hour >= 7 && hour < 16) return SESSION_EUROPEAN;
    if (hour >= 13 && hour < 22) return SESSION_AMERICAN;
    if (hour >= 0 && hour < 9) return SESSION_ASIAN;
    return SESSION_OFF_HOURS;
}
```

### Komplett State Vector Output

```cpp
struct MarketState {
    double trend_strength;      // 0.0 - 1.0
    double trend_slope;         // -1.0 - 1.0
    double trend_curvature;     // -1.0 - 1.0
    double volatility_level;    // 0.0 - 1.0
    double volatility_change;   // -1.0 - 1.0
    double mean_reversion_score; // 0.0 - 1.0
    double spread_zscore;       // typically -3.0 - 3.0
    int    session_id;          // 0-4
};
```

---

## 3.2 EntryEngine (Selektiv Entry)

### Filosofi

Klassisk grid/martingale börjar med en trade och hoppas på det bästa. Vår approach är annorlunda:

> **Målet är ≥50% vinnande första trades. Grid är backup, inte plan A.**

### Entry Modes

| ID | Mode | Beskrivning | Bäst i |
|----|------|-------------|--------|
| 0 | NO_ENTRY | Ingen trade tillåts | Hög osäkerhet |
| 1 | TREND_PULLBACK | Entry i trendriktning efter pullback | Stark trend |
| 2 | RANGE_FADE | Sälj toppen, köp botten av range | Sidledes marknad |
| 3 | BREAKOUT_RETEST | Entry efter breakout och retest | Konsolidering → trend |
| 4 | MEAN_REVERSION_SCALP | Snabb trade mot extrem | Överdriven rörelse |

### Detaljerad beskrivning av varje Entry Mode

#### Mode 1: TREND_PULLBACK

**Koncept:** I en stark trend, vänta på en tillfällig dip (i upptrend) eller rally (i nedtrend) innan entry.

```
Stark upptrend i EUR/USD:
Pris: 1.0900
EMA20: 1.0880
EMA50: 1.0850

        1.0920 ─┐
                │╲
        1.0900 ─┤ ╲ ← Pris faller tillbaka
                │  ╲
        1.0880 ─┤   ● ← ENTRY HÄR (vid EMA20)
                │  ╱
        1.0860 ─┤ ╱
                │╱
        1.0850 ─┘ ← EMA50 (stöd)
```

**Entry-kriterier:**
- Trend strength > 0.6
- Pris har pullback minst 30% av senaste swing
- RSI har fallit från >60 till 45-55 zonen
- Priset visar tecken på att vända (bullish candle)

**Varför det fungerar:**
- Handlar med trenden, inte mot
- Bättre entry-pris än att jaga
- Definierad stop loss (under EMA50)

#### Mode 2: RANGE_FADE

**Koncept:** I en sidledes marknad, sälj vid range-toppen och köp vid range-botten.

```
Range i GBP/USD:
                    Resistance: 1.2750
        1.2760 ─┐   ═══════════════════
                │     ●SELL        ●SELL
        1.2720 ─┤    ╱ ╲          ╱ ╲
                │   ╱   ╲        ╱   ╲
        1.2680 ─┤  ╱     ╲      ╱     ╲
                │ ╱       ╲    ╱       ╲
        1.2650 ─┤●BUY      ╲  ●BUY
                │           ╲╱
        1.2620 ─┘═══════════════════════
                    Support: 1.2620
```

**Entry-kriterier:**
- Trend strength < 0.3 (ingen tydlig trend)
- Pris inom definierad range (minst 3 touches)
- Mean reversion score > 0.6
- ATR sjunkande eller stabil

**Take Profit:** Mitt i rangen eller motsatt sida
**Stop Loss:** Strax utanför range (breakout = fel)

#### Mode 3: BREAKOUT_RETEST

**Koncept:** Efter ett breakout, vänta på att priset testar den brutna nivån innan entry.

```
Breakout och retest:

        1.3050 ─┐          ╱╲
                │         ╱  ╲ ← Fortsatt uppgång
        1.3020 ─┤        ╱
                │       ╱
        1.3000 ─┤══════●════════ ← ENTRY vid retest
                │     ╱│ Gammal resistance = ny support
        1.2980 ─┤    ╱ │
                │   ╱  │
        1.2960 ─┤──╱───┼────────
                │ ╱    │ Konsolidering före breakout
        1.2940 ─┤╱     │
                └──────┴────────
```

**Entry-kriterier:**
- Tydligt breakout (close ovanför/under nivå)
- Pris återvänder till bruten nivå
- Nivån håller (bekräftelse)
- Volym minskar under retest (normalt)

**Varför det fungerar:**
- Bekräftar att breakout är "äkta"
- Bättre risk/reward än att jaga breakout
- Tydlig invalidering om nivån inte håller

#### Mode 4: MEAN_REVERSION_SCALP

**Koncept:** Snabb trade mot en överdriven kortvarig rörelse.

```
Mean reversion scalp:

        1.2850 ─┐
                │    ╲
        1.2830 ─┤     ╲ ← Överdriven spike ner
                │      ╲  (RSI < 20, utanför BB)
        1.2810 ─┤       ●
                │       │╲
        1.2800 ─┤       │ ╲ ← ENTRY (köp)
                │      ╱│  Target: 1.2820
        1.2790 ─┤     ╱ │
                │    ╱  │ ← Stop: 1.2780
        1.2780 ─┤───────┴─────────
```

**Entry-kriterier:**
- Pris > 2 standardavvikelser från MA
- RSI < 25 eller > 75
- Snabb rörelse (ej gradvis drift)
- Spike, inte trend-start

**Risk:** Hög – endast med tight stop och snabb TP

### Entry Filter (alltid aktiva i EA)

Dessa filter kan ALDRIG åsidosättas av AI:

```cpp
struct EntryFilters {
    double max_spread_pips = 2.0;           // Blockera vid hög spread
    double min_volatility_atr = 5.0;        // Pips - för låg = ingen edge
    double max_volatility_atr = 50.0;       // Pips - för hög = för riskabelt
    int    news_lockout_minutes = 30;       // Före/efter high-impact news
    int    max_concurrent_entries = 1;      // Endast en position åt gången (innan grid)
    double min_balance_usd = 1000;          // Säkerhetsmarginal
    bool   weekend_lockout = true;          // Ingen trading fredag 21:00 - söndag 22:00
};

bool PassesAllFilters(EntryFilters& filters) {
    // Spread check
    double spread = SymbolInfoInteger(symbol, SYMBOL_SPREAD) * point;
    if (spread > filters.max_spread_pips * 10 * point) return false;

    // Volatility check
    double atr_pips = iATR(symbol, PERIOD_H1, 14, 0) / point / 10;
    if (atr_pips < filters.min_volatility_atr) return false;
    if (atr_pips > filters.max_volatility_atr) return false;

    // News check (kräver extern kalender eller MQL5 calendar)
    if (IsHighImpactNewsWithin(filters.news_lockout_minutes)) return false;

    // Concurrent positions
    if (CountOpenPositions() >= filters.max_concurrent_entries) return false;

    // Balance check
    if (AccountInfoDouble(ACCOUNT_BALANCE) < filters.min_balance_usd) return false;

    // Weekend check
    if (filters.weekend_lockout && IsWeekend()) return false;

    return true;
}
```

### Entry Workflow (komplett flöde)

```
1. Varje tick/bar:
   ├── MarketStateManager uppdaterar state
   ├── State skickas till ONNX
   └── ONNX returnerar: {allow_entry, entry_mode, direction, confidence}

2. Om allow_entry == true:
   ├── EA kontrollerar ALLA filter
   ├── Om filter passerar:
   │   ├── Beräkna position size baserat på risk
   │   ├── Öppna position med:
   │   │   ├── Entry price (market eller limit)
   │   │   ├── Stop loss (baserat på ATR/struktur)
   │   │   └── Take profit (liten, konservativ)
   │   └── Logga entry i PositionManager
   └── Om filter INTE passerar:
       └── Logga "Entry blocked by filter: {reason}"

3. Position öppen:
   ├── Monitor för TP/SL
   ├── Om TP träffas: Logga vinst, avvakta ny signal
   └── Om SL träffas ELLER pris går mot oss:
       └── Utvärdera grid-aktivering
```

---

## 3.3 PositionManager

### Syfte
Hålla exakt koll på alla positioner och deras aggregerade state.

### Data som spåras

```cpp
struct PositionState {
    // Grundläggande
    datetime entry_time;           // När första position öppnades
    double   initial_entry_price;  // Första entry-pris
    double   initial_lot_size;     // Första position storlek
    int      entry_mode;           // Vilken entry mode som användes
    int      direction;            // 1 = long, -1 = short

    // Grid state
    bool     grid_active;          // Är grid aktiverad?
    int      grid_structure;       // Vilken struktur (0-5)
    int      open_levels;          // Antal öppna grid-nivåer
    double   total_lots;           // Total exponering
    datetime grid_activated_at;    // När grid aktiverades

    // Beräknade värden
    double   average_entry_price;  // Volymviktat genomsnittspris
    double   breakeven_price;      // Pris för att gå ±0
    double   unrealized_pnl;       // Flytande P/L i kontoräkensvaluta
    double   unrealized_pnl_pct;   // Som % av konto

    // Drawdown tracking
    double   max_adverse_excursion; // Värsta punkt (MAE)
    double   current_drawdown_pct;  // Nuvarande DD
    double   dd_velocity;           // Hur snabbt DD förändras

    // Timing
    int      bars_in_trade;        // Hur länge position varit öppen
    int      grid_age_bars;        // Hur länge grid varit aktiv
};
```

### Beräkningsexempel

**Scenario:** Long EUR/USD med 3 grid-nivåer

```
Position 1: Entry 1.0900, 0.10 lot (initial entry)
Position 2: Entry 1.0850, 0.15 lot (grid level 1)
Position 3: Entry 1.0800, 0.22 lot (grid level 2)

Nuvarande pris: 1.0820

Beräkningar:
─────────────
Total lots = 0.10 + 0.15 + 0.22 = 0.47 lot

Average entry price = (1.0900×0.10 + 1.0850×0.15 + 1.0800×0.22) / 0.47
                    = (0.109 + 0.16275 + 0.2376) / 0.47
                    = 0.50935 / 0.47
                    = 1.0838

Breakeven price = Average entry price + spread + kommission per point
                ≈ 1.0840 (med 2 pip spread)

Unrealized P/L per position:
  Pos 1: (1.0820 - 1.0900) × 0.10 × 100,000 = -80 pips × $10 = -$80
  Pos 2: (1.0820 - 1.0850) × 0.15 × 100,000 = -30 pips × $15 = -$45
  Pos 3: (1.0820 - 1.0800) × 0.22 × 100,000 = +20 pips × $22 = +$44

Total unrealized P/L = -$80 - $45 + $44 = -$81

Om konto = $10,000:
  unrealized_pnl_pct = -0.81%
```

### Drawdown Velocity

Mäter hur snabbt drawdown förvärras:

```cpp
double CalculateDrawdownVelocity() {
    // Håll historik av DD över senaste N bars
    static double dd_history[10];
    static int dd_index = 0;

    dd_history[dd_index] = current_drawdown_pct;
    dd_index = (dd_index + 1) % 10;

    // Beräkna genomsnittlig förändring per bar
    double total_change = 0;
    for (int i = 1; i < 10; i++) {
        total_change += dd_history[i] - dd_history[i-1];
    }

    return total_change / 9.0;  // Genomsnittlig DD-förändring per bar
}
```

**Tolkning:**
- DD velocity > 0: Drawdown förvärras (farligt)
- DD velocity ≈ 0: Stabil situation
- DD velocity < 0: Recovery pågår (bra)

---

## 3.4 GridEngine – Detaljerad Beskrivning av Strukturer

### Översikt

EA implementerar 6 olika grid-strukturer. ONNX väljer vilken som är aktiv baserat på marknadsförhållanden. Varje struktur har olika egenskaper som passar olika situationer.

### 3.4.1 Horizontal Grid (Klassisk)

**Koncept:** Fast spacing mellan alla nivåer. Enklast att förstå och implementera.

```
Horizontal Grid - Long position
Initial entry: 1.0900
Spacing: 50 pips
Lot growth: 1.5x

Pris        Lot     Nivå
──────────────────────────
1.0900      0.10    Entry
1.0850      0.15    Level 1  (50 pips under)
1.0800      0.22    Level 2  (50 pips under)
1.0750      0.33    Level 3  (50 pips under)
1.0700      0.50    Level 4  (50 pips under)
1.0650      0.75    Level 5  (50 pips under)

Visualisering:
   1.0950 ┤
          │
   1.0900 ├──●────────────────── Entry (0.10)
          │  │
   1.0850 ├──┼──●──────────────── L1 (0.15)
          │  │  │
   1.0800 ├──┼──┼──●────────────── L2 (0.22)
          │  │  │  │
   1.0750 ├──┼──┼──┼──●──────────── L3 (0.33)
          │  │  │  │  │
   1.0700 ├──┼──┼──┼──┼──●──────── L4 (0.50)
          │  │  │  │  │  │
   1.0650 ├──┼──┼──┼──┼──┼──●──── L5 (0.75)
          │  │  │  │  │  │  │
```

**Bäst för:**
- Ranging marknad (ingen tydlig trend)
- Normal/låg volatilitet
- När mean reversion är sannolikt

**Problem:**
- Rigid - anpassar sig inte till förändrade förhållanden
- Kan bli överraskad av trend

**Implementation:**

```cpp
double CalculateHorizontalGridLevel(int level, double entry_price,
                                     double base_spacing, int direction) {
    // direction: 1 = long (nivåer under entry), -1 = short (nivåer över entry)
    return entry_price - (direction * level * base_spacing);
}

double CalculateHorizontalLotSize(int level, double initial_lot, double lot_growth) {
    return initial_lot * MathPow(lot_growth, level);
}
```

---

### 3.4.2 ATR-Adaptive Grid

**Koncept:** Spacing justeras automatiskt baserat på aktuell volatilitet (ATR).

```
ATR-Adaptive Grid - Long position
Initial entry: 1.0900
ATR(H1): 20 pips → Spacing = ATR × 2.5 = 50 pips
(Men om ATR ökar till 30 pips → Spacing = 75 pips)

Scenario A: Normal volatilitet (ATR = 20 pips)
─────────────────────────────────────────────────
1.0900      0.10    Entry
1.0850      0.15    Level 1  (50 pips)
1.0800      0.22    Level 2  (50 pips)

Scenario B: Ökad volatilitet (ATR = 30 pips)
─────────────────────────────────────────────────
1.0900      0.10    Entry
1.0825      0.15    Level 1  (75 pips)
1.0750      0.22    Level 2  (75 pips)

Visualisering av skillnaden:

Normal ATR:          Hög ATR:
   │                    │
   ●Entry               ●Entry
   │ 50 pips            │
   ●L1                  │ 75 pips
   │ 50 pips            │
   ●L2                  ●L1
   │                    │ 75 pips
                        │
                        ●L2
```

**Fördelar:**
- Automatisk anpassning till marknadsförhållanden
- Bredare spacing vid hög volatilitet = mindre risk för rapid triggering
- Tightare spacing vid låg volatilitet = fler möjligheter

**Implementation:**

```cpp
double CalculateATRAdaptiveLevel(int level, double entry_price,
                                  double atr, double atr_multiplier, int direction) {
    double spacing = atr * atr_multiplier;
    return entry_price - (direction * level * spacing);
}

// Dynamisk lot growth baserat på volatilitet
double CalculateATRAdaptiveLotGrowth(double base_growth, double volatility_level) {
    // Lägre lot growth vid hög volatilitet
    // volatility_level 0.5 (normal) → base_growth
    // volatility_level 0.8 (hög) → base_growth × 0.7
    double adjustment = 1.0 - (volatility_level - 0.5) * 0.6;
    return base_growth * MathMax(0.7, MathMin(1.0, adjustment));
}
```

---

### 3.4.3 Trend-Aligned Grid

**Koncept:** Grid-nivåerna rör sig med trenden över tid. Istället för statiska nivåer, "glider" griden i trendriktning.

```
Trend-Aligned Grid - Long position i upptrend
Initial entry: 1.0900
Base spacing: 50 pips
Trend slope: +5 pips per timme

Tid     Entry   L1      L2      L3
────────────────────────────────────────
T+0     1.0900  1.0850  1.0800  1.0750  (initial)
T+1h    1.0905  1.0855  1.0805  1.0755  (+5 pips drift)
T+2h    1.0910  1.0860  1.0810  1.0760  (+5 pips drift)
T+4h    1.0920  1.0870  1.0820  1.0770  (+5 pips drift)

Visualisering över tid:

Pris
   │    T+0         T+2h        T+4h
   │
1.0920 │                          ●Entry
   │                    ●Entry    │
1.0900 │──●Entry──      │         │
   │    │               │         │
1.0870 │    │           │         ●L1
   │    │         ●L1   │         │
1.0850 │──●L1──   │     │         │
   │    │         │     ●L1       │
1.0820 │    │     │     │         ●L2
   │    │   ●L2   │     │         │
1.0800 │──●L2──   │     │         │
   │    │         ●L2   │         │
   │    │         │     ●L2       │
       ─────────────────────────────► Tid
```

**Varför det fungerar:**
- I en trend, om vi inte flyttar nivåerna, hamnar vi "för långt bort" från aktuellt pris
- Genom att drifta med trenden, behåller vi relevant spacing
- Minskar risken för att griden blir "stranded" i fel prisområde

**Implementation:**

```cpp
struct TrendAlignedGrid {
    double base_entry;
    double base_spacing;
    double trend_slope;      // pips per timme
    datetime activation_time;
};

double CalculateTrendAlignedLevel(TrendAlignedGrid& grid, int level, int direction) {
    // Tid sedan aktivering
    double hours_elapsed = (TimeCurrent() - grid.activation_time) / 3600.0;

    // Drift baserat på trend
    double drift = grid.trend_slope * hours_elapsed * Point * 10;  // konvertera pips till price

    // Nivå med drift
    double base_level = grid.base_entry - (direction * level * grid.base_spacing);
    return base_level + drift;
}
```

**Viktigt:**
- Slope uppdateras periodiskt baserat på faktisk marknadsrörelse
- Om trenden vänder, stoppar driften eller reverserar
- Max drift begränsas för att undvika extrema nivåer

---

### 3.4.4 Curved Grid (Icke-linjär)

**Koncept:** Spacing ökar exponentiellt med varje nivå. Tätt nära entry, glesare längre bort.

```
Curved Grid - Long position
Initial entry: 1.0900
Base spacing: 30 pips
Curve factor (α): 0.15

Formula: spacing_i = base × (1 + α × i²)

Level   Spacing beräkning           Spacing   Pris
──────────────────────────────────────────────────────
Entry   -                           -         1.0900
L1      30 × (1 + 0.15 × 1²)        34.5      1.0865
L2      30 × (1 + 0.15 × 4)         48.0      1.0817
L3      30 × (1 + 0.15 × 9)         70.5      1.0747
L4      30 × (1 + 0.15 × 16)        102.0     1.0645
L5      30 × (1 + 0.15 × 25)        142.5     1.0502

Visualisering:

   1.0900 ├───●Entry
          │   │ 34.5 pips (tight)
   1.0865 ├───●L1
          │   │ 48 pips
   1.0817 ├───●L2
          │   │
          │   │ 70.5 pips
          │   │
   1.0747 ├───●L3
          │   │
          │   │
          │   │ 102 pips
          │   │
          │   │
   1.0645 ├───●L4
          │   │
          │   │
          │   │
          │   │ 142.5 pips
          │   │
          │   │
          │   │
   1.0502 ├───●L5
```

**Fördelar:**
- Fångar små pullbacks med täta tidiga nivåer
- Sparar kapital för större rörelser med glesa sena nivåer
- Naturlig de-eskalering

**Bäst för:**
- Mean reversion scenarios (de flesta pullbacks är små)
- När du vill fånga 70% av fallen med L1-L2

**AI styr α:**
- Högre α → snabbare expansion (mer konservativt)
- Lägre α → mer linjärt beteende

**Implementation:**

```cpp
double CalculateCurvedSpacing(int level, double base_spacing, double alpha) {
    return base_spacing * (1.0 + alpha * level * level);
}

double CalculateCurvedGridLevel(int level, double entry_price,
                                 double base_spacing, double alpha, int direction) {
    double cumulative_distance = 0;
    for (int i = 1; i <= level; i++) {
        cumulative_distance += CalculateCurvedSpacing(i, base_spacing, alpha);
    }
    return entry_price - (direction * cumulative_distance);
}
```

---

### 3.4.5 Volatility-Skewed Grid (Asymmetrisk)

**Koncept:** Olika spacing beroende på om priset rör sig med eller mot trenden.

```
Volatility-Skewed Grid - Long position i upptrend
Entry: 1.0900
Trend direction: UP

Mot trenden (ner) = tätare nivåer (fler chanser för recovery)
Med trenden (om short) = glesare (mer skydd mot trend)

Men vi är LONG, så:
- Priset faller = vi är fel → fler nivåer, tätare spacing
- Om vi var SHORT i samma upptrend → vi är ännu mer fel → mycket gles

           │
   1.0950 ─┤                   ▲
           │                   │ Trend direction
   1.0900 ─├──●Entry           │
           │  │ 40 pips        │
   1.0860 ─├──●L1
           │  │ 45 pips (ökar lite)
   1.0815 ─├──●L2
           │  │ 50 pips
   1.0765 ─├──●L3
           │  │ 55 pips
   1.0710 ─├──●L4
           │

Jämfört med standard grid:
Standard:  Entry → 50 → 50 → 50 → 50
Skewed:    Entry → 40 → 45 → 50 → 55

```

**Logik:**
- Om vi handlar MOT trenden (mottrend), vi vet att vi tar hög risk
- Därför vill vi snabbt bygga position nära entry
- Men om vi handlar MED trenden och det ändå går emot oss, är något fundamentalt fel
- Då vill vi vara mer försiktiga med att addera

**Implementation:**

```cpp
double CalculateSkewedSpacing(int level, double base_spacing,
                               double trend_strength, int trade_direction, int trend_direction) {
    // Faktor: hur mycket vi är "med" trenden (1) eller "mot" (-1)
    int alignment = trade_direction * trend_direction;  // +1 eller -1

    // Skew factor baserat på trend strength och alignment
    double skew;
    if (alignment > 0) {
        // Med trenden men det går fel - var försiktig
        skew = 1.0 + (trend_strength * 0.1 * level);  // spacing ökar mer
    } else {
        // Mot trenden - var aggressiv tidigt
        skew = 1.0 - (trend_strength * 0.05 * level);  // spacing minskar lite
        skew = MathMax(0.7, skew);  // minimum 70% av base
    }

    return base_spacing * skew;
}
```

---

### 3.4.6 Time-Decay Grid

**Koncept:** Ju längre griden är aktiv, desto mer konservativ blir den.

```
Time-Decay Grid - Beteende över tid
Entry: 1.0900, Tid T+0

Fas 1: Aktiv fas (0-4 timmar)
────────────────────────────
Normal spacing: 50 pips
Normal lot growth: 1.5x
Ny nivå läggs till om villkor uppfylls

Fas 2: Mogen fas (4-12 timmar)
────────────────────────────
Spacing ökar: 50 → 60 pips (+20%)
Lot growth minskar: 1.5x → 1.3x
Längre tid mellan nya nivåer

Fas 3: Åldrad fas (12-24 timmar)
────────────────────────────
Spacing ökar: 60 → 75 pips (+50% från start)
Lot growth minskar: 1.3x → 1.15x
Inga nya nivåer läggs till

Fas 4: Exit-fas (>24 timmar)
────────────────────────────
Letar aktivt efter exit
Accepterar break-even eller liten förlust
Kan stänga vid bättre pris än genomsnitt

Visualisering av aging:

Aggressivitet
    │
1.0 ├──────╮
    │      │╲
0.8 ├      │ ╲
    │      │  ╲
0.6 ├      │   ╲
    │      │    ╲
0.4 ├      │     ╲
    │      │      ╲────────
0.2 ├      │
    │      │
  0 ├──────┴───────────────────────
    0     4h    12h    24h    Time
       Aktiv  Mogen  Åldrad  Exit
```

**Filosofi:**
- Färska grids har bäst chans att lösa sig
- Gamla grids indikerar att vi hade fel om marknaden
- Eskalera inte en förlorande position i det oändliga
- Acceptera att vissa trades blir förluster

**Implementation:**

```cpp
struct TimeDecayParams {
    double age_hours;
    double spacing_decay_rate;     // hur mycket spacing ökar per timme
    double lot_growth_decay_rate;  // hur mycket lot growth minskar per timme
    double max_spacing_multiplier; // max spacing ökning
    double min_lot_growth;         // minimum lot growth
    int    max_age_hours;          // när exit-fas börjar
};

double GetTimeDecayedSpacing(double base_spacing, TimeDecayParams& params) {
    double age_factor = MathMin(params.age_hours / params.max_age_hours, 1.0);
    double multiplier = 1.0 + (params.max_spacing_multiplier - 1.0) * age_factor;
    return base_spacing * multiplier;
}

double GetTimeDecayedLotGrowth(double base_lot_growth, TimeDecayParams& params) {
    double age_factor = MathMin(params.age_hours / params.max_age_hours, 1.0);
    double growth = base_lot_growth - (base_lot_growth - params.min_lot_growth) * age_factor;
    return MathMax(params.min_lot_growth, growth);
}

bool ShouldSeekExit(TimeDecayParams& params, double unrealized_pnl_pct) {
    // I exit-fas, acceptera break-even eller liten förlust
    if (params.age_hours > params.max_age_hours) {
        if (unrealized_pnl_pct > -0.5) {  // inom 0.5% av break-even
            return true;
        }
    }
    return false;
}
```

---

## 3.5 Grid Transitions

### Koncept

Grid "dör" inte - den transformeras. AI kan besluta att byta struktur baserat på förändrade marknadsförhållanden.

### Tillåtna övergångar

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│ Horizontal  │────►│ ATR-Adaptive│────►│   Curved    │
└─────────────┘     └─────────────┘     └─────────────┘
       │                   │                   │
       │                   │                   │
       ▼                   ▼                   ▼
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Trend-    │────►│ Volatility- │────►│    Time-    │
│  Aligned    │     │   Skewed    │     │   Decay     │
└─────────────┘     └─────────────┘     └─────────────┘
       │                   │                   │
       └───────────────────┴───────────────────┘
                           │
                           ▼
                    ┌─────────────┐
                    │   FREEZE    │
                    │  (no new    │
                    │   levels)   │
                    └──────┬──────┘
                           │
                           ▼
                    ┌─────────────┐
                    │  CLOSE_ALL  │
                    └─────────────┘
```

### Transition-exempel

**Scenario: Ranging marknad blir trending**

```
Steg 1: Startar med Horizontal Grid i ranging marknad
────────────────────────────────────────────────────
MarketState: trend_strength=0.2, volatility=0.4
Grid: Horizontal, spacing=50 pips
Nivåer: Entry + L1 + L2 öppna

Steg 2: Marknad börjar trenda
────────────────────────────────────────────────────
MarketState: trend_strength=0.6, volatility=0.5
ONNX: grid_action=TRANSITION, new_structure=TREND_ALIGNED

Steg 3: EA genomför transition
────────────────────────────────────────────────────
- Befintliga positioner behålls
- Ny spacing beräknas med trend-drift
- Framtida nivåer följer trend

Före transition:          Efter transition:
   1.0900 ●Entry             1.0900 ●Entry
   1.0850 ●L1                1.0850 ●L1 (befintlig)
   1.0800 ●L2                1.0800 ●L2 (befintlig)
   1.0750 [L3 väntande]      1.0760 [L3 väntande - justerad för trend]
```

### Implementation av transition

```cpp
void ExecuteGridTransition(int new_structure) {
    // 1. Spara nuvarande state
    GridSnapshot snapshot;
    snapshot.open_positions = CopyOpenPositions();
    snapshot.total_lots = CalculateTotalLots();
    snapshot.average_entry = CalculateAverageEntry();

    // 2. Uppdatera grid-struktur
    current_grid.structure = new_structure;
    current_grid.transition_time = TimeCurrent();

    // 3. Beräkna nya parametrar baserat på ny struktur
    RecalculateGridParameters(new_structure);

    // 4. Befintliga positioner påverkas INTE
    // Endast framtida nivåer använder ny struktur

    // 5. Logga transition
    LogTransition(snapshot, new_structure);
}
```

### Transition Hysteresis (v2.0)

> **Problem:** Utan hysteresis kan griden "flappar" mellan strukturer i stökiga regimer.

**Exempel på flapping:**
```
Bar 1: MarketState ändras → ONNX: "Transition to TREND_ALIGNED"
Bar 2: MarketState svänger tillbaka → ONNX: "Transition to HORIZONTAL"
Bar 3: MarketState ändras igen → ONNX: "Transition to TREND_ALIGNED"
→ Kaotiskt beteende, inkonsistent grid, ökad risk
```

**Lösning: Hysteresis Gate**

```cpp
struct TransitionHysteresis {
    // Cooldown-perioder
    int min_bars_between_same_transition = 12;  // Samma transition: 12 bars (~12h på H1)
    int min_bars_between_any_transition = 4;    // Alla transitions: 4 bars (~4h på H1)

    // Stabilitetskrav för MarketState
    int required_stable_bars = 3;               // State måste vara stabil 3 bars
    double state_stability_threshold = 0.15;    // Max förändring per bar

    // Historik
    datetime last_transition_time;
    int last_from_structure;
    int last_to_structure;

    // State history ringbuffer
    MarketState state_history[5];
    int state_history_index;
};

bool IsTransitionAllowed(int from_structure, int to_structure,
                         MarketState& current_state, double confidence) {

    // Gate 1: Confidence check
    if (confidence < MIN_TRANSITION_CONFIDENCE) {
        Log("Transition blocked: confidence " + DoubleToString(confidence) + " < 0.50");
        return false;
    }

    // Gate 2: Global cooldown
    int bars_since_last = BarsSince(hysteresis.last_transition_time);
    if (bars_since_last < hysteresis.min_bars_between_any_transition) {
        Log("Transition blocked: global cooldown (" +
            IntegerToString(bars_since_last) + "/" +
            IntegerToString(hysteresis.min_bars_between_any_transition) + " bars)");
        return false;
    }

    // Gate 3: Reverse-transition cooldown (förhindra oscillering)
    bool is_reverse = (to_structure == hysteresis.last_from_structure &&
                       from_structure == hysteresis.last_to_structure);
    if (is_reverse && bars_since_last < hysteresis.min_bars_between_same_transition) {
        Log("Transition blocked: reverse cooldown (" +
            IntegerToString(bars_since_last) + "/" +
            IntegerToString(hysteresis.min_bars_between_same_transition) + " bars)");
        return false;
    }

    // Gate 4: MarketState stability
    if (!IsMarketStateStable()) {
        Log("Transition blocked: MarketState not stable for " +
            IntegerToString(hysteresis.required_stable_bars) + " bars");
        return false;
    }

    return true;
}

bool IsMarketStateStable() {
    // Kräver att trend_strength och volatility_level
    // inte varierat mer än threshold de senaste N bars
    for (int i = 1; i < hysteresis.required_stable_bars; i++) {
        int idx_curr = (hysteresis.state_history_index - i + 5) % 5;
        int idx_prev = (hysteresis.state_history_index - i - 1 + 5) % 5;

        double trend_change = MathAbs(
            hysteresis.state_history[idx_curr].trend_strength -
            hysteresis.state_history[idx_prev].trend_strength
        );
        double vol_change = MathAbs(
            hysteresis.state_history[idx_curr].volatility_level -
            hysteresis.state_history[idx_prev].volatility_level
        );

        if (trend_change > hysteresis.state_stability_threshold ||
            vol_change > hysteresis.state_stability_threshold) {
            return false;
        }
    }
    return true;
}
```

**Hysteresis-flöde:**

```
ONNX: TRANSITION förfrågan
         │
         ▼
┌─────────────────────────┐
│ Gate 1: Confidence ≥0.5?│──NO──► BLOCKED
└───────────┬─────────────┘
            │YES
            ▼
┌─────────────────────────┐
│ Gate 2: Global cooldown │──NO──► BLOCKED
│ (≥4 bars since last?)   │
└───────────┬─────────────┘
            │YES
            ▼
┌─────────────────────────┐
│ Gate 3: Reverse cooldown│──NO──► BLOCKED
│ (≥12 bars if reversing?)│
└───────────┬─────────────┘
            │YES
            ▼
┌─────────────────────────┐
│ Gate 4: State stable    │──NO──► BLOCKED
│ (3 bars stable?)        │
└───────────┬─────────────┘
            │YES
            ▼
      ✓ TRANSITION ALLOWED
```

**Praktiskt exempel:**

```
Bar 100: trend_strength = 0.70, current = HORIZONTAL
         ONNX: TRANSITION → TREND_ALIGNED, confidence = 0.72
         Stability: [0.65, 0.68, 0.70] ✓
         → ALLOWED

Bar 101: trend_strength = 0.55
         ONNX: TRANSITION → ATR_ADAPTIVE, confidence = 0.48
         → BLOCKED (confidence < 0.50)

Bar 102: trend_strength = 0.40
         ONNX: TRANSITION → HORIZONTAL, confidence = 0.61
         → BLOCKED (global cooldown: 2 bars < 4)

Bar 104: trend_strength = 0.35
         ONNX: TRANSITION → HORIZONTAL, confidence = 0.68
         Stability: [0.70, 0.55, 0.40, 0.35] - UNSTABLE!
         → BLOCKED (trend changed 0.35 in 4 bars)

Bar 108: trend_strength = 0.32
         ONNX: TRANSITION → HORIZONTAL, confidence = 0.71
         Stability: [0.34, 0.33, 0.32] ✓
         → ALLOWED
```

---

## 3.6 RiskEngine

### Hårda begränsningar (aldrig förhandlingsbara)

Dessa gränser är hårdkodade i EA och kan ALDRIG åsidosättas av AI.

```cpp
struct HardLimits {
    double max_drawdown_pct = 15.0;          // Max 15% drawdown
    double max_total_lots = 5.0;             // Max total exponering
    int    max_grid_levels = 8;              // Max 8 nivåer
    int    max_grid_age_hours = 72;          // Max 3 dagar
    double max_exposure_per_symbol = 0.10;   // Max 10% av konto per symbol
    double emergency_close_dd_pct = 20.0;    // Nödstängning vid 20% DD
};

bool CheckHardLimits(HardLimits& limits, PositionState& state) {
    // Drawdown check
    if (state.current_drawdown_pct >= limits.max_drawdown_pct) {
        Log("HARD LIMIT: Max drawdown reached");
        return false;  // Blockera alla nya nivåer
    }

    // Total lots check
    if (state.total_lots >= limits.max_total_lots) {
        Log("HARD LIMIT: Max lots reached");
        return false;
    }

    // Grid levels check
    if (state.open_levels >= limits.max_grid_levels) {
        Log("HARD LIMIT: Max grid levels reached");
        return false;
    }

    // Grid age check
    if (state.grid_age_bars * GetBarDurationHours() >= limits.max_grid_age_hours) {
        Log("HARD LIMIT: Max grid age reached");
        return false;
    }

    // Emergency close
    if (state.current_drawdown_pct >= limits.emergency_close_dd_pct) {
        Log("EMERGENCY: Closing all positions");
        CloseAllPositions();
        return false;
    }

    return true;
}
```

### Dynamiska gränser (AI kan justera inom range)

```cpp
struct DynamicLimits {
    // ONNX föreslår värden inom dessa ranges
    double spacing_min = 20.0;       // pips
    double spacing_max = 100.0;      // pips
    double lot_growth_min = 1.1;
    double lot_growth_max = 2.0;
    int    recommended_max_levels_min = 3;
    int    recommended_max_levels_max = 8;
};

void ApplyONNXDecision(ONNXOutput& decision, DynamicLimits& limits) {
    // Clampa alla AI-beslut till tillåtna ranges
    double spacing = MathMax(limits.spacing_min,
                     MathMin(limits.spacing_max, decision.base_spacing));

    double lot_growth = MathMax(limits.lot_growth_min,
                        MathMin(limits.lot_growth_max, decision.lot_growth));

    int max_levels = MathMax(limits.recommended_max_levels_min,
                     MathMin(limits.recommended_max_levels_max, decision.max_levels));
}
```

---

## 3.7 SafetyController

### Katastrofdetektering

```cpp
struct SafetyChecks {
    // Volatility spike detection
    double volatility_spike_threshold = 2.5;  // ATR ratio

    // Spread anomaly
    double spread_zscore_threshold = 3.0;

    // Equity cliff (snabb förlust)
    double equity_cliff_pct = 5.0;            // 5% på kort tid
    int    equity_cliff_bars = 10;            // inom 10 bars

    // Connection health
    int    max_missed_ticks_seconds = 30;
};

enum SafetyAction {
    SAFETY_OK,
    SAFETY_PAUSE_NEW_ENTRIES,
    SAFETY_FREEZE_GRID,
    SAFETY_CLOSE_ALL
};

SafetyAction EvaluateSafety(SafetyChecks& checks, MarketState& market, PositionState& position) {
    // Volatility spike
    if (market.volatility_change > checks.volatility_spike_threshold) {
        Log("SAFETY: Volatility spike detected");
        return SAFETY_FREEZE_GRID;
    }

    // Spread anomaly
    if (MathAbs(market.spread_zscore) > checks.spread_zscore_threshold) {
        Log("SAFETY: Spread anomaly detected");
        return SAFETY_PAUSE_NEW_ENTRIES;
    }

    // Equity cliff
    double equity_change = CalculateEquityChange(checks.equity_cliff_bars);
    if (equity_change < -checks.equity_cliff_pct) {
        Log("SAFETY: Equity cliff detected - rapid loss");
        return SAFETY_CLOSE_ALL;
    }

    // Connection health
    if (GetSecondsSinceLastTick() > checks.max_missed_ticks_seconds) {
        Log("SAFETY: Connection issue detected");
        return SAFETY_FREEZE_GRID;
    }

    return SAFETY_OK;
}
```

### Händelsedriven säkerhet

```cpp
void OnTradeTransaction(const MqlTradeTransaction& trans) {
    // Detektera oväntade händelser
    if (trans.type == TRADE_TRANSACTION_ORDER_DELETE) {
        // Order togs bort - av vem?
        if (!WasOrderDeletedByEA(trans.order)) {
            Log("WARNING: External order deletion detected");
            // Kan vara manuell intervention - respektera det
        }
    }

    if (trans.type == TRADE_TRANSACTION_DEAL_ADD) {
        // Ny deal - kontrollera slippage
        double expected_price = GetExpectedFillPrice(trans.order);
        double actual_price = trans.price;
        double slippage_pips = MathAbs(expected_price - actual_price) / Point / 10;

        if (slippage_pips > 5.0) {
            Log("WARNING: High slippage detected: " + DoubleToString(slippage_pips) + " pips");
            // Kan indikera dålig likviditet eller flash crash
        }
    }
}
```

---

# Del 4: ONNX Integration

## 4.1 ONNX Model Specification

### Input Tensor

```
Name: "state_input"
Shape: [1, 12]
Type: float32

Index   Feature                 Range           Description
─────────────────────────────────────────────────────────────
0       trend_strength          [0, 1]          Styrka på trend
1       trend_slope             [-1, 1]         Trendens lutning
2       trend_curvature         [-1, 1]         Trendens krökning
3       volatility_level        [0, 1]          Normaliserad volatilitet
4       volatility_change       [-1, 1]         Volatilitetsförändring
5       mean_reversion_score    [0, 1]          MR-sannolikhet
6       spread_zscore           [-3, 3]         Spread z-score (clipped)
7       session_id              [0, 4]          Session (one-hot eller int)
8       grid_active             [0, 1]          Är grid aktiv?
9       open_levels             [0, 8]          Antal öppna nivåer (normaliserat)
10      unrealized_dd_pct       [0, 1]          Unrealized DD (normaliserat)
11      dd_velocity             [-1, 1]         DD-hastighet
```

### Output Tensor

```
Name: "decision_output"
Shape: [1, 12]
Type: float32

Index   Feature                 Range           Description
─────────────────────────────────────────────────────────────
0       allow_entry             [0, 1]          Sannolikhet för entry (>0.5 = ja)
1       entry_mode              [0, 4]          Entry-typ (argmax)
2       entry_direction         [-1, 1]         -1=short, 0=neutral, 1=long
3       initial_risk_pct        [0.5, 2.0]      Risk per trade i %
4       activate_grid           [0, 1]          Aktivera grid? (>0.5 = ja)
5       grid_structure          [0, 5]          Grid-struktur (argmax)
6       grid_action             [0, 4]          Grid-action (argmax)
7       base_spacing            [20, 100]       Spacing i pips
8       spacing_growth          [1.0, 1.5]      Spacing growth factor
9       lot_growth              [1.1, 2.0]      Lot growth factor
10      max_levels              [3, 8]          Max grid-nivåer
11      confidence              [0, 1]          Modellens konfidensgrad
```

### Normaliseringsregler

```cpp
// Input normalisering
float NormalizeInput(int index, double raw_value) {
    switch(index) {
        case 0: return (float)raw_value;  // trend_strength redan 0-1
        case 1: return (float)((raw_value + 1.0) / 2.0);  // slope: [-1,1] -> [0,1]
        case 2: return (float)((raw_value + 1.0) / 2.0);  // curvature: [-1,1] -> [0,1]
        case 3: return (float)raw_value;  // volatility redan 0-1
        case 4: return (float)((raw_value + 1.0) / 2.0);  // vol_change: [-1,1] -> [0,1]
        case 5: return (float)raw_value;  // MR score redan 0-1
        case 6: return (float)((raw_value + 3.0) / 6.0);  // zscore: [-3,3] -> [0,1]
        case 7: return (float)(raw_value / 4.0);  // session: [0,4] -> [0,1]
        case 8: return (float)raw_value;  // grid_active: 0 eller 1
        case 9: return (float)(raw_value / 8.0);  // levels: [0,8] -> [0,1]
        case 10: return (float)(raw_value / 20.0);  // DD: [0,20%] -> [0,1]
        case 11: return (float)((raw_value + 1.0) / 2.0);  // dd_vel: [-1,1] -> [0,1]
    }
    return 0.0f;
}

// Output denormalisering
double DenormalizeOutput(int index, float normalized_value) {
    switch(index) {
        case 7: return normalized_value * 80.0 + 20.0;  // spacing: [0,1] -> [20,100]
        case 8: return normalized_value * 0.5 + 1.0;    // spacing_growth: [0,1] -> [1.0,1.5]
        case 9: return normalized_value * 0.9 + 1.1;    // lot_growth: [0,1] -> [1.1,2.0]
        case 10: return (int)(normalized_value * 5.0 + 3.0);  // levels: [0,1] -> [3,8]
    }
    return (double)normalized_value;
}
```

## 4.2 MQL5 ONNX Runtime

### Modell-laddning

```cpp
// Globala variabler
long onnx_handle = INVALID_HANDLE;
string onnx_model_path = "policy_v1.onnx";

int OnInit() {
    // Ladda ONNX-modell
    onnx_handle = OnnxCreate(onnx_model_path, ONNX_DEFAULT);

    if (onnx_handle == INVALID_HANDLE) {
        Print("ERROR: Could not load ONNX model: ", onnx_model_path);
        return INIT_FAILED;
    }

    // Verifiera input shape
    long input_shape[];
    if (!OnnxGetInputShape(onnx_handle, 0, input_shape)) {
        Print("ERROR: Could not get input shape");
        return INIT_FAILED;
    }

    if (ArraySize(input_shape) != 2 || input_shape[1] != 12) {
        Print("ERROR: Unexpected input shape");
        return INIT_FAILED;
    }

    Print("ONNX model loaded successfully");
    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {
    if (onnx_handle != INVALID_HANDLE) {
        OnnxRelease(onnx_handle);
    }
}
```

### Inference

```cpp
struct ONNXDecision {
    bool   allow_entry;
    int    entry_mode;
    int    entry_direction;
    double initial_risk_pct;
    bool   activate_grid;
    int    grid_structure;
    int    grid_action;
    double base_spacing;
    double spacing_growth;
    double lot_growth;
    int    max_levels;
    double confidence;
};

bool RunONNXInference(MarketState& market, PositionState& position, ONNXDecision& decision) {
    // Förbered input
    float input_data[12];
    input_data[0] = NormalizeInput(0, market.trend_strength);
    input_data[1] = NormalizeInput(1, market.trend_slope);
    input_data[2] = NormalizeInput(2, market.trend_curvature);
    input_data[3] = NormalizeInput(3, market.volatility_level);
    input_data[4] = NormalizeInput(4, market.volatility_change);
    input_data[5] = NormalizeInput(5, market.mean_reversion_score);
    input_data[6] = NormalizeInput(6, market.spread_zscore);
    input_data[7] = NormalizeInput(7, market.session_id);
    input_data[8] = NormalizeInput(8, position.grid_active ? 1.0 : 0.0);
    input_data[9] = NormalizeInput(9, position.open_levels);
    input_data[10] = NormalizeInput(10, position.current_drawdown_pct);
    input_data[11] = NormalizeInput(11, position.dd_velocity);

    // Skapa input tensor
    const long input_shape[] = {1, 12};
    OnnxSetInputShape(onnx_handle, 0, input_shape);

    // Förbered output
    float output_data[12];
    const long output_shape[] = {1, 12};
    OnnxSetOutputShape(onnx_handle, 0, output_shape);

    // Kör inference
    if (!OnnxRun(onnx_handle, ONNX_DEFAULT, input_data, output_data)) {
        Print("ERROR: ONNX inference failed");
        return false;
    }

    // Parsa output
    decision.allow_entry = output_data[0] > 0.5;
    decision.entry_mode = ArgMax(output_data, 1, 5);  // index 1-4 för modes
    decision.entry_direction = output_data[2] > 0.33 ? 1 : (output_data[2] < -0.33 ? -1 : 0);
    decision.initial_risk_pct = DenormalizeOutput(3, output_data[3]);
    decision.activate_grid = output_data[4] > 0.5;
    decision.grid_structure = ArgMax(output_data, 5, 6);  // 6 strukturer
    decision.grid_action = (int)output_data[6];
    decision.base_spacing = DenormalizeOutput(7, output_data[7]);
    decision.spacing_growth = DenormalizeOutput(8, output_data[8]);
    decision.lot_growth = DenormalizeOutput(9, output_data[9]);
    decision.max_levels = (int)DenormalizeOutput(10, output_data[10]);
    decision.confidence = output_data[11];

    return true;
}
```

### Validering av ONNX output

```cpp
bool ValidateONNXDecision(ONNXDecision& decision) {
    // Kontrollera att alla värden är inom rimliga gränser

    if (decision.base_spacing < 10 || decision.base_spacing > 200) {
        Print("WARNING: Invalid spacing from ONNX: ", decision.base_spacing);
        decision.base_spacing = 50.0;  // Fallback
    }

    if (decision.lot_growth < 1.0 || decision.lot_growth > 3.0) {
        Print("WARNING: Invalid lot growth from ONNX: ", decision.lot_growth);
        decision.lot_growth = 1.5;  // Fallback
    }

    if (decision.max_levels < 1 || decision.max_levels > 10) {
        Print("WARNING: Invalid max levels from ONNX: ", decision.max_levels);
        decision.max_levels = 5;  // Fallback
    }

    if (decision.confidence < 0 || decision.confidence > 1) {
        Print("WARNING: Invalid confidence from ONNX: ", decision.confidence);
        decision.confidence = 0.5;  // Fallback
    }

    // Om confidence är för låg, var skeptisk
    if (decision.confidence < 0.3 && decision.allow_entry) {
        Print("WARNING: Low confidence entry - requiring confirmation");
        // Kan välja att blockera entry här
    }

    return true;
}
```

## 4.3 Confidence-Driven Adaptation (v2.0)

> **Princip:** Låg confidence = hög osäkerhet = konservativt beteende

ONNX returnerar `confidence` (0.0-1.0) för varje beslut. Gridzilla använder detta aktivt för att dynamiskt justera aggressivitet.

### Confidence-trösklar

```cpp
struct ConfidenceThresholds {
    double high_confidence = 0.75;     // Full aggressivitet
    double medium_confidence = 0.50;   // Normal
    double low_confidence = 0.35;      // Reducerad
    double min_confidence = 0.20;      // Blockera action

    // Gates för specifika actions
    double min_entry_confidence = 0.40;
    double min_grid_activate_confidence = 0.35;
    double min_transition_confidence = 0.50;  // HÖGRE - transitions är riskabla
    double min_add_level_confidence = 0.30;
};
```

### Skalning av spacing

```cpp
double ScaleSpacingByConfidence(double base_spacing, double confidence) {
    // Hög confidence → normal spacing
    // Låg confidence → ökad spacing (mer konservativt)

    if (confidence >= 0.75) {
        return base_spacing;  // 100%
    }
    else if (confidence >= 0.50) {
        // Interpolera: 100% → 125%
        double factor = 1.0 + (0.75 - confidence) / 0.25 * 0.25;
        return base_spacing * factor;
    }
    else if (confidence >= 0.35) {
        // Interpolera: 125% → 150%
        double factor = 1.25 + (0.50 - confidence) / 0.15 * 0.25;
        return base_spacing * factor;
    }
    else {
        return base_spacing * 1.5;  // Max 150%
    }
}
```

### Skalning av lot growth

```cpp
double ScaleLotGrowthByConfidence(double base_lot_growth, double confidence) {
    // Hög confidence → normal lot growth
    // Låg confidence → reducerad lot growth (mindre eskalering)

    if (confidence >= 0.75) {
        return base_lot_growth;  // 100%
    }
    else if (confidence >= 0.50) {
        // Reducera growth-faktorn (inte base)
        double growth_factor = base_lot_growth - 1.0;  // t.ex. 0.5 för 1.5x
        double scale = 1.0 - (0.75 - confidence) / 0.25 * 0.2;  // 100% → 80%
        return 1.0 + growth_factor * scale;
    }
    else if (confidence >= 0.35) {
        double growth_factor = base_lot_growth - 1.0;
        double scale = 0.8 - (0.50 - confidence) / 0.15 * 0.2;  // 80% → 60%
        return 1.0 + growth_factor * scale;
    }
    else {
        double growth_factor = base_lot_growth - 1.0;
        return 1.0 + growth_factor * 0.6;  // Max 60% reduction
    }
}
```

### Confidence-gates för actions

```cpp
bool IsActionAllowedByConfidence(int action_type, double confidence) {
    switch (action_type) {
        case ACTION_ENTRY:
            return confidence >= thresholds.min_entry_confidence;

        case ACTION_ACTIVATE_GRID:
            return confidence >= thresholds.min_grid_activate_confidence;

        case ACTION_TRANSITION:
            return confidence >= thresholds.min_transition_confidence;

        case ACTION_ADD_LEVEL:
            return confidence >= thresholds.min_add_level_confidence;
    }
    return true;
}
```

### Visualisering

```
Confidence:   0.2    0.35    0.5    0.75    1.0
              │       │       │       │       │
Spacing:      ├───────┼───────┼───────┼───────┤
              │ +50%  │ +37%  │ +12%  │  0%   │
              │       │       │       │       │
Lot Growth:   ├───────┼───────┼───────┼───────┤
              │ -40%  │ -30%  │ -10%  │  0%   │
              │       │       │       │       │
Transitions:  │ BLOCK │ BLOCK │  OK   │  OK   │
              │       │       │       │       │
Entry:        │ BLOCK │  OK   │  OK   │  OK   │
              │       │       │       │       │
Grid Activate:│ BLOCK │  OK   │  OK   │  OK   │
```

### Praktiskt exempel

```
ONNX Output:
  base_spacing = 50 pips
  lot_growth = 1.5
  confidence = 0.42

Efter confidence-skalning:
  spacing = 50 × 1.32 = 66 pips (+32%)
  lot_growth = 1.0 + 0.5 × 0.72 = 1.36 (-28% av growth)

Om ONNX föreslagit TRANSITION:
  → BLOCKED (confidence 0.42 < 0.50 threshold)

Om ONNX föreslagit ENTRY:
  → ALLOWED (confidence 0.42 ≥ 0.40 threshold)
  → Men med reducerad risk pga låg confidence
```

---

# Del 5: AI-träning (Offline)

## 5.1 Datainsamling

### Baseline EA för datainsamling

Först byggs en regelbaserad EA som genererar träningsdata:

```cpp
// Regelbaserad policy för datainsamling
struct RuleBasedPolicy {
    // Entry regler
    bool AllowEntry(MarketState& state) {
        // Enkel regel: entry i trend pullback
        if (state.trend_strength > 0.5 && state.mean_reversion_score > 0.4) {
            return true;
        }
        // Eller i range fade
        if (state.trend_strength < 0.3 && state.mean_reversion_score > 0.6) {
            return true;
        }
        return false;
    }

    // Grid aktivering
    bool ActivateGrid(PositionState& pos, MarketState& state) {
        // Aktivera grid om loss > 1% och tillräcklig tid har gått
        if (pos.unrealized_pnl_pct < -1.0 && pos.bars_in_trade > 4) {
            return true;
        }
        return false;
    }

    // Grid struktur val
    int SelectGridStructure(MarketState& state) {
        if (state.trend_strength > 0.6) return GRID_TREND_ALIGNED;
        if (state.volatility_level > 0.7) return GRID_ATR_ADAPTIVE;
        return GRID_HORIZONTAL;
    }
};
```

### Data format

```cpp
struct TrainingDataPoint {
    // State (input)
    MarketState market_state;
    PositionState position_state;

    // Action (vad som gjordes)
    int action_taken;           // Entry, add level, hold, close, etc.
    double action_params[5];    // Parametrar för action

    // Outcome (resultat)
    double pnl_after_1h;
    double pnl_after_4h;
    double pnl_after_24h;
    double max_drawdown;
    double max_favorable;
    bool   trade_closed;
    double final_pnl;

    // Metadata
    datetime timestamp;
    string symbol;
};
```

### Loggning

```cpp
void LogTrainingData(TrainingDataPoint& data) {
    // Skriv till CSV för träning
    string filename = "training_data_" + Symbol() + ".csv";
    int handle = FileOpen(filename, FILE_WRITE|FILE_CSV|FILE_COMMON, ',');

    // Header (första gången)
    if (FileSize(handle) == 0) {
        FileWrite(handle,
            "timestamp", "symbol",
            "trend_strength", "trend_slope", "trend_curvature",
            "volatility_level", "volatility_change", "mean_reversion_score",
            "spread_zscore", "session_id",
            "grid_active", "open_levels", "unrealized_dd", "dd_velocity",
            "action", "param1", "param2", "param3", "param4", "param5",
            "pnl_1h", "pnl_4h", "pnl_24h", "max_dd", "max_fav", "final_pnl"
        );
    }

    // Data row
    FileWrite(handle, /* all fields */);
    FileClose(handle);
}
```

## 5.2 Träningsmetoder

### Supervised Learning (Imitation Learning)

Träna modellen att imitera en framgångsrik regelbaserad strategi:

```python
# Python träningskod (körs offline)
import torch
import torch.nn as nn
import pandas as pd

class PolicyNetwork(nn.Module):
    def __init__(self, input_size=12, hidden_size=64, output_size=12):
        super().__init__()
        self.network = nn.Sequential(
            nn.Linear(input_size, hidden_size),
            nn.ReLU(),
            nn.BatchNorm1d(hidden_size),
            nn.Dropout(0.2),
            nn.Linear(hidden_size, hidden_size),
            nn.ReLU(),
            nn.BatchNorm1d(hidden_size),
            nn.Dropout(0.2),
            nn.Linear(hidden_size, output_size)
        )

        # Olika aktiveringar för olika outputs
        self.sigmoid = nn.Sigmoid()
        self.softmax = nn.Softmax(dim=1)

    def forward(self, x):
        raw_output = self.network(x)

        # Applicera lämpliga aktiveringar
        output = torch.zeros_like(raw_output)
        output[:, 0] = self.sigmoid(raw_output[:, 0])   # allow_entry
        output[:, 1:5] = self.softmax(raw_output[:, 1:5])  # entry_mode
        output[:, 2] = torch.tanh(raw_output[:, 2])      # direction
        # ... etc

        return output

# Träning
def train_supervised(model, train_loader, epochs=100):
    optimizer = torch.optim.Adam(model.parameters(), lr=0.001)
    criterion = nn.MSELoss()

    for epoch in range(epochs):
        for batch in train_loader:
            states, actions = batch
            predictions = model(states)
            loss = criterion(predictions, actions)

            optimizer.zero_grad()
            loss.backward()
            optimizer.step()
```

### Reinforcement Learning

För mer avancerad träning, använd RL med custom reward:

```python
class TradingEnvironment:
    def __init__(self, historical_data):
        self.data = historical_data
        self.current_step = 0
        self.position = None
        self.equity_curve = [10000]  # Start equity

    def step(self, action):
        # Exekvera action
        reward = self._calculate_reward(action)
        self.current_step += 1

        next_state = self._get_state()
        done = self.current_step >= len(self.data) - 1

        return next_state, reward, done

    def _calculate_reward(self, action):
        """
        Reward funktion som balanserar:
        - Vinst
        - Drawdown
        - Tid i position
        - Risk-adjusted returns
        """
        pnl = self._get_pnl_change()
        drawdown = self._get_current_drawdown()
        time_in_position = self._get_time_in_position()

        # Komponentviktning
        reward = 0.0

        # Belöning för vinst
        reward += pnl * 10.0

        # Straff för drawdown (exponentiellt)
        reward -= (drawdown ** 2) * 5.0

        # Straff för lång tid i position
        if time_in_position > 24:  # timmar
            reward -= (time_in_position - 24) * 0.1

        # Stor straff för att trigga max drawdown
        if drawdown > 15:
            reward -= 100.0

        return reward
```

## 5.3 ONNX Export

```python
def export_to_onnx(model, filepath="policy_v1.onnx"):
    model.eval()

    # Dummy input för trace
    dummy_input = torch.randn(1, 12)

    # Export
    torch.onnx.export(
        model,
        dummy_input,
        filepath,
        export_params=True,
        opset_version=12,
        do_constant_folding=True,
        input_names=['state_input'],
        output_names=['decision_output'],
        dynamic_axes={
            'state_input': {0: 'batch_size'},
            'decision_output': {0: 'batch_size'}
        }
    )

    print(f"Model exported to {filepath}")

    # Verifiera
    import onnx
    onnx_model = onnx.load(filepath)
    onnx.checker.check_model(onnx_model)
    print("ONNX model verified successfully")
```

## 5.4 Problemet med Imitation Learning (v2.0)

> **Varning:** Träningsdata från regelbaserad EA skapar bias.

```
Regelbaserad EA → Genererar data → Tränar ONNX → ONNX imiterar reglerna

Problem:
├── Modellen lär sig ATT följa regler, inte VARFÖR
├── Ärver alla edge cases och bias
└── Kan inte överträffa sin lärare
```

**Lösning: Multi-fas träning**

```
Fas A: Imitation Learning (baseline)
   ↓
Fas B: Counterfactual Labeling
   ↓
Fas C: Advantage-Weighted Learning
   ↓
Fas D: Shadow Mode Evaluation
   ↓
Fas E: Production (om godkänd)
```

## 5.5 Counterfactual Learning (v2.0)

### Koncept

För varje situation i historisk data, generera "vad hade hänt om"-alternativ:

```python
class CounterfactualGenerator:
    """
    Genererar alternativa scenarios för att lära modellen
    vad som HADE fungerat bättre.
    """

    def generate_counterfactuals(self, historical_data):
        counterfactuals = []

        for episode in historical_data:
            state = episode.state
            actual_action = episode.action
            actual_outcome = episode.outcome
            future_prices = episode.future_prices  # Faktiska framtida priser

            # Generera alternativ
            alternatives = self.get_alternatives(actual_action)

            for alt_action in alternatives:
                # Simulera vad som hade hänt
                simulated_outcome = self.simulate(state, alt_action, future_prices)

                counterfactuals.append({
                    'state': state,
                    'action': alt_action,
                    'outcome': simulated_outcome,
                    'comparison': {
                        'actual_pnl': actual_outcome.pnl,
                        'simulated_pnl': simulated_outcome.pnl,
                        'advantage': simulated_outcome.pnl - actual_outcome.pnl
                    }
                })

        return counterfactuals

    def get_alternatives(self, actual_action):
        alternatives = []

        # Alternativ 1: Om vi aktiverade grid - vad om vi INTE hade?
        if actual_action.activate_grid:
            alt = copy(actual_action)
            alt.activate_grid = False
            alternatives.append(alt)

        # Alternativ 2: Andra grid-strukturer
        for structure in range(6):
            if structure != actual_action.grid_structure:
                alt = copy(actual_action)
                alt.grid_structure = structure
                alternatives.append(alt)

        # Alternativ 3: Andra spacing-värden
        for mult in [0.7, 0.85, 1.15, 1.3]:
            alt = copy(actual_action)
            alt.base_spacing *= mult
            alternatives.append(alt)

        return alternatives
```

### Praktiskt counterfactual-exempel

```
Faktisk situation:
──────────────────
State: trend_strength=0.7, volatility=0.5
Action: Grid med HORIZONTAL, spacing=50
Outcome: -2.3% DD, recovery efter 18h

Counterfactual A:
────────────────
Action: Grid med TREND_ALIGNED, spacing=50
Simulated: -1.1% DD, recovery efter 8h
Advantage: +1.2% DD, -10h recovery
→ TREND_ALIGNED hade varit bättre

Counterfactual B:
────────────────
Action: INTE aktivera grid (håll initial)
Simulated: Stoppas ut vid -1.5%
Advantage: -0.8% (sämre)
→ Grid var rätt beslut

Counterfactual C:
────────────────
Action: HORIZONTAL med spacing=75
Simulated: -1.8% DD, 4 nivåer istället för 6
Advantage: +0.5% DD, färre nivåer
→ Större spacing hade varit bättre
```

### Advantage-Weighted Training

```python
class AdvantageWeightedTrainer:
    """
    Träna modellen att föredra actions med positiv advantage.
    """

    def train(self, model, counterfactuals, epochs=50):
        optimizer = torch.optim.Adam(model.parameters(), lr=0.0001)

        for epoch in range(epochs):
            for cf in counterfactuals:
                advantage = cf['comparison']['advantage']

                # Endast förstärk positiva advantages
                if advantage > 0:
                    weight = min(advantage * 10, 5.0)  # Cappa vikten

                    prediction = model(cf['state'])
                    target = encode_action(cf['action'])

                    loss = weight * F.mse_loss(prediction, target)
                    loss.backward()
                    optimizer.step()
                    optimizer.zero_grad()

            # Evaluera på valideringsdata
            if epoch % 10 == 0:
                val_performance = self.evaluate(model)
                print(f"Epoch {epoch}: Val performance = {val_performance}")
```

## 5.6 Shadow Mode (v2.0)

### Koncept

Innan ny modell går live, kör den parallellt utan att faktiskt handla.

```
┌─────────────────────────────────────────────────────┐
│                   LIVE TRADING                       │
│  ┌──────────────────┐    ┌──────────────────┐       │
│  │ Production Model │    │   Shadow Model   │       │
│  │ (faktisk handel) │    │ (endast loggning)│       │
│  └────────┬─────────┘    └────────┬─────────┘       │
│           │                       │                  │
│           ▼                       ▼                  │
│  ┌──────────────────┐    ┌──────────────────┐       │
│  │  Execute Orders  │    │  Log Decisions   │       │
│  └──────────────────┘    └──────────────────┘       │
│           │                       │                  │
│           └───────────┬───────────┘                  │
│                       ▼                              │
│              ┌──────────────────┐                    │
│              │ Compare Outcomes │                    │
│              └──────────────────┘                    │
└─────────────────────────────────────────────────────┘
```

### Implementation

```cpp
// I Gridzilla EA
class ShadowModeManager {
private:
    bool shadow_mode_enabled;
    long shadow_model_handle;
    ShadowLog shadow_log;

public:
    void OnTick() {
        if (!shadow_mode_enabled) return;

        MarketState state = GetCurrentState();
        PositionState position = GetPositionState();

        // Kör shadow model
        ONNXDecision shadow_decision;
        RunShadowInference(state, position, shadow_decision);

        // Logga vad shadow hade gjort
        LogShadowDecision(state, shadow_decision);
    }

    void LogShadowDecision(MarketState& state, ONNXDecision& shadow) {
        ShadowLogEntry entry;
        entry.timestamp = TimeCurrent();
        entry.state = state;
        entry.shadow_decision = shadow;
        entry.production_decision = last_production_decision;

        // Skillnader att analysera
        entry.entry_differs = (shadow.allow_entry != production_decision.allow_entry);
        entry.structure_differs = (shadow.grid_structure != production_decision.grid_structure);
        entry.spacing_diff = shadow.base_spacing - production_decision.base_spacing;

        shadow_log.Add(entry);
    }
};
```

### Shadow Performance Analysis

```python
def analyze_shadow_performance(shadow_log, price_data):
    """
    Analysera hur shadow model hade presterat vs production.
    """
    results = {
        'shadow_theoretical_pnl': 0,
        'production_actual_pnl': 0,
        'decisions_compared': 0,
        'shadow_better_count': 0
    }

    for entry in shadow_log:
        # Simulera shadow decision med faktiska priser
        shadow_outcome = simulate_decision(
            entry.state,
            entry.shadow_decision,
            price_data[entry.timestamp:]
        )

        # Hämta faktiskt utfall för production
        production_outcome = get_actual_outcome(entry.timestamp)

        results['shadow_theoretical_pnl'] += shadow_outcome.pnl
        results['production_actual_pnl'] += production_outcome.pnl
        results['decisions_compared'] += 1

        if shadow_outcome.pnl > production_outcome.pnl:
            results['shadow_better_count'] += 1

    # Beräkna ratio
    results['shadow_better_ratio'] = (
        results['shadow_better_count'] / results['decisions_compared']
    )

    return results

def should_promote_shadow(results, min_improvement=1.10, min_better_ratio=0.55):
    """
    Avgör om shadow model ska ersätta production.
    """
    pnl_improvement = results['shadow_theoretical_pnl'] / max(results['production_actual_pnl'], 1)
    better_ratio = results['shadow_better_ratio']

    if pnl_improvement >= min_improvement and better_ratio >= min_better_ratio:
        print(f"✓ Shadow model recommended for promotion")
        print(f"  PnL improvement: {pnl_improvement:.1%}")
        print(f"  Better decisions: {better_ratio:.1%}")
        return True
    else:
        print(f"✗ Shadow model not ready")
        print(f"  PnL improvement: {pnl_improvement:.1%} (need {min_improvement:.1%})")
        print(f"  Better decisions: {better_ratio:.1%} (need {min_better_ratio:.1%})")
        return False
```

### Kontinuerlig förbättringscykel

```
┌────────────────────────────────────────────────────────────┐
│                    TRAINING CYCLE                           │
│                                                             │
│  ┌─────────┐     ┌─────────┐     ┌─────────┐               │
│  │  Rule-  │     │Imitation│     │ Initial │               │
│  │  Based  │────►│Learning │────►│  ONNX   │               │
│  └─────────┘     └─────────┘     └────┬────┘               │
│                                       │                     │
│                                       ▼                     │
│  ┌─────────┐     ┌─────────┐     ┌─────────┐               │
│  │  Live   │◄────│ Shadow  │◄────│Counter- │               │
│  │ Trading │     │  Mode   │     │factual  │               │
│  └────┬────┘     └─────────┘     └─────────┘               │
│       │                                                     │
│       ▼                                                     │
│  ┌─────────┐     ┌─────────┐     ┌─────────┐               │
│  │ Collect │────►│Generate │────►│ Retrain │               │
│  │Live Data│     │ CFs     │     │ Model   │───► Shadow    │
│  └─────────┘     └─────────┘     └─────────┘               │
│                                                             │
└────────────────────────────────────────────────────────────┘
```

---

# Del 6: Felhantering & Robusthet

## 6.1 Connection & Execution Errors

```cpp
enum ExecutionError {
    ERR_NONE = 0,
    ERR_REQUOTE,
    ERR_SLIPPAGE,
    ERR_TIMEOUT,
    ERR_INVALID_PRICE,
    ERR_NO_MONEY,
    ERR_MARKET_CLOSED,
    ERR_CONNECTION_LOST
};

struct RetryConfig {
    int max_retries = 3;
    int retry_delay_ms = 1000;
    double max_slippage_pips = 3.0;
    bool allow_requote = true;
};

ExecutionResult ExecuteOrderWithRetry(OrderRequest& request, RetryConfig& config) {
    for (int attempt = 0; attempt < config.max_retries; attempt++) {
        // Uppdatera pris före varje försök
        request.price = GetCurrentPrice(request.type);

        // Försök exekvera
        bool success = OrderSend(request.request, request.result);

        if (success) {
            // Kontrollera slippage
            double slippage = MathAbs(request.result.price - request.price) / Point / 10;
            if (slippage > config.max_slippage_pips) {
                Log("WARNING: High slippage: " + DoubleToString(slippage) + " pips");
            }
            return {true, ERR_NONE, request.result};
        }

        // Hantera specifika fel
        int error = GetLastError();

        switch (error) {
            case TRADE_RETCODE_REQUOTE:
                if (config.allow_requote && attempt < config.max_retries - 1) {
                    Log("Requote received, retrying...");
                    Sleep(config.retry_delay_ms);
                    continue;
                }
                return {false, ERR_REQUOTE, request.result};

            case TRADE_RETCODE_TIMEOUT:
                Log("Timeout, retrying...");
                Sleep(config.retry_delay_ms * 2);
                continue;

            case TRADE_RETCODE_NO_MONEY:
                Log("Insufficient funds");
                return {false, ERR_NO_MONEY, request.result};

            case TRADE_RETCODE_MARKET_CLOSED:
                Log("Market closed");
                return {false, ERR_MARKET_CLOSED, request.result};

            default:
                Log("Execution error: " + IntegerToString(error));
                Sleep(config.retry_delay_ms);
                continue;
        }
    }

    return {false, ERR_TIMEOUT, request.result};
}
```

## 6.2 Partial Fill Handling

```cpp
void HandlePartialFill(ulong order_id, double requested_volume, double filled_volume) {
    if (filled_volume < requested_volume * 0.99) {  // Mer än 1% saknas
        double remaining = requested_volume - filled_volume;

        Log("Partial fill detected. Requested: " + DoubleToString(requested_volume) +
            ", Filled: " + DoubleToString(filled_volume));

        // Alternativ 1: Acceptera partial fill
        // Uppdatera position manager med faktisk volym
        position_manager.UpdateActualVolume(order_id, filled_volume);

        // Alternativ 2: Försök fylla resten
        if (remaining >= SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN)) {
            OrderRequest fill_request;
            fill_request.volume = remaining;
            ExecuteOrderWithRetry(fill_request, retry_config);
        }
    }
}
```

## 6.3 State Recovery (efter restart)

```cpp
// Spara state periodiskt
void SaveStateToFile() {
    string filename = "ea_state_" + Symbol() + ".bin";
    int handle = FileOpen(filename, FILE_WRITE|FILE_BIN);

    // Serialisera kritisk state
    FileWriteStruct(handle, position_state);
    FileWriteStruct(handle, grid_state);
    FileWriteInteger(handle, current_grid_structure);
    FileWriteDouble(handle, average_entry_price);

    FileClose(handle);
}

// Återställ state vid startup
bool LoadStateFromFile() {
    string filename = "ea_state_" + Symbol() + ".bin";

    if (!FileIsExist(filename)) {
        return false;  // Ingen state att återställa
    }

    int handle = FileOpen(filename, FILE_READ|FILE_BIN);

    // Deserialisera
    FileReadStruct(handle, position_state);
    FileReadStruct(handle, grid_state);
    current_grid_structure = FileReadInteger(handle);
    average_entry_price = FileReadDouble(handle);

    FileClose(handle);

    // Verifiera mot faktiska positioner
    return ValidateStateAgainstPositions();
}

bool ValidateStateAgainstPositions() {
    // Kontrollera att sparad state matchar faktiska positioner i MT5
    int actual_positions = CountOpenPositions();

    if (actual_positions != position_state.open_levels) {
        Log("WARNING: State mismatch - recalculating from positions");
        RecalculateStateFromPositions();
    }

    return true;
}
```

---

# Del 7: Loggning & Monitoring

## 7.1 Loggningsnivåer

```cpp
enum LogLevel {
    LOG_DEBUG = 0,
    LOG_INFO = 1,
    LOG_WARNING = 2,
    LOG_ERROR = 3,
    LOG_CRITICAL = 4
};

LogLevel current_log_level = LOG_INFO;

void Log(string message, LogLevel level = LOG_INFO) {
    if (level < current_log_level) return;

    string prefix;
    switch (level) {
        case LOG_DEBUG:    prefix = "[DEBUG] "; break;
        case LOG_INFO:     prefix = "[INFO] "; break;
        case LOG_WARNING:  prefix = "[WARN] "; break;
        case LOG_ERROR:    prefix = "[ERROR] "; break;
        case LOG_CRITICAL: prefix = "[CRIT] "; break;
    }

    string timestamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
    string full_message = timestamp + " " + prefix + message;

    // Skriv till MT5 journal
    Print(full_message);

    // Skriv till fil
    WriteToLogFile(full_message);

    // Alert för kritiska
    if (level >= LOG_ERROR) {
        Alert(Symbol() + ": " + message);
    }
}
```

## 7.2 Trade Journal

```cpp
struct TradeJournalEntry {
    datetime entry_time;
    datetime exit_time;
    string symbol;
    int direction;          // 1=long, -1=short
    int entry_mode;         // Entry typ
    double entry_price;
    double exit_price;
    double volume;
    double pnl_money;
    double pnl_pips;
    bool grid_used;
    int grid_levels;
    int grid_structure;
    double max_drawdown;
    double max_favorable;
    int bars_held;
    string exit_reason;     // TP, SL, Signal, Manual, etc.
};

void LogTradeToJournal(TradeJournalEntry& entry) {
    string filename = "trade_journal_" + entry.symbol + "_" +
                      TimeToString(TimeCurrent(), TIME_DATE) + ".csv";

    int handle = FileOpen(filename, FILE_WRITE|FILE_CSV|FILE_COMMON, ',');

    // Skriv entry
    FileWrite(handle,
        TimeToString(entry.entry_time),
        TimeToString(entry.exit_time),
        entry.symbol,
        entry.direction == 1 ? "LONG" : "SHORT",
        EntryModeToString(entry.entry_mode),
        entry.entry_price,
        entry.exit_price,
        entry.volume,
        entry.pnl_money,
        entry.pnl_pips,
        entry.grid_used ? "YES" : "NO",
        entry.grid_levels,
        GridStructureToString(entry.grid_structure),
        entry.max_drawdown,
        entry.max_favorable,
        entry.bars_held,
        entry.exit_reason
    );

    FileClose(handle);
}
```

## 7.3 Performance Metrics

```cpp
struct PerformanceMetrics {
    // Grundläggande
    int total_trades;
    int winning_trades;
    int losing_trades;
    double win_rate;

    // P/L
    double total_profit;
    double total_loss;
    double net_profit;
    double profit_factor;
    double average_win;
    double average_loss;
    double expectancy;

    // Risk
    double max_drawdown_pct;
    double max_drawdown_duration_hours;
    double sharpe_ratio;
    double sortino_ratio;
    double calmar_ratio;

    // Grid-specifikt
    int trades_without_grid;
    int trades_with_grid;
    double grid_win_rate;
    double avg_grid_levels_used;
    double avg_grid_duration_hours;
};

void CalculateMetrics(TradeJournalEntry& trades[], PerformanceMetrics& metrics) {
    int n = ArraySize(trades);
    if (n == 0) return;

    metrics.total_trades = n;

    double equity_curve[];
    ArrayResize(equity_curve, n + 1);
    equity_curve[0] = 10000;  // Starting equity

    for (int i = 0; i < n; i++) {
        equity_curve[i + 1] = equity_curve[i] + trades[i].pnl_money;

        if (trades[i].pnl_money > 0) {
            metrics.winning_trades++;
            metrics.total_profit += trades[i].pnl_money;
        } else {
            metrics.losing_trades++;
            metrics.total_loss += MathAbs(trades[i].pnl_money);
        }

        if (trades[i].grid_used) {
            metrics.trades_with_grid++;
        } else {
            metrics.trades_without_grid++;
        }
    }

    metrics.win_rate = (double)metrics.winning_trades / n * 100;
    metrics.net_profit = metrics.total_profit - metrics.total_loss;
    metrics.profit_factor = metrics.total_loss > 0 ?
                            metrics.total_profit / metrics.total_loss : 999;
    metrics.average_win = metrics.winning_trades > 0 ?
                          metrics.total_profit / metrics.winning_trades : 0;
    metrics.average_loss = metrics.losing_trades > 0 ?
                           metrics.total_loss / metrics.losing_trades : 0;
    metrics.expectancy = (metrics.win_rate/100 * metrics.average_win) -
                         ((100-metrics.win_rate)/100 * metrics.average_loss);

    // Beräkna max drawdown från equity curve
    metrics.max_drawdown_pct = CalculateMaxDrawdown(equity_curve);

    // Sharpe ratio (förenklad, antar riskfri ränta = 0)
    double returns[];
    CalculateReturns(equity_curve, returns);
    metrics.sharpe_ratio = MathMean(returns) / MathStdDev(returns) * MathSqrt(252);
}
```

---

# Del 8: Testning

## 8.1 Backtesting-strategi

### Testperioder

```
Träningsdata:    2018-01-01 till 2022-12-31 (5 år)
Valideringsdata: 2023-01-01 till 2023-06-30 (6 månader)
Testdata:        2023-07-01 till 2024-06-30 (1 år, out-of-sample)

Walk-Forward:
┌─────────┬─────────┬─────────┬─────────┬─────────┐
│Train    │Train    │Train    │Train    │Train    │
│Window 1 │Window 2 │Window 3 │Window 4 │Window 5 │
├─────────┼─────────┼─────────┼─────────┼─────────┤
│  Test 1 │  Test 2 │  Test 3 │  Test 4 │  Test 5 │
└─────────┴─────────┴─────────┴─────────┴─────────┘
         ──────────────────────────────────────────►
                          Tid
```

### MT5 Backtest Settings

```
Modell:              Every tick based on real ticks
Initial deposit:     $10,000
Leverage:            1:100
Spread:              Current (eller fixed med margin)
Commission:          $7 per round lot (om tillämpligt)
Slippage:            Max 3 pips
```

## 8.2 Monte Carlo Simulering

```python
def monte_carlo_simulation(trades, n_simulations=1000):
    """
    Simulera olika ordningar av trades för att förstå
    sannolikhetsfördelning av utfall.
    """
    results = {
        'final_equity': [],
        'max_drawdown': [],
        'sharpe_ratio': []
    }

    trade_pnls = [t.pnl_money for t in trades]

    for _ in range(n_simulations):
        # Slumpa ordning
        shuffled = np.random.permutation(trade_pnls)

        # Beräkna equity curve
        equity = np.cumsum(shuffled) + 10000

        # Metrics
        results['final_equity'].append(equity[-1])
        results['max_drawdown'].append(calculate_max_dd(equity))
        results['sharpe_ratio'].append(calculate_sharpe(shuffled))

    # Analysera distribution
    print(f"Final Equity:")
    print(f"  5th percentile:  ${np.percentile(results['final_equity'], 5):.0f}")
    print(f"  50th percentile: ${np.percentile(results['final_equity'], 50):.0f}")
    print(f"  95th percentile: ${np.percentile(results['final_equity'], 95):.0f}")

    print(f"\nMax Drawdown:")
    print(f"  5th percentile:  {np.percentile(results['max_drawdown'], 5):.1f}%")
    print(f"  50th percentile: {np.percentile(results['max_drawdown'], 50):.1f}%")
    print(f"  95th percentile: {np.percentile(results['max_drawdown'], 95):.1f}%")

    return results
```

## 8.3 Stress Testing

### Scenarios att testa

```
1. Flash Crash (2010-05-06 typ)
   - 10% rörelse på 5 minuter
   - Spread ökar 10x
   - Slippage ökar dramatiskt

2. Brexit (2016-06-24)
   - 10%+ rörelse över natten
   - Gaps i pris
   - Extrem volatilitet flera dagar

3. SNB Shock (2015-01-15)
   - 30%+ rörelse momentant
   - Många mäklare stoppade trading
   - Negativt equity möjligt

4. COVID Crash (2020-03)
   - Hög volatilitet veckor i rad
   - Korrelationer bryter ned
   - VIX > 80

5. Low Volatility Grind
   - ATR minskar 50%+
   - Tight ranges
   - False breakouts
```

### Implementation

```cpp
struct StressTestParams {
    double volatility_multiplier;
    double spread_multiplier;
    double slippage_multiplier;
    double gap_probability;
    double gap_size_atr;
};

void RunStressTest(StressTestParams& params) {
    // Modifiera marknadssimulering
    stress_mode = true;
    stress_params = params;

    // Kör backtest
    RunBacktest();

    // Analysera resultat under stress
    AnalyzeStressResults();

    stress_mode = false;
}
```

---

# Del 9: Deployment & Drift

## 9.1 Systemkrav

```
Minimum VPS Specifikation:
- CPU:     2+ cores
- RAM:     4GB
- Storage: 50GB SSD
- Network: Stabil, låg latency till broker
- OS:      Windows Server 2016/2019/2022

Rekommenderat:
- CPU:     4 cores
- RAM:     8GB
- Storage: 100GB SSD
- Location: Samma datacenter som broker (eller nära)
```

## 9.2 Installation

```
1. Installera MT5 Terminal
   - Ladda ned från broker
   - Installera och logga in

2. Kopiera EA-filer
   - Gridzilla.mq5 → MQL5/Experts/
   - policy_v1.onnx → MQL5/Files/

3. Kompilera EA
   - Öppna MetaEditor
   - Kompilera Gridzilla.mq5
   - Verifiera inga errors

4. Konfigurera EA
   - Dra EA till chart
   - Sätt parametrar
   - Aktivera "Allow Algo Trading"

5. Verifiera
   - Kontrollera att ONNX laddar korrekt
   - Kör på demo först
```

## 9.3 Konfigurationsparametrar

```cpp
// User-facing parametrar (minimala, enkla)
input group "=== Grundläggande ==="
input double RiskPerTrade = 1.0;           // Risk per trade (%)
input double MaxDrawdownPercent = 15.0;    // Max drawdown (%)
input int    MaxGridLevels = 6;            // Max grid-nivåer

input group "=== Tidsfilter ==="
input bool   TradeAsianSession = false;    // Handla Asian session?
input bool   TradeEuropeanSession = true;  // Handla European session?
input bool   TradeAmericanSession = true;  // Handla American session?

input group "=== Avancerat ==="
input string ONNXModelFile = "policy_v1.onnx";  // ONNX-modell
input int    MagicNumber = 123456;              // Magic number
input bool   DebugMode = false;                 // Debug-läge
```

## 9.4 Monitoring i drift

```cpp
// Periodisk hälsokontroll
void OnTimer() {
    static datetime last_health_check = 0;

    if (TimeCurrent() - last_health_check > 300) {  // Var 5:e minut
        last_health_check = TimeCurrent();

        // Kontrollera anslutning
        if (!TerminalInfoInteger(TERMINAL_CONNECTED)) {
            Log("CONNECTION LOST", LOG_CRITICAL);
            Alert("Gridzilla: Connection lost!");
        }

        // Kontrollera equity
        double equity = AccountInfoDouble(ACCOUNT_EQUITY);
        double balance = AccountInfoDouble(ACCOUNT_BALANCE);
        double dd_pct = (balance - equity) / balance * 100;

        if (dd_pct > MaxDrawdownPercent * 0.8) {
            Log("Approaching max drawdown: " + DoubleToString(dd_pct) + "%", LOG_WARNING);
        }

        // Logga status
        LogStatus();
    }
}

void LogStatus() {
    Log("=== Status Update ===", LOG_INFO);
    Log("Equity: $" + DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2));
    Log("Open positions: " + IntegerToString(PositionsTotal()));
    Log("Grid active: " + (position_state.grid_active ? "YES" : "NO"));
    if (position_state.grid_active) {
        Log("Grid levels: " + IntegerToString(position_state.open_levels));
        Log("Unrealized P/L: " + DoubleToString(position_state.unrealized_pnl, 2));
    }
}
```

---

# Del 10: Utvecklingsfaser med Deliverables

## Fas 1: Arkitektur & Grundstruktur
**Mål:** Fungerande EA-skelett med alla moduler definierade

### Deliverables:
- [ ] MQL5 projektstruktur
- [ ] Klass-definitioner för alla moduler
- [ ] Kompilerande kod (utan funktionalitet)
- [ ] Enhetstester för utility-funktioner
- [ ] Dokumentation av arkitektur

### Definition of Done:
- EA kompilerar utan errors eller warnings
- Alla moduler existerar som tomma skal
- README med arkitekturbeskrivning

---

## Fas 2: MarketStateManager
**Mål:** Fullständig implementation av alla marknadsstate-beräkningar

### Deliverables:
- [ ] Trend strength beräkning
- [ ] Trend slope och curvature
- [ ] Volatility level och change
- [ ] Mean reversion score
- [ ] Spread z-score
- [ ] Session identification
- [ ] Multi-timeframe aggregering
- [ ] Ringbuffers för historik

### Definition of Done:
- Alla indikatorer returnerar rimliga värden
- Backtest visar korrekt state över tid
- Visuell verifiering med on-chart display

---

## Fas 3: EntryEngine
**Mål:** Selektiv entry-logik med alla filter

### Deliverables:
- [ ] Alla entry modes implementerade
- [ ] Entry filter (spread, volatility, news, etc.)
- [ ] Position sizing baserat på risk
- [ ] Order execution med error handling
- [ ] Baseline entry-strategi (utan AI)

### Definition of Done:
- Entry sker endast när villkor uppfylls
- Filters blockerar korrekt
- 100+ simulated entries utan execution errors

---

## Fas 4: PositionManager & GridEngine
**Mål:** Komplett grid-funktionalitet med alla strukturer

### Deliverables:
- [ ] PositionManager state tracking
- [ ] Alla 6 grid-strukturer
- [ ] Grid activation logic
- [ ] Grid transitions
- [ ] Lot calculation
- [ ] Breakeven calculation
- [ ] Exit logic

### Definition of Done:
- Varje grid-struktur testad isolerat
- Transitions fungerar korrekt
- Calculations verifierade med hand-beräkningar

---

## Fas 5: RiskEngine & SafetyController
**Mål:** Robust risk- och säkerhetshantering

### Deliverables:
- [ ] Hårda begränsningar
- [ ] Dynamiska gränser
- [ ] Katastrofdetektering
- [ ] Nödstängningslogik
- [ ] State recovery efter restart

### Definition of Done:
- Hårda gränser kan INTE kringgås
- Stress-test klaras utan katastrofala förluster
- State recovery fungerar efter simulerat crash

---

## Fas 6: ONNX Integration
**Mål:** Fungerande ONNX runtime med fallback

### Deliverables:
- [ ] ONNX model loading
- [ ] Input normalisering
- [ ] Inference execution
- [ ] Output parsing och validering
- [ ] Fallback till regelbaserad strategi
- [ ] Dummy ONNX-modell för test

### Definition of Done:
- ONNX inference returnerar valid output
- Fallback aktiveras vid ONNX-fel
- Latency < 10ms per inference

---

## Fas 7: AI-träning
**Mål:** Tränad AI-policy som outperformar baseline

### Deliverables:
- [ ] Datainsamlingspipeline
- [ ] Feature engineering
- [ ] Training infrastructure
- [ ] Supervised learning implementation
- [ ] Reward function design
- [ ] RL training (optional)
- [ ] ONNX export pipeline
- [ ] Model versioning

### Definition of Done:
- ONNX-modell klarar alla validationstester
- Outperformar regelbaserad strategi på valideringsdata
- Reproducerbar träningsprocess

---

## Fas 8: Testning & Optimering
**Mål:** Validerad strategi med robusta resultat

### Deliverables:
- [ ] 5-års backtest
- [ ] Walk-forward analys
- [ ] Out-of-sample test
- [ ] Monte Carlo simulering
- [ ] Stress testing
- [ ] Parameter sensitivity analysis
- [ ] Performance rapport

### Definition of Done:
- Positiv expectancy på alla testperioder
- Max drawdown < 15% i 95% av Monte Carlo simulations
- Konsistenta resultat över olika marknadsregimer

---

## Fas 9: Produktifiering
**Mål:** Produktionsklar EA

### Deliverables:
- [ ] Parametrar förenkling
- [ ] Användardokumentation
- [ ] Installationsguide
- [ ] VPS-konfigurationsguide
- [ ] Troubleshooting guide
- [ ] Förpackning och distribution

### Definition of Done:
- En icke-teknisk användare kan installera och köra EA
- Dokumentation täcker alla vanliga frågor
- Support-process definierad

---

# Del 11: Framgångskriterier

## Kvantitativa mål

| Metric | Mål | Minimum acceptabelt |
|--------|-----|---------------------|
| Max Drawdown | < 10% | < 15% |
| Win Rate (utan grid) | > 55% | > 50% |
| Profit Factor | > 1.5 | > 1.2 |
| Sharpe Ratio | > 1.0 | > 0.5 |
| Grid Activation Rate | < 30% | < 50% |
| Avg Grid Duration | < 12h | < 24h |
| Recovery Time (avg) | < 5 trades | < 10 trades |

## Kvalitativa mål

- **Reproducerbarhet:** Samma resultat vid upprepade körningar
- **Stabilitet:** Inga crashes under 1000+ timmar körning
- **Förståelighet:** Alla beslut kan förklaras och loggas
- **Anpassningsbarhet:** ONNX kan bytas utan kod-ändringar

---

# Del 12: Riskwarning & Disclaimer

## Viktigt att förstå

1. **Grid/Martingale är riskabelt** – oavsett AI-optimering kan tail events orsaka stora förluster

2. **Backtests ≠ framtida resultat** – historisk performance garanterar inget

3. **AI är inte magisk** – ONNX-modellen gör misstag, särskilt i nya marknadsregimer

4. **Leverage multiplicerar risk** – 1:100 leverage kan utplåna konto snabbt

5. **VPS/broker-problem händer** – connection loss under kritiska moment kan orsaka förluster

## Rekommendationer

- Starta med demo-konto i minst 3 månader
- Använd endast kapital du har råd att förlora
- Diversifiera – lägg inte alla ägg i en korg
- Övervaka EA regelbundet, även om den är "automatisk"
- Ha en manuell nödplan om allt går fel

---

# Appendix A: Ordlista

| Term | Förklaring |
|------|-----------|
| ATR | Average True Range - volatilitetsmått |
| DD | Drawdown - förlust från peak |
| EA | Expert Advisor - automatisk trading-bot i MT5 |
| Grid | Serie av orders på olika prisnivåer |
| Lot | Handelsstorlek (1 lot = 100,000 enheter) |
| Martingale | Strategi att dubbla insats efter förlust |
| MQL5 | MetaQuotes Language 5 - programspråk för MT5 |
| ONNX | Open Neural Network Exchange - AI-modellformat |
| Pip | Point in Percentage - prisrörelse enhet |
| Slippage | Skillnad mellan förväntad och faktisk fill-pris |
| TP/SL | Take Profit / Stop Loss |

---

# Appendix B: Filstruktur

```
Gridzilla/
├── MQL5/
│   ├── Experts/
│   │   └── Gridzilla.mq5              # Huvud-EA
│   ├── Include/
│   │   ├── Gridzilla/
│   │   │   ├── MarketStateManager.mqh
│   │   │   ├── EntryEngine.mqh
│   │   │   ├── PositionManager.mqh
│   │   │   ├── GridEngine.mqh
│   │   │   ├── RiskEngine.mqh
│   │   │   ├── SafetyController.mqh
│   │   │   ├── ONNXBridge.mqh
│   │   │   ├── Logger.mqh
│   │   │   └── Types.mqh           # Structs, enums, constants
│   │   └── Utilities/
│   │       ├── Statistics.mqh
│   │       └── RingBuffer.mqh
│   └── Files/
│       └── policy_v1.onnx          # AI-modell
├── Training/
│   ├── data/
│   │   └── training_data.csv
│   ├── models/
│   │   └── policy_v1.pt
│   ├── train.py
│   ├── export_onnx.py
│   └── requirements.txt
├── Docs/
│   ├── PROJEKTPLAN.md              # Detta dokument
│   ├── INSTALLATION.md
│   ├── TROUBLESHOOTING.md
│   └── ARCHITECTURE.md
└── Tests/
    ├── test_indicators.mq5
    ├── test_grid_structures.mq5
    └── test_risk_engine.mq5
```

---

*Dokument skapat: 2024-12-13*
*Senast uppdaterad: 2024-12-13*
