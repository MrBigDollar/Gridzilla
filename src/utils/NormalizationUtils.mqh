//+------------------------------------------------------------------+
//|                                         NormalizationUtils.mqh    |
//|                                Copyright 2024, Gridzilla Project  |
//+------------------------------------------------------------------+
#property copyright "Gridzilla Project"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| ONNXInputRanges - Definierade intervall för ONNX-input            |
//|                                                                   |
//| Enligt CLAUDE.md tensor-specifikation:                            |
//| Input (state_input): Shape [1, 12], float32                       |
//+------------------------------------------------------------------+
struct ONNXInputRanges {
    // Index 0-2: Trend
    double trend_strength_min;     // 0
    double trend_strength_max;     // 1
    double slope_min;              // -1
    double slope_max;              // 1
    double curvature_min;          // -1
    double curvature_max;          // 1

    // Index 3-4: Volatility
    double volatility_level_min;   // 0
    double volatility_level_max;   // 1
    double volatility_change_min;  // -1
    double volatility_change_max;  // 1

    // Index 5-7: Market context
    double mean_reversion_min;     // 0
    double mean_reversion_max;     // 1
    double spread_zscore_min;      // -3
    double spread_zscore_max;      // 3
    double session_id_min;         // 0
    double session_id_max;         // 4

    // Index 8-11: Grid state
    double grid_active_min;        // 0
    double grid_active_max;        // 1
    double open_levels_min;        // 0
    double open_levels_max;        // 8
    double unrealized_dd_min;      // 0
    double unrealized_dd_max;      // 1
    double dd_velocity_min;        // -1
    double dd_velocity_max;        // 1

    //--- Konstruktor med standardvärden
    ONNXInputRanges() {
        trend_strength_min = 0.0;   trend_strength_max = 1.0;
        slope_min = -1.0;           slope_max = 1.0;
        curvature_min = -1.0;       curvature_max = 1.0;
        volatility_level_min = 0.0; volatility_level_max = 1.0;
        volatility_change_min = -1.0; volatility_change_max = 1.0;
        mean_reversion_min = 0.0;   mean_reversion_max = 1.0;
        spread_zscore_min = -3.0;   spread_zscore_max = 3.0;
        session_id_min = 0.0;       session_id_max = 4.0;
        grid_active_min = 0.0;      grid_active_max = 1.0;
        open_levels_min = 0.0;      open_levels_max = 8.0;
        unrealized_dd_min = 0.0;    unrealized_dd_max = 1.0;
        dd_velocity_min = -1.0;     dd_velocity_max = 1.0;
    }
};

//+------------------------------------------------------------------+
//| ONNXOutputRanges - Definierade intervall för ONNX-output          |
//|                                                                   |
//| Enligt CLAUDE.md tensor-specifikation:                            |
//| Output (decision_output): Shape [1, 12], float32                  |
//+------------------------------------------------------------------+
struct ONNXOutputRanges {
    // Index 0-3: Entry decisions
    double allow_entry_min;        // 0
    double allow_entry_max;        // 1
    double entry_mode_min;         // 0
    double entry_mode_max;         // 4
    double direction_min;          // -1
    double direction_max;          // 1
    double initial_risk_min;       // 0.5
    double initial_risk_max;       // 2.0

    // Index 4-6: Grid decisions
    double activate_grid_min;      // 0
    double activate_grid_max;      // 1
    double grid_structure_min;     // 0
    double grid_structure_max;     // 5
    double grid_action_min;        // 0
    double grid_action_max;        // 4

    // Index 7-11: Grid parameters
    double base_spacing_min;       // 20
    double base_spacing_max;       // 100
    double spacing_growth_min;     // 1.0
    double spacing_growth_max;     // 1.5
    double lot_growth_min;         // 1.1
    double lot_growth_max;         // 2.0
    double max_levels_min;         // 3
    double max_levels_max;         // 8
    double confidence_min;         // 0
    double confidence_max;         // 1

    //--- Konstruktor med standardvärden
    ONNXOutputRanges() {
        allow_entry_min = 0.0;      allow_entry_max = 1.0;
        entry_mode_min = 0.0;       entry_mode_max = 4.0;
        direction_min = -1.0;       direction_max = 1.0;
        initial_risk_min = 0.5;     initial_risk_max = 2.0;
        activate_grid_min = 0.0;    activate_grid_max = 1.0;
        grid_structure_min = 0.0;   grid_structure_max = 5.0;
        grid_action_min = 0.0;      grid_action_max = 4.0;
        base_spacing_min = 20.0;    base_spacing_max = 100.0;
        spacing_growth_min = 1.0;   spacing_growth_max = 1.5;
        lot_growth_min = 1.1;       lot_growth_max = 2.0;
        max_levels_min = 3.0;       max_levels_max = 8.0;
        confidence_min = 0.0;       confidence_max = 1.0;
    }
};

//+------------------------------------------------------------------+
//| CNormalizationUtils - Normalisering för ONNX-integration          |
//|                                                                   |
//| Syfte: Säkerställa att alla värden som skickas till ONNX-modellen |
//| är korrekt normaliserade och validerade.                          |
//+------------------------------------------------------------------+
class CNormalizationUtils {
public:
    //+------------------------------------------------------------------+
    //| NormalizeValue - Normalisera ett värde till nytt intervall        |
    //|                                                                   |
    //| value: Råvärde                                                    |
    //| raw_min, raw_max: Ursprungligt intervall                          |
    //| target_min, target_max: Mål-intervall                             |
    //+------------------------------------------------------------------+
    static double NormalizeValue(double value,
                                 double raw_min, double raw_max,
                                 double target_min, double target_max) {
        double raw_range = raw_max - raw_min;
        if (MathAbs(raw_range) < 1e-10) return target_min;

        double normalized = (value - raw_min) / raw_range;
        return target_min + normalized * (target_max - target_min);
    }

    //+------------------------------------------------------------------+
    //| DenormalizeValue - Konvertera från ONNX-intervall till rå         |
    //|                                                                   |
    //| value: ONNX-output                                                |
    //| onnx_min, onnx_max: ONNX-intervall                                |
    //| target_min, target_max: Mål-intervall för användning              |
    //+------------------------------------------------------------------+
    static double DenormalizeValue(double value,
                                   double onnx_min, double onnx_max,
                                   double target_min, double target_max) {
        double onnx_range = onnx_max - onnx_min;
        if (MathAbs(onnx_range) < 1e-10) return target_min;

        double normalized = (value - onnx_min) / onnx_range;
        return target_min + normalized * (target_max - target_min);
    }

    //+------------------------------------------------------------------+
    //| ClampToRange - Begränsa värde till specifikt intervall            |
    //+------------------------------------------------------------------+
    static double ClampToRange(double value, double min_val, double max_val) {
        if (value < min_val) return min_val;
        if (value > max_val) return max_val;
        return value;
    }

    //+------------------------------------------------------------------+
    //| IsInValidRange - Kontrollera om värde är inom giltigt intervall   |
    //+------------------------------------------------------------------+
    static bool IsInValidRange(double value, double min_val, double max_val) {
        return (value >= min_val && value <= max_val);
    }

    //+------------------------------------------------------------------+
    //| NormalizeAndClamp - Normalisera och begränsa i ett steg           |
    //+------------------------------------------------------------------+
    static double NormalizeAndClamp(double value,
                                    double raw_min, double raw_max,
                                    double target_min, double target_max) {
        double normalized = NormalizeValue(value, raw_min, raw_max, target_min, target_max);
        return ClampToRange(normalized, target_min, target_max);
    }

    //+------------------------------------------------------------------+
    //| ValidateONNXInputArray - Validera ONNX input-array                |
    //|                                                                   |
    //| input: Array med 12 float-värden                                  |
    //| ranges: Referens till ONNXInputRanges                             |
    //| Returnerar true om alla värden är inom giltiga intervall          |
    //+------------------------------------------------------------------+
    static bool ValidateONNXInputArray(const float &arr[], const ONNXInputRanges &ranges) {
        if (ArraySize(arr) != 12) return false;

        // Validera varje index mot dess intervall
        if (!IsInValidRange(arr[0], ranges.trend_strength_min, ranges.trend_strength_max)) return false;
        if (!IsInValidRange(arr[1], ranges.slope_min, ranges.slope_max)) return false;
        if (!IsInValidRange(arr[2], ranges.curvature_min, ranges.curvature_max)) return false;
        if (!IsInValidRange(arr[3], ranges.volatility_level_min, ranges.volatility_level_max)) return false;
        if (!IsInValidRange(arr[4], ranges.volatility_change_min, ranges.volatility_change_max)) return false;
        if (!IsInValidRange(arr[5], ranges.mean_reversion_min, ranges.mean_reversion_max)) return false;
        if (!IsInValidRange(arr[6], ranges.spread_zscore_min, ranges.spread_zscore_max)) return false;
        if (!IsInValidRange(arr[7], ranges.session_id_min, ranges.session_id_max)) return false;
        if (!IsInValidRange(arr[8], ranges.grid_active_min, ranges.grid_active_max)) return false;
        if (!IsInValidRange(arr[9], ranges.open_levels_min, ranges.open_levels_max)) return false;
        if (!IsInValidRange(arr[10], ranges.unrealized_dd_min, ranges.unrealized_dd_max)) return false;
        if (!IsInValidRange(arr[11], ranges.dd_velocity_min, ranges.dd_velocity_max)) return false;

        return true;
    }

    //+------------------------------------------------------------------+
    //| ValidateONNXOutputArray - Validera ONNX output-array              |
    //+------------------------------------------------------------------+
    static bool ValidateONNXOutputArray(const float &output[], const ONNXOutputRanges &ranges) {
        if (ArraySize(output) != 12) return false;

        if (!IsInValidRange(output[0], ranges.allow_entry_min, ranges.allow_entry_max)) return false;
        if (!IsInValidRange(output[1], ranges.entry_mode_min, ranges.entry_mode_max)) return false;
        if (!IsInValidRange(output[2], ranges.direction_min, ranges.direction_max)) return false;
        if (!IsInValidRange(output[3], ranges.initial_risk_min, ranges.initial_risk_max)) return false;
        if (!IsInValidRange(output[4], ranges.activate_grid_min, ranges.activate_grid_max)) return false;
        if (!IsInValidRange(output[5], ranges.grid_structure_min, ranges.grid_structure_max)) return false;
        if (!IsInValidRange(output[6], ranges.grid_action_min, ranges.grid_action_max)) return false;
        if (!IsInValidRange(output[7], ranges.base_spacing_min, ranges.base_spacing_max)) return false;
        if (!IsInValidRange(output[8], ranges.spacing_growth_min, ranges.spacing_growth_max)) return false;
        if (!IsInValidRange(output[9], ranges.lot_growth_min, ranges.lot_growth_max)) return false;
        if (!IsInValidRange(output[10], ranges.max_levels_min, ranges.max_levels_max)) return false;
        if (!IsInValidRange(output[11], ranges.confidence_min, ranges.confidence_max)) return false;

        return true;
    }

    //+------------------------------------------------------------------+
    //| ClampONNXInputArray - Begränsa alla input-värden till giltiga     |
    //+------------------------------------------------------------------+
    static void ClampONNXInputArray(float &arr[], const ONNXInputRanges &ranges) {
        if (ArraySize(arr) != 12) return;

        arr[0] = (float)ClampToRange(arr[0], ranges.trend_strength_min, ranges.trend_strength_max);
        arr[1] = (float)ClampToRange(arr[1], ranges.slope_min, ranges.slope_max);
        arr[2] = (float)ClampToRange(arr[2], ranges.curvature_min, ranges.curvature_max);
        arr[3] = (float)ClampToRange(arr[3], ranges.volatility_level_min, ranges.volatility_level_max);
        arr[4] = (float)ClampToRange(arr[4], ranges.volatility_change_min, ranges.volatility_change_max);
        arr[5] = (float)ClampToRange(arr[5], ranges.mean_reversion_min, ranges.mean_reversion_max);
        arr[6] = (float)ClampToRange(arr[6], ranges.spread_zscore_min, ranges.spread_zscore_max);
        arr[7] = (float)ClampToRange(arr[7], ranges.session_id_min, ranges.session_id_max);
        arr[8] = (float)ClampToRange(arr[8], ranges.grid_active_min, ranges.grid_active_max);
        arr[9] = (float)ClampToRange(arr[9], ranges.open_levels_min, ranges.open_levels_max);
        arr[10] = (float)ClampToRange(arr[10], ranges.unrealized_dd_min, ranges.unrealized_dd_max);
        arr[11] = (float)ClampToRange(arr[11], ranges.dd_velocity_min, ranges.dd_velocity_max);
    }

    //+------------------------------------------------------------------+
    //| ClampONNXOutputArray - Begränsa alla output-värden till giltiga   |
    //+------------------------------------------------------------------+
    static void ClampONNXOutputArray(float &output[], const ONNXOutputRanges &ranges) {
        if (ArraySize(output) != 12) return;

        output[0] = (float)ClampToRange(output[0], ranges.allow_entry_min, ranges.allow_entry_max);
        output[1] = (float)ClampToRange(output[1], ranges.entry_mode_min, ranges.entry_mode_max);
        output[2] = (float)ClampToRange(output[2], ranges.direction_min, ranges.direction_max);
        output[3] = (float)ClampToRange(output[3], ranges.initial_risk_min, ranges.initial_risk_max);
        output[4] = (float)ClampToRange(output[4], ranges.activate_grid_min, ranges.activate_grid_max);
        output[5] = (float)ClampToRange(output[5], ranges.grid_structure_min, ranges.grid_structure_max);
        output[6] = (float)ClampToRange(output[6], ranges.grid_action_min, ranges.grid_action_max);
        output[7] = (float)ClampToRange(output[7], ranges.base_spacing_min, ranges.base_spacing_max);
        output[8] = (float)ClampToRange(output[8], ranges.spacing_growth_min, ranges.spacing_growth_max);
        output[9] = (float)ClampToRange(output[9], ranges.lot_growth_min, ranges.lot_growth_max);
        output[10] = (float)ClampToRange(output[10], ranges.max_levels_min, ranges.max_levels_max);
        output[11] = (float)ClampToRange(output[11], ranges.confidence_min, ranges.confidence_max);
    }

    //+------------------------------------------------------------------+
    //| CheckForNaN - Kontrollera om array innehåller NaN-värden          |
    //+------------------------------------------------------------------+
    static bool CheckForNaN(const float &values[]) {
        int size = ArraySize(values);
        for (int i = 0; i < size; i++) {
            if (MathIsValidNumber(values[i]) == false) {
                return true;  // Hittade NaN eller Inf
            }
        }
        return false;
    }

    //+------------------------------------------------------------------+
    //| ReplaceNaN - Ersätt NaN-värden med standardvärde                  |
    //+------------------------------------------------------------------+
    static void ReplaceNaN(float &values[], float default_value = 0.0f) {
        int size = ArraySize(values);
        for (int i = 0; i < size; i++) {
            if (MathIsValidNumber(values[i]) == false) {
                values[i] = default_value;
            }
        }
    }
};

//+------------------------------------------------------------------+
