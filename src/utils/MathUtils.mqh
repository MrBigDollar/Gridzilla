//+------------------------------------------------------------------+
//|                                                   MathUtils.mqh   |
//|                                Copyright 2024, Gridzilla Project  |
//+------------------------------------------------------------------+
#property copyright "Gridzilla Project"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| LinearRegressionResult - Resultat från linjär regression          |
//+------------------------------------------------------------------+
struct LinearRegressionResult {
    double slope;           // Lutning
    double intercept;       // Skärningspunkt med y-axeln
    double r_squared;       // Förklaringsgrad (0-1)
    double std_error;       // Standardfel

    LinearRegressionResult() {
        slope = 0;
        intercept = 0;
        r_squared = 0;
        std_error = 0;
    }
};

//+------------------------------------------------------------------+
//| MathUtils - Matematiska hjälpfunktioner                           |
//|                                                                   |
//| Syfte: Tillhandahålla deterministiska matematiska beräkningar     |
//| för trend-analys, statistik och normalisering.                    |
//+------------------------------------------------------------------+
class CMathUtils {
public:
    //+------------------------------------------------------------------+
    //| Mean - Beräkna medelvärde                                         |
    //+------------------------------------------------------------------+
    static double Mean(const double &values[], int count = -1) {
        int n = (count < 0) ? ArraySize(values) : count;
        if (n == 0) return 0.0;

        double sum = 0.0;
        for (int i = 0; i < n; i++) {
            sum += values[i];
        }
        return sum / n;
    }

    //+------------------------------------------------------------------+
    //| Sum - Beräkna summa                                               |
    //+------------------------------------------------------------------+
    static double Sum(const double &values[], int count = -1) {
        int n = (count < 0) ? ArraySize(values) : count;
        double sum = 0.0;
        for (int i = 0; i < n; i++) {
            sum += values[i];
        }
        return sum;
    }

    //+------------------------------------------------------------------+
    //| Min - Hitta minsta värde                                          |
    //+------------------------------------------------------------------+
    static double Min(const double &values[], int count = -1) {
        int n = (count < 0) ? ArraySize(values) : count;
        if (n == 0) return 0.0;

        double min_val = values[0];
        for (int i = 1; i < n; i++) {
            if (values[i] < min_val) min_val = values[i];
        }
        return min_val;
    }

    //+------------------------------------------------------------------+
    //| Max - Hitta största värde                                         |
    //+------------------------------------------------------------------+
    static double Max(const double &values[], int count = -1) {
        int n = (count < 0) ? ArraySize(values) : count;
        if (n == 0) return 0.0;

        double max_val = values[0];
        for (int i = 1; i < n; i++) {
            if (values[i] > max_val) max_val = values[i];
        }
        return max_val;
    }

    //+------------------------------------------------------------------+
    //| Variance - Beräkna varians (population)                           |
    //+------------------------------------------------------------------+
    static double Variance(const double &values[], int count = -1) {
        int n = (count < 0) ? ArraySize(values) : count;
        if (n == 0) return 0.0;

        double mean = Mean(values, n);
        double sum_sq_diff = 0.0;

        for (int i = 0; i < n; i++) {
            double diff = values[i] - mean;
            sum_sq_diff += diff * diff;
        }

        return sum_sq_diff / n;
    }

    //+------------------------------------------------------------------+
    //| StdDev - Beräkna standardavvikelse (population)                   |
    //+------------------------------------------------------------------+
    static double StdDev(const double &values[], int count = -1) {
        return MathSqrt(Variance(values, count));
    }

    //+------------------------------------------------------------------+
    //| SampleVariance - Beräkna varians (sample, n-1)                    |
    //+------------------------------------------------------------------+
    static double SampleVariance(const double &values[], int count = -1) {
        int n = (count < 0) ? ArraySize(values) : count;
        if (n <= 1) return 0.0;

        double mean = Mean(values, n);
        double sum_sq_diff = 0.0;

        for (int i = 0; i < n; i++) {
            double diff = values[i] - mean;
            sum_sq_diff += diff * diff;
        }

        return sum_sq_diff / (n - 1);
    }

    //+------------------------------------------------------------------+
    //| SampleStdDev - Beräkna standardavvikelse (sample, n-1)            |
    //+------------------------------------------------------------------+
    static double SampleStdDev(const double &values[], int count = -1) {
        return MathSqrt(SampleVariance(values, count));
    }

    //+------------------------------------------------------------------+
    //| LinearRegression - Utför linjär regression (y = ax + b)           |
    //|                                                                   |
    //| y_values: Y-värden (beroende variabel)                            |
    //| count: Antal värden att använda                                   |
    //| Förutsätter X = 0, 1, 2, 3, ... (index)                           |
    //+------------------------------------------------------------------+
    static LinearRegressionResult LinearRegression(const double &y_values[], int count = -1) {
        LinearRegressionResult result;

        int n = (count < 0) ? ArraySize(y_values) : count;
        if (n < 2) return result;

        // Beräkna medelvärden
        double sum_x = 0.0;
        double sum_y = 0.0;
        double sum_xy = 0.0;
        double sum_xx = 0.0;

        for (int i = 0; i < n; i++) {
            double x = (double)i;
            double y = y_values[i];
            sum_x += x;
            sum_y += y;
            sum_xy += x * y;
            sum_xx += x * x;
        }

        double mean_x = sum_x / n;
        double mean_y = sum_y / n;

        // Beräkna slope och intercept
        double denominator = sum_xx - n * mean_x * mean_x;
        if (MathAbs(denominator) < 1e-10) {
            // Vertikal linje eller inga data
            result.slope = 0;
            result.intercept = mean_y;
            return result;
        }

        result.slope = (sum_xy - n * mean_x * mean_y) / denominator;
        result.intercept = mean_y - result.slope * mean_x;

        // Beräkna R² (förklaringsgrad)
        double ss_tot = 0.0;  // Total sum of squares
        double ss_res = 0.0;  // Residual sum of squares

        for (int i = 0; i < n; i++) {
            double y_actual = y_values[i];
            double y_pred = result.slope * i + result.intercept;
            double y_diff = y_actual - mean_y;

            ss_tot += y_diff * y_diff;
            ss_res += (y_actual - y_pred) * (y_actual - y_pred);
        }

        if (ss_tot > 1e-10) {
            result.r_squared = 1.0 - (ss_res / ss_tot);
        } else {
            result.r_squared = 1.0;  // Alla Y är samma
        }

        // Beräkna standardfel
        if (n > 2) {
            result.std_error = MathSqrt(ss_res / (n - 2));
        }

        return result;
    }

    //+------------------------------------------------------------------+
    //| LinearRegressionSlope - Beräkna endast slope                      |
    //+------------------------------------------------------------------+
    static double LinearRegressionSlope(const double &y_values[], int count = -1) {
        LinearRegressionResult result = LinearRegression(y_values, count);
        return result.slope;
    }

    //+------------------------------------------------------------------+
    //| ZScore - Beräkna z-score                                          |
    //+------------------------------------------------------------------+
    static double ZScore(double value, double mean, double std_dev) {
        if (MathAbs(std_dev) < 1e-10) return 0.0;
        return (value - mean) / std_dev;
    }

    //+------------------------------------------------------------------+
    //| ZScoreOfArray - Beräkna z-score för värde relativt array          |
    //+------------------------------------------------------------------+
    static double ZScoreOfArray(double value, const double &values[], int count = -1) {
        double mean = Mean(values, count);
        double std_dev = StdDev(values, count);
        return ZScore(value, mean, std_dev);
    }

    //+------------------------------------------------------------------+
    //| NormalizeToRange - Normalisera värde till nytt intervall          |
    //|                                                                   |
    //| value: Värde att normalisera                                      |
    //| in_min, in_max: Ursprungligt intervall                            |
    //| out_min, out_max: Mål-intervall                                   |
    //+------------------------------------------------------------------+
    static double NormalizeToRange(double value,
                                   double in_min, double in_max,
                                   double out_min = 0.0, double out_max = 1.0) {
        double in_range = in_max - in_min;
        if (MathAbs(in_range) < 1e-10) return out_min;

        double normalized = (value - in_min) / in_range;
        return out_min + normalized * (out_max - out_min);
    }

    //+------------------------------------------------------------------+
    //| Clamp - Begränsa värde till intervall                             |
    //+------------------------------------------------------------------+
    static double Clamp(double value, double min_val, double max_val) {
        if (value < min_val) return min_val;
        if (value > max_val) return max_val;
        return value;
    }

    //+------------------------------------------------------------------+
    //| ClampInt - Begränsa heltal till intervall                         |
    //+------------------------------------------------------------------+
    static int ClampInt(int value, int min_val, int max_val) {
        if (value < min_val) return min_val;
        if (value > max_val) return max_val;
        return value;
    }

    //+------------------------------------------------------------------+
    //| Lerp - Linjär interpolation                                       |
    //|                                                                   |
    //| a: Startvärde                                                     |
    //| b: Slutvärde                                                      |
    //| t: Interpolationsfaktor (0-1)                                     |
    //+------------------------------------------------------------------+
    static double Lerp(double a, double b, double t) {
        return a + (b - a) * t;
    }

    //+------------------------------------------------------------------+
    //| InverseLerp - Hitta t givet värde och intervall                   |
    //+------------------------------------------------------------------+
    static double InverseLerp(double a, double b, double value) {
        double range = b - a;
        if (MathAbs(range) < 1e-10) return 0.0;
        return (value - a) / range;
    }

    //+------------------------------------------------------------------+
    //| ExponentialSmooth - Exponentiell utjämning (EMA-stil)             |
    //|                                                                   |
    //| current: Nytt värde                                               |
    //| previous: Föregående utjämnat värde                               |
    //| alpha: Utjämningsfaktor (0-1, högre = mer reaktivt)               |
    //+------------------------------------------------------------------+
    static double ExponentialSmooth(double current, double previous, double alpha) {
        alpha = Clamp(alpha, 0.0, 1.0);
        return alpha * current + (1.0 - alpha) * previous;
    }

    //+------------------------------------------------------------------+
    //| RoundToDigits - Avrunda till specifikt antal decimaler            |
    //+------------------------------------------------------------------+
    static double RoundToDigits(double value, int digits) {
        return NormalizeDouble(value, digits);
    }

    //+------------------------------------------------------------------+
    //| SafeDiv - Säker division (undvik division med 0)                  |
    //+------------------------------------------------------------------+
    static double SafeDiv(double numerator, double denominator, double default_value = 0.0) {
        if (MathAbs(denominator) < 1e-10) return default_value;
        return numerator / denominator;
    }

    //+------------------------------------------------------------------+
    //| Sign - Returnera tecken på tal (-1, 0, eller 1)                   |
    //+------------------------------------------------------------------+
    static int Sign(double value) {
        if (value > 0) return 1;
        if (value < 0) return -1;
        return 0;
    }

    //+------------------------------------------------------------------+
    //| Percentile - Beräkna percentil av array                           |
    //+------------------------------------------------------------------+
    static double Percentile(const double &values[], double percentile, int count = -1) {
        int n = (count < 0) ? ArraySize(values) : count;
        if (n == 0) return 0.0;
        if (n == 1) return values[0];

        // Kopiera och sortera
        double sorted[];
        ArrayResize(sorted, n);
        for (int i = 0; i < n; i++) {
            sorted[i] = values[i];
        }
        ArraySort(sorted);

        // Beräkna position
        double pos = percentile / 100.0 * (n - 1);
        int lower = (int)MathFloor(pos);
        int upper = (int)MathCeil(pos);

        if (lower == upper) {
            return sorted[lower];
        }

        // Linjär interpolation
        double frac = pos - lower;
        return sorted[lower] * (1.0 - frac) + sorted[upper] * frac;
    }

    //+------------------------------------------------------------------+
    //| Median - Beräkna median                                           |
    //+------------------------------------------------------------------+
    static double Median(const double &values[], int count = -1) {
        return Percentile(values, 50.0, count);
    }
};

//+------------------------------------------------------------------+
