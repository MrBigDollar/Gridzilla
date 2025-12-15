//+------------------------------------------------------------------+
//|                                      TestNormalizationUtils.mqh   |
//|                                Copyright 2024, Gridzilla Project  |
//+------------------------------------------------------------------+
#property copyright "Gridzilla Project"
#property version   "1.00"
#property strict

#include "..\..\src\utils\NormalizationUtils.mqh"
#include "..\TestAssertions.mqh"

//+------------------------------------------------------------------+
//| Helper: Skapa giltig ONNX input-array                             |
//+------------------------------------------------------------------+
void CreateValidONNXInput(float &arr[]) {
    ArrayResize(arr, 12);
    arr[0] = 0.5f;   // trend_strength [0,1]
    arr[1] = 0.0f;   // slope [-1,1]
    arr[2] = 0.0f;   // curvature [-1,1]
    arr[3] = 0.5f;   // volatility_level [0,1]
    arr[4] = 0.0f;   // volatility_change [-1,1]
    arr[5] = 0.5f;   // mean_reversion [0,1]
    arr[6] = 0.0f;   // spread_zscore [-3,3]
    arr[7] = 2.0f;   // session_id [0,4]
    arr[8] = 0.0f;   // grid_active [0,1]
    arr[9] = 4.0f;   // open_levels [0,8]
    arr[10] = 0.0f;  // unrealized_dd [0,1]
    arr[11] = 0.0f;  // dd_velocity [-1,1]
}

//+------------------------------------------------------------------+
//| Helper: Skapa giltig ONNX output-array                            |
//+------------------------------------------------------------------+
void CreateValidONNXOutput(float &arr[]) {
    ArrayResize(arr, 12);
    arr[0] = 0.8f;   // allow_entry [0,1]
    arr[1] = 1.0f;   // entry_mode [0,4]
    arr[2] = 0.5f;   // direction [-1,1]
    arr[3] = 1.0f;   // initial_risk [0.5,2.0]
    arr[4] = 0.0f;   // activate_grid [0,1]
    arr[5] = 2.0f;   // grid_structure [0,5]
    arr[6] = 1.0f;   // grid_action [0,4]
    arr[7] = 50.0f;  // base_spacing [20,100]
    arr[8] = 1.2f;   // spacing_growth [1.0,1.5]
    arr[9] = 1.5f;   // lot_growth [1.1,2.0]
    arr[10] = 5.0f;  // max_levels [3,8]
    arr[11] = 0.75f; // confidence [0,1]
}

//+------------------------------------------------------------------+
//| RunNormalizationUtilsTests - Kör alla NormalizationUtils-tester   |
//+------------------------------------------------------------------+
void RunNormalizationUtilsTests() {
    BeginTestSuite("NormalizationUtils");

    //=== NormalizeValue Tests ===
    BeginTest("NormalizeValue_MidPoint_ReturnsHalf");
    {
        // 50 i [0,100] -> 0.5 i [0,1]
        double result = CNormalizationUtils::NormalizeValue(50.0, 0.0, 100.0, 0.0, 1.0);
        AssertNear(0.5, result, 0.0001, "Midpoint should normalize to 0.5");
    }
    EndTest();

    BeginTest("NormalizeValue_MinValue_ReturnsTargetMin");
    {
        double result = CNormalizationUtils::NormalizeValue(0.0, 0.0, 100.0, 0.0, 1.0);
        AssertNear(0.0, result, 0.0001, "Min value should normalize to target min");
    }
    EndTest();

    BeginTest("NormalizeValue_MaxValue_ReturnsTargetMax");
    {
        double result = CNormalizationUtils::NormalizeValue(100.0, 0.0, 100.0, 0.0, 1.0);
        AssertNear(1.0, result, 0.0001, "Max value should normalize to target max");
    }
    EndTest();

    BeginTest("NormalizeValue_NegativeRange_HandlesCorrectly");
    {
        // -1 i [-1,1] -> 0.0 i [0,1]
        double result = CNormalizationUtils::NormalizeValue(-1.0, -1.0, 1.0, 0.0, 1.0);
        AssertNear(0.0, result, 0.0001, "-1 in [-1,1] should be 0 in [0,1]");
    }
    EndTest();

    BeginTest("NormalizeValue_CustomTargetRange_ReturnsCorrect");
    {
        // 75 i [0,100] -> [20,100]: 20 + 0.75*80 = 80
        double result = CNormalizationUtils::NormalizeValue(75.0, 0.0, 100.0, 20.0, 100.0);
        AssertNear(80.0, result, 0.0001, "75 should map to 80 in [20,100]");
    }
    EndTest();

    //=== DenormalizeValue Tests ===
    BeginTest("DenormalizeValue_HalfPoint_ReturnsMid");
    {
        // 0.5 i [0,1] -> 50 i [0,100]
        double result = CNormalizationUtils::DenormalizeValue(0.5, 0.0, 1.0, 0.0, 100.0);
        AssertNear(50.0, result, 0.0001, "0.5 should denormalize to 50");
    }
    EndTest();

    BeginTest("DenormalizeValue_SpacingRange_ReturnsCorrect");
    {
        // 60 i [20,100] -> 0.5 -> sedan till pip-värde
        double result = CNormalizationUtils::DenormalizeValue(60.0, 20.0, 100.0, 0.0, 1.0);
        AssertNear(0.5, result, 0.0001, "60 in [20,100] should be 0.5 in [0,1]");
    }
    EndTest();

    //=== ClampToRange Tests ===
    BeginTest("ClampToRange_ValueInRange_ReturnsUnchanged");
    {
        double result = CNormalizationUtils::ClampToRange(0.5, 0.0, 1.0);
        AssertNear(0.5, result, 0.0001, "Value in range unchanged");
    }
    EndTest();

    BeginTest("ClampToRange_ValueBelowMin_ReturnsMin");
    {
        double result = CNormalizationUtils::ClampToRange(-0.5, 0.0, 1.0);
        AssertNear(0.0, result, 0.0001, "Value below min clamped to min");
    }
    EndTest();

    BeginTest("ClampToRange_ValueAboveMax_ReturnsMax");
    {
        double result = CNormalizationUtils::ClampToRange(1.5, 0.0, 1.0);
        AssertNear(1.0, result, 0.0001, "Value above max clamped to max");
    }
    EndTest();

    //=== IsInValidRange Tests ===
    BeginTest("IsInValidRange_ValueInRange_ReturnsTrue");
    {
        bool result = CNormalizationUtils::IsInValidRange(0.5, 0.0, 1.0);
        AssertTrue(result, "0.5 is in [0,1]");
    }
    EndTest();

    BeginTest("IsInValidRange_ValueAtMin_ReturnsTrue");
    {
        bool result = CNormalizationUtils::IsInValidRange(0.0, 0.0, 1.0);
        AssertTrue(result, "0.0 is in [0,1] (inclusive)");
    }
    EndTest();

    BeginTest("IsInValidRange_ValueAtMax_ReturnsTrue");
    {
        bool result = CNormalizationUtils::IsInValidRange(1.0, 0.0, 1.0);
        AssertTrue(result, "1.0 is in [0,1] (inclusive)");
    }
    EndTest();

    BeginTest("IsInValidRange_ValueOutside_ReturnsFalse");
    {
        bool result = CNormalizationUtils::IsInValidRange(1.5, 0.0, 1.0);
        AssertFalse(result, "1.5 is not in [0,1]");
    }
    EndTest();

    //=== NormalizeAndClamp Tests ===
    BeginTest("NormalizeAndClamp_ValueOutOfRange_Clamps");
    {
        // 150 i [0,100] skulle ge 1.5, men clampas till 1.0
        double result = CNormalizationUtils::NormalizeAndClamp(150.0, 0.0, 100.0, 0.0, 1.0);
        AssertNear(1.0, result, 0.0001, "150 should clamp to 1.0");
    }
    EndTest();

    BeginTest("NormalizeAndClamp_NegativeOutOfRange_ClampsToMin");
    {
        double result = CNormalizationUtils::NormalizeAndClamp(-50.0, 0.0, 100.0, 0.0, 1.0);
        AssertNear(0.0, result, 0.0001, "-50 should clamp to 0.0");
    }
    EndTest();

    //=== ONNXInputRanges Default Values ===
    BeginTest("ONNXInputRanges_DefaultValues_AreCorrect");
    {
        ONNXInputRanges ranges;
        AssertNear(0.0, ranges.trend_strength_min, 0.0001, "trend_strength_min");
        AssertNear(1.0, ranges.trend_strength_max, 0.0001, "trend_strength_max");
        AssertNear(-1.0, ranges.slope_min, 0.0001, "slope_min");
        AssertNear(1.0, ranges.slope_max, 0.0001, "slope_max");
        AssertNear(-3.0, ranges.spread_zscore_min, 0.0001, "spread_zscore_min");
        AssertNear(3.0, ranges.spread_zscore_max, 0.0001, "spread_zscore_max");
        AssertNear(0.0, ranges.session_id_min, 0.0001, "session_id_min");
        AssertNear(4.0, ranges.session_id_max, 0.0001, "session_id_max");
        AssertNear(0.0, ranges.open_levels_min, 0.0001, "open_levels_min");
        AssertNear(8.0, ranges.open_levels_max, 0.0001, "open_levels_max");
    }
    EndTest();

    //=== ONNXOutputRanges Default Values ===
    BeginTest("ONNXOutputRanges_DefaultValues_AreCorrect");
    {
        ONNXOutputRanges ranges;
        AssertNear(0.0, ranges.allow_entry_min, 0.0001, "allow_entry_min");
        AssertNear(1.0, ranges.allow_entry_max, 0.0001, "allow_entry_max");
        AssertNear(0.5, ranges.initial_risk_min, 0.0001, "initial_risk_min");
        AssertNear(2.0, ranges.initial_risk_max, 0.0001, "initial_risk_max");
        AssertNear(20.0, ranges.base_spacing_min, 0.0001, "base_spacing_min");
        AssertNear(100.0, ranges.base_spacing_max, 0.0001, "base_spacing_max");
        AssertNear(1.1, ranges.lot_growth_min, 0.0001, "lot_growth_min");
        AssertNear(2.0, ranges.lot_growth_max, 0.0001, "lot_growth_max");
    }
    EndTest();

    //=== ValidateONNXInputArray Tests ===
    BeginTest("ValidateONNXInputArray_ValidInput_ReturnsTrue");
    {
        float arr[];
        CreateValidONNXInput(arr);
        ONNXInputRanges ranges;
        bool result = CNormalizationUtils::ValidateONNXInputArray(arr, ranges);
        AssertTrue(result, "Valid input should pass validation");
    }
    EndTest();

    BeginTest("ValidateONNXInputArray_InvalidSize_ReturnsFalse");
    {
        float arr[];
        ArrayResize(arr, 10);
        ArrayInitialize(arr, 0.5f);
        ONNXInputRanges ranges;
        bool result = CNormalizationUtils::ValidateONNXInputArray(arr, ranges);
        AssertFalse(result, "Wrong size should fail validation");
    }
    EndTest();

    BeginTest("ValidateONNXInputArray_OutOfRangeValue_ReturnsFalse");
    {
        float arr[];
        CreateValidONNXInput(arr);
        arr[0] = 1.5f;  // trend_strength = 1.5 är utanför [0,1]
        ONNXInputRanges ranges;
        bool result = CNormalizationUtils::ValidateONNXInputArray(arr, ranges);
        AssertFalse(result, "Out of range value should fail validation");
    }
    EndTest();

    //=== ClampONNXInputArray Tests ===
    BeginTest("ClampONNXInputArray_OutOfRangeValues_Clamps");
    {
        float arr[];
        ArrayResize(arr, 12);
        arr[0] = 1.5f;   // trend_strength - should clamp to 1.0
        arr[1] = -2.0f;  // slope - should clamp to -1.0
        arr[2] = 2.0f;   // curvature - should clamp to 1.0
        arr[3] = 0.5f;
        arr[4] = 0.0f;
        arr[5] = 0.5f;
        arr[6] = 5.0f;   // spread_zscore - should clamp to 3.0
        arr[7] = 2.0f;
        arr[8] = 0.0f;
        arr[9] = 10.0f;  // open_levels - should clamp to 8.0
        arr[10] = 0.0f;
        arr[11] = 0.0f;

        ONNXInputRanges ranges;
        CNormalizationUtils::ClampONNXInputArray(arr, ranges);

        AssertNear(1.0, arr[0], 0.0001, "trend_strength clamped to 1.0");
        AssertNear(-1.0, arr[1], 0.0001, "slope clamped to -1.0");
        AssertNear(1.0, arr[2], 0.0001, "curvature clamped to 1.0");
        AssertNear(3.0, arr[6], 0.0001, "spread_zscore clamped to 3.0");
        AssertNear(8.0, arr[9], 0.0001, "open_levels clamped to 8.0");
    }
    EndTest();

    //=== CheckForNaN Tests ===
    BeginTest("CheckForNaN_ValidValues_ReturnsFalse");
    {
        float values[];
        ArrayResize(values, 5);
        values[0] = 1.0f;
        values[1] = 2.0f;
        values[2] = 3.0f;
        values[3] = 4.0f;
        values[4] = 5.0f;
        bool result = CNormalizationUtils::CheckForNaN(values);
        AssertFalse(result, "Valid values should not contain NaN");
    }
    EndTest();

    //=== ValidateONNXOutputArray Tests ===
    BeginTest("ValidateONNXOutputArray_ValidOutput_ReturnsTrue");
    {
        float arr[];
        CreateValidONNXOutput(arr);
        ONNXOutputRanges ranges;
        bool result = CNormalizationUtils::ValidateONNXOutputArray(arr, ranges);
        AssertTrue(result, "Valid output should pass validation");
    }
    EndTest();

    BeginTest("ValidateONNXOutputArray_SpacingOutOfRange_ReturnsFalse");
    {
        float arr[];
        CreateValidONNXOutput(arr);
        arr[7] = 150.0f;  // base_spacing = 150 är utanför [20,100]
        ONNXOutputRanges ranges;
        bool result = CNormalizationUtils::ValidateONNXOutputArray(arr, ranges);
        AssertFalse(result, "Spacing out of range should fail");
    }
    EndTest();

    EndTestSuite();
}

//+------------------------------------------------------------------+
