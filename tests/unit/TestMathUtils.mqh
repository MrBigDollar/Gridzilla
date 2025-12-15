//+------------------------------------------------------------------+
//|                                               TestMathUtils.mqh   |
//|                                Copyright 2024, Gridzilla Project  |
//+------------------------------------------------------------------+
#property copyright "Gridzilla Project"
#property version   "1.00"
#property strict

#include "..\..\src\utils\MathUtils.mqh"
#include "..\TestAssertions.mqh"

//+------------------------------------------------------------------+
//| RunMathUtilsTests - Kör alla MathUtils-tester                     |
//+------------------------------------------------------------------+
void RunMathUtilsTests() {
    BeginTestSuite("MathUtils");

    //=== Mean Tests ===
    BeginTest("Mean_EmptyArray_ReturnsZero");
    {
        double values[];
        double result = CMathUtils::Mean(values, 0);
        AssertEqual(0.0, result, "Mean of empty array should be 0");
    }
    EndTest();

    BeginTest("Mean_SingleValue_ReturnsThatValue");
    {
        double values[] = {5.0};
        double result = CMathUtils::Mean(values, 1);
        AssertNear(5.0, result, 0.0001, "Mean of single value");
    }
    EndTest();

    BeginTest("Mean_KnownValues_ReturnsCorrect");
    {
        double values[] = {1.0, 2.0, 3.0, 4.0, 5.0};
        double result = CMathUtils::Mean(values, 5);
        AssertNear(3.0, result, 0.0001, "Mean of 1-5 should be 3");
    }
    EndTest();

    BeginTest("Mean_NegativeValues_ReturnsCorrect");
    {
        double values[] = {-5.0, -3.0, -1.0, 1.0, 3.0, 5.0};
        double result = CMathUtils::Mean(values, 6);
        AssertNear(0.0, result, 0.0001, "Mean should be 0");
    }
    EndTest();

    //=== Sum Tests ===
    BeginTest("Sum_EmptyArray_ReturnsZero");
    {
        double values[];
        double result = CMathUtils::Sum(values, 0);
        AssertEqual(0.0, result, "Sum of empty array should be 0");
    }
    EndTest();

    BeginTest("Sum_KnownValues_ReturnsCorrect");
    {
        double values[] = {1.0, 2.0, 3.0, 4.0, 5.0};
        double result = CMathUtils::Sum(values, 5);
        AssertNear(15.0, result, 0.0001, "Sum of 1-5 should be 15");
    }
    EndTest();

    //=== Min/Max Tests ===
    BeginTest("Min_KnownValues_ReturnsSmallest");
    {
        double values[] = {5.0, 2.0, 8.0, 1.0, 9.0};
        double result = CMathUtils::Min(values, 5);
        AssertNear(1.0, result, 0.0001, "Min should be 1");
    }
    EndTest();

    BeginTest("Max_KnownValues_ReturnsLargest");
    {
        double values[] = {5.0, 2.0, 8.0, 1.0, 9.0};
        double result = CMathUtils::Max(values, 5);
        AssertNear(9.0, result, 0.0001, "Max should be 9");
    }
    EndTest();

    BeginTest("Min_NegativeValues_ReturnsCorrect");
    {
        double values[] = {-3.0, -7.0, -1.0, -5.0};
        double result = CMathUtils::Min(values, 4);
        AssertNear(-7.0, result, 0.0001, "Min should be -7");
    }
    EndTest();

    //=== StdDev Tests ===
    BeginTest("StdDev_IdenticalValues_ReturnsZero");
    {
        double values[] = {5.0, 5.0, 5.0, 5.0};
        double result = CMathUtils::StdDev(values, 4);
        AssertNear(0.0, result, 0.0001, "StdDev of identical values should be 0");
    }
    EndTest();

    BeginTest("StdDev_KnownValues_ReturnsCorrect");
    {
        // Känd population stddev för [1,2,3,4,5] = sqrt(2) ≈ 1.4142
        double values[] = {1.0, 2.0, 3.0, 4.0, 5.0};
        double result = CMathUtils::StdDev(values, 5);
        AssertNear(1.4142, result, 0.001, "StdDev of 1-5");
    }
    EndTest();

    BeginTest("Variance_KnownValues_ReturnsCorrect");
    {
        // Variance för [1,2,3,4,5] = 2.0
        double values[] = {1.0, 2.0, 3.0, 4.0, 5.0};
        double result = CMathUtils::Variance(values, 5);
        AssertNear(2.0, result, 0.0001, "Variance of 1-5 should be 2");
    }
    EndTest();

    //=== LinearRegression Tests ===
    BeginTest("LinearRegression_PerfectLine_ReturnsExactSlope");
    {
        // y = 2x + 1 (x=0,1,2,3,4)
        double values[] = {1.0, 3.0, 5.0, 7.0, 9.0};
        LinearRegressionResult result = CMathUtils::LinearRegression(values, 5);

        AssertNear(2.0, result.slope, 0.0001, "Slope should be 2");
        AssertNear(1.0, result.intercept, 0.0001, "Intercept should be 1");
        AssertNear(1.0, result.r_squared, 0.0001, "R² should be 1 for perfect line");
    }
    EndTest();

    BeginTest("LinearRegression_FlatLine_ReturnsZeroSlope");
    {
        double values[] = {5.0, 5.0, 5.0, 5.0, 5.0};
        LinearRegressionResult result = CMathUtils::LinearRegression(values, 5);

        AssertNear(0.0, result.slope, 0.0001, "Slope should be 0 for flat line");
        AssertNear(5.0, result.intercept, 0.0001, "Intercept should be 5");
    }
    EndTest();

    BeginTest("LinearRegression_NegativeSlope_ReturnsCorrect");
    {
        // y = -1x + 10 (x=0,1,2,3,4)
        double values[] = {10.0, 9.0, 8.0, 7.0, 6.0};
        LinearRegressionResult result = CMathUtils::LinearRegression(values, 5);

        AssertNear(-1.0, result.slope, 0.0001, "Slope should be -1");
        AssertNear(10.0, result.intercept, 0.0001, "Intercept should be 10");
    }
    EndTest();

    BeginTest("LinearRegressionSlope_Shortcut_MatchesFull");
    {
        double values[] = {1.0, 3.0, 5.0, 7.0, 9.0};
        double slope = CMathUtils::LinearRegressionSlope(values, 5);
        AssertNear(2.0, slope, 0.0001, "Slope shortcut should return 2");
    }
    EndTest();

    //=== ZScore Tests ===
    BeginTest("ZScore_AtMean_ReturnsZero");
    {
        double result = CMathUtils::ZScore(5.0, 5.0, 2.0);
        AssertNear(0.0, result, 0.0001, "Z-score at mean should be 0");
    }
    EndTest();

    BeginTest("ZScore_OneStdDevAbove_ReturnsOne");
    {
        double result = CMathUtils::ZScore(7.0, 5.0, 2.0);
        AssertNear(1.0, result, 0.0001, "Z-score 1 std above should be 1");
    }
    EndTest();

    BeginTest("ZScore_TwoStdDevBelow_ReturnsMinusTwo");
    {
        double result = CMathUtils::ZScore(1.0, 5.0, 2.0);
        AssertNear(-2.0, result, 0.0001, "Z-score 2 std below should be -2");
    }
    EndTest();

    //=== NormalizeToRange Tests ===
    BeginTest("NormalizeToRange_MidValue_ReturnsHalf");
    {
        double result = CMathUtils::NormalizeToRange(50.0, 0.0, 100.0, 0.0, 1.0);
        AssertNear(0.5, result, 0.0001, "50 in [0,100] -> 0.5 in [0,1]");
    }
    EndTest();

    BeginTest("NormalizeToRange_MinValue_ReturnsMin");
    {
        double result = CMathUtils::NormalizeToRange(0.0, 0.0, 100.0, 0.0, 1.0);
        AssertNear(0.0, result, 0.0001, "Min value should map to output min");
    }
    EndTest();

    BeginTest("NormalizeToRange_MaxValue_ReturnsMax");
    {
        double result = CMathUtils::NormalizeToRange(100.0, 0.0, 100.0, 0.0, 1.0);
        AssertNear(1.0, result, 0.0001, "Max value should map to output max");
    }
    EndTest();

    BeginTest("NormalizeToRange_CustomRange_ReturnsCorrect");
    {
        // 75 in [0,100] -> [10,20]: 10 + 0.75*10 = 17.5
        double result = CMathUtils::NormalizeToRange(75.0, 0.0, 100.0, 10.0, 20.0);
        AssertNear(17.5, result, 0.0001, "75 in [0,100] -> 17.5 in [10,20]");
    }
    EndTest();

    //=== Clamp Tests ===
    BeginTest("Clamp_ValueInRange_ReturnsUnchanged");
    {
        double result = CMathUtils::Clamp(5.0, 0.0, 10.0);
        AssertNear(5.0, result, 0.0001, "Value in range should be unchanged");
    }
    EndTest();

    BeginTest("Clamp_ValueBelowMin_ReturnsMin");
    {
        double result = CMathUtils::Clamp(-5.0, 0.0, 10.0);
        AssertNear(0.0, result, 0.0001, "Value below min should return min");
    }
    EndTest();

    BeginTest("Clamp_ValueAboveMax_ReturnsMax");
    {
        double result = CMathUtils::Clamp(15.0, 0.0, 10.0);
        AssertNear(10.0, result, 0.0001, "Value above max should return max");
    }
    EndTest();

    //=== Lerp Tests ===
    BeginTest("Lerp_AtStart_ReturnsA");
    {
        double result = CMathUtils::Lerp(0.0, 10.0, 0.0);
        AssertNear(0.0, result, 0.0001, "Lerp at t=0 should return a");
    }
    EndTest();

    BeginTest("Lerp_AtEnd_ReturnsB");
    {
        double result = CMathUtils::Lerp(0.0, 10.0, 1.0);
        AssertNear(10.0, result, 0.0001, "Lerp at t=1 should return b");
    }
    EndTest();

    BeginTest("Lerp_AtMiddle_ReturnsAverage");
    {
        double result = CMathUtils::Lerp(0.0, 10.0, 0.5);
        AssertNear(5.0, result, 0.0001, "Lerp at t=0.5 should return average");
    }
    EndTest();

    //=== SafeDiv Tests ===
    BeginTest("SafeDiv_NormalDivision_ReturnsCorrect");
    {
        double result = CMathUtils::SafeDiv(10.0, 2.0, 0.0);
        AssertNear(5.0, result, 0.0001, "10/2 should be 5");
    }
    EndTest();

    BeginTest("SafeDiv_DivisionByZero_ReturnsDefault");
    {
        double result = CMathUtils::SafeDiv(10.0, 0.0, -1.0);
        AssertNear(-1.0, result, 0.0001, "Division by zero should return default");
    }
    EndTest();

    //=== Median Tests ===
    BeginTest("Median_OddCount_ReturnsMiddle");
    {
        double values[] = {1.0, 5.0, 3.0, 2.0, 4.0};  // Sorterat: 1,2,3,4,5
        double result = CMathUtils::Median(values, 5);
        AssertNear(3.0, result, 0.0001, "Median of 1,2,3,4,5 should be 3");
    }
    EndTest();

    BeginTest("Median_EvenCount_ReturnsAverage");
    {
        double values[] = {1.0, 2.0, 3.0, 4.0};  // Median = (2+3)/2 = 2.5
        double result = CMathUtils::Median(values, 4);
        AssertNear(2.5, result, 0.0001, "Median of 1,2,3,4 should be 2.5");
    }
    EndTest();

    //=== Sign Tests ===
    BeginTest("Sign_PositiveValue_ReturnsOne");
    {
        int result = CMathUtils::Sign(5.0);
        AssertEqual(1, result, "Sign of positive should be 1");
    }
    EndTest();

    BeginTest("Sign_NegativeValue_ReturnsMinusOne");
    {
        int result = CMathUtils::Sign(-5.0);
        AssertEqual(-1, result, "Sign of negative should be -1");
    }
    EndTest();

    BeginTest("Sign_Zero_ReturnsZero");
    {
        int result = CMathUtils::Sign(0.0);
        AssertEqual(0, result, "Sign of zero should be 0");
    }
    EndTest();

    EndTestSuite();
}

//+------------------------------------------------------------------+
