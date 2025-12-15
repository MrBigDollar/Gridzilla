//+------------------------------------------------------------------+
//|                                              TestAssertions.mqh   |
//|                                Copyright 2024, Gridzilla Project  |
//+------------------------------------------------------------------+
#property copyright "Gridzilla Project"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| TestResult - Resultat från ett enskilt test                       |
//+------------------------------------------------------------------+
struct TestResult {
    string   test_name;
    bool     passed;
    string   message;
    double   duration_ms;
    string   file;
    int      line;

    TestResult() {
        test_name = "";
        passed = true;
        message = "";
        duration_ms = 0;
        file = "";
        line = 0;
    }
};

//+------------------------------------------------------------------+
//| Global teststatistik                                              |
//+------------------------------------------------------------------+
int    g_tests_total = 0;
int    g_tests_passed = 0;
int    g_tests_failed = 0;
string g_current_test_name = "";
string g_current_test_suite = "";
uint   g_test_start_time = 0;
bool   g_current_test_passed = true;
string g_failure_message = "";

//--- Test-resultat array
TestResult g_test_results[];
int        g_result_count = 0;
int        g_max_results = 1000;

//+------------------------------------------------------------------+
//| InitializeTestFramework - Initiera testramverket                  |
//+------------------------------------------------------------------+
void InitializeTestFramework() {
    g_tests_total = 0;
    g_tests_passed = 0;
    g_tests_failed = 0;
    g_current_test_name = "";
    g_current_test_suite = "";
    g_current_test_passed = true;
    g_result_count = 0;
    ArrayResize(g_test_results, g_max_results);
}

//+------------------------------------------------------------------+
//| BeginTestSuite - Starta en testsvit                               |
//+------------------------------------------------------------------+
void BeginTestSuite(string suite_name) {
    g_current_test_suite = suite_name;
    Print("========================================");
    Print("TEST SUITE: ", suite_name);
    Print("========================================");
}

//+------------------------------------------------------------------+
//| EndTestSuite - Avsluta en testsvit                                |
//+------------------------------------------------------------------+
void EndTestSuite() {
    Print("----------------------------------------");
    Print("End of suite: ", g_current_test_suite);
    Print("");
    g_current_test_suite = "";
}

//+------------------------------------------------------------------+
//| BeginTest - Starta ett enskilt test                               |
//+------------------------------------------------------------------+
void BeginTest(string test_name) {
    g_current_test_name = test_name;
    g_current_test_passed = true;
    g_failure_message = "";
    g_test_start_time = GetTickCount();
    g_tests_total++;
}

//+------------------------------------------------------------------+
//| EndTest - Avsluta ett enskilt test                                |
//+------------------------------------------------------------------+
void EndTest() {
    uint duration = GetTickCount() - g_test_start_time;

    // Spara resultat
    if (g_result_count < g_max_results) {
        g_test_results[g_result_count].test_name = g_current_test_name;
        g_test_results[g_result_count].passed = g_current_test_passed;
        g_test_results[g_result_count].message = g_failure_message;
        g_test_results[g_result_count].duration_ms = duration;
        g_result_count++;
    }

    // Uppdatera statistik
    if (g_current_test_passed) {
        g_tests_passed++;
        Print("  [PASS] ", g_current_test_name, " (", duration, "ms)");
    } else {
        g_tests_failed++;
        Print("  [FAIL] ", g_current_test_name, " (", duration, "ms)");
        Print("         ", g_failure_message);
    }

    g_current_test_name = "";
}

//+------------------------------------------------------------------+
//| FailTest - Markera aktuellt test som misslyckat                   |
//+------------------------------------------------------------------+
void FailTest(string message) {
    g_current_test_passed = false;
    if (g_failure_message == "") {
        g_failure_message = message;
    } else {
        g_failure_message += "; " + message;
    }
}

//+------------------------------------------------------------------+
//| AssertTrue - Kontrollera att villkor är sant                      |
//+------------------------------------------------------------------+
bool AssertTrue(bool condition, string message = "") {
    if (!condition) {
        string fail_msg = "AssertTrue failed";
        if (message != "") fail_msg += ": " + message;
        FailTest(fail_msg);
        return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| AssertFalse - Kontrollera att villkor är falskt                   |
//+------------------------------------------------------------------+
bool AssertFalse(bool condition, string message = "") {
    if (condition) {
        string fail_msg = "AssertFalse failed";
        if (message != "") fail_msg += ": " + message;
        FailTest(fail_msg);
        return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| AssertEqual (int) - Kontrollera likhet för heltal                 |
//+------------------------------------------------------------------+
bool AssertEqual(int expected, int actual, string message = "") {
    if (expected != actual) {
        string fail_msg = StringFormat("AssertEqual failed: expected %d, got %d",
                                       expected, actual);
        if (message != "") fail_msg += " - " + message;
        FailTest(fail_msg);
        return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| AssertEqual (long) - Kontrollera likhet för long                  |
//+------------------------------------------------------------------+
bool AssertEqual(long expected, long actual, string message = "") {
    if (expected != actual) {
        string fail_msg = StringFormat("AssertEqual failed: expected %d, got %d",
                                       expected, actual);
        if (message != "") fail_msg += " - " + message;
        FailTest(fail_msg);
        return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| AssertEqual (double) - Kontrollera likhet för decimaltal          |
//+------------------------------------------------------------------+
bool AssertEqual(double expected, double actual, string message = "") {
    // Använd liten tolerans för flyttal
    if (MathAbs(expected - actual) > 0.0000001) {
        string fail_msg = StringFormat("AssertEqual failed: expected %.8f, got %.8f",
                                       expected, actual);
        if (message != "") fail_msg += " - " + message;
        FailTest(fail_msg);
        return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| AssertEqual (string) - Kontrollera likhet för strängar            |
//+------------------------------------------------------------------+
bool AssertEqual(string expected, string actual, string message = "") {
    if (expected != actual) {
        string fail_msg = StringFormat("AssertEqual failed: expected \"%s\", got \"%s\"",
                                       expected, actual);
        if (message != "") fail_msg += " - " + message;
        FailTest(fail_msg);
        return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| AssertNotEqual (int) - Kontrollera olikhet för heltal             |
//+------------------------------------------------------------------+
bool AssertNotEqual(int not_expected, int actual, string message = "") {
    if (not_expected == actual) {
        string fail_msg = StringFormat("AssertNotEqual failed: both are %d", actual);
        if (message != "") fail_msg += " - " + message;
        FailTest(fail_msg);
        return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| AssertNear - Kontrollera att värden är nära nog                   |
//+------------------------------------------------------------------+
bool AssertNear(double expected, double actual, double tolerance, string message = "") {
    double diff = MathAbs(expected - actual);
    if (diff > tolerance) {
        string fail_msg = StringFormat("AssertNear failed: expected %.8f, got %.8f (diff: %.8f > tolerance: %.8f)",
                                       expected, actual, diff, tolerance);
        if (message != "") fail_msg += " - " + message;
        FailTest(fail_msg);
        return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| AssertGreater - Kontrollera att värde är större                   |
//+------------------------------------------------------------------+
bool AssertGreater(double value, double threshold, string message = "") {
    if (value <= threshold) {
        string fail_msg = StringFormat("AssertGreater failed: %.8f is not > %.8f",
                                       value, threshold);
        if (message != "") fail_msg += " - " + message;
        FailTest(fail_msg);
        return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| AssertGreaterOrEqual - Kontrollera att värde är >= tröskel        |
//+------------------------------------------------------------------+
bool AssertGreaterOrEqual(double value, double threshold, string message = "") {
    if (value < threshold) {
        string fail_msg = StringFormat("AssertGreaterOrEqual failed: %.8f is not >= %.8f",
                                       value, threshold);
        if (message != "") fail_msg += " - " + message;
        FailTest(fail_msg);
        return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| AssertLess - Kontrollera att värde är mindre                      |
//+------------------------------------------------------------------+
bool AssertLess(double value, double threshold, string message = "") {
    if (value >= threshold) {
        string fail_msg = StringFormat("AssertLess failed: %.8f is not < %.8f",
                                       value, threshold);
        if (message != "") fail_msg += " - " + message;
        FailTest(fail_msg);
        return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| AssertLessOrEqual - Kontrollera att värde är <= tröskel           |
//+------------------------------------------------------------------+
bool AssertLessOrEqual(double value, double threshold, string message = "") {
    if (value > threshold) {
        string fail_msg = StringFormat("AssertLessOrEqual failed: %.8f is not <= %.8f",
                                       value, threshold);
        if (message != "") fail_msg += " - " + message;
        FailTest(fail_msg);
        return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| AssertInRange - Kontrollera att värde är inom intervall           |
//+------------------------------------------------------------------+
bool AssertInRange(double value, double min_val, double max_val, string message = "") {
    if (value < min_val || value > max_val) {
        string fail_msg = StringFormat("AssertInRange failed: %.8f is not in [%.8f, %.8f]",
                                       value, min_val, max_val);
        if (message != "") fail_msg += " - " + message;
        FailTest(fail_msg);
        return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| AssertNull - Kontrollera att pekare är NULL                       |
//+------------------------------------------------------------------+
bool AssertNull(void* ptr, string message = "") {
    if (ptr != NULL) {
        string fail_msg = "AssertNull failed: pointer is not NULL";
        if (message != "") fail_msg += " - " + message;
        FailTest(fail_msg);
        return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| AssertNotNull - Kontrollera att pekare inte är NULL               |
//+------------------------------------------------------------------+
bool AssertNotNull(void* ptr, string message = "") {
    if (ptr == NULL) {
        string fail_msg = "AssertNotNull failed: pointer is NULL";
        if (message != "") fail_msg += " - " + message;
        FailTest(fail_msg);
        return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| AssertContains - Kontrollera att sträng innehåller substring      |
//+------------------------------------------------------------------+
bool AssertContains(string haystack, string needle, string message = "") {
    if (StringFind(haystack, needle) < 0) {
        string fail_msg = StringFormat("AssertContains failed: \"%s\" not found in \"%s\"",
                                       needle, haystack);
        if (message != "") fail_msg += " - " + message;
        FailTest(fail_msg);
        return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| AssertNotContains - Kontrollera att sträng INTE innehåller substr |
//+------------------------------------------------------------------+
bool AssertNotContains(string haystack, string needle, string message = "") {
    if (StringFind(haystack, needle) >= 0) {
        string fail_msg = StringFormat("AssertNotContains failed: \"%s\" found in \"%s\"",
                                       needle, haystack);
        if (message != "") fail_msg += " - " + message;
        FailTest(fail_msg);
        return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| AssertArraySize - Kontrollera array-storlek                       |
//+------------------------------------------------------------------+
template<typename T>
bool AssertArraySize(const T &arr[], int expected_size, string message = "") {
    int actual_size = ArraySize(arr);
    if (actual_size != expected_size) {
        string fail_msg = StringFormat("AssertArraySize failed: expected %d, got %d",
                                       expected_size, actual_size);
        if (message != "") fail_msg += " - " + message;
        FailTest(fail_msg);
        return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| PrintTestSummary - Skriv ut testsammanfattning                    |
//+------------------------------------------------------------------+
void PrintTestSummary() {
    Print("");
    Print("========================================");
    Print("TEST SUMMARY");
    Print("========================================");
    Print("Total tests:  ", g_tests_total);
    Print("Passed:       ", g_tests_passed);
    Print("Failed:       ", g_tests_failed);

    double pass_rate = (g_tests_total > 0) ?
                       (double)g_tests_passed / g_tests_total * 100.0 : 0.0;
    Print("Pass rate:    ", DoubleToString(pass_rate, 1), "%");
    Print("========================================");

    if (g_tests_failed > 0) {
        Print("");
        Print("FAILED TESTS:");
        for (int i = 0; i < g_result_count; i++) {
            if (!g_test_results[i].passed) {
                Print("  - ", g_test_results[i].test_name);
                Print("    ", g_test_results[i].message);
            }
        }
    }

    Print("");
    if (g_tests_failed == 0) {
        Print("STATUS: ALL TESTS PASSED");
    } else {
        Print("STATUS: TESTS FAILED");
    }
    Print("========================================");
}

//+------------------------------------------------------------------+
//| AllTestsPassed - Returnera true om alla tester passerade          |
//+------------------------------------------------------------------+
bool AllTestsPassed() {
    return g_tests_failed == 0;
}

//+------------------------------------------------------------------+
//| GetTestResults - Hämta testresultat                               |
//+------------------------------------------------------------------+
int GetTestResults(TestResult &results[]) {
    ArrayResize(results, g_result_count);
    for (int i = 0; i < g_result_count; i++) {
        results[i] = g_test_results[i];
    }
    return g_result_count;
}

//+------------------------------------------------------------------+
