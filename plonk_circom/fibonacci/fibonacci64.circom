pragma circom 2.0.3;

template Fibonacci64() {
    // Public input: expected result
    signal input expected_result;
    // Output: the computed Fibonacci number
    signal output out;

    // Arrays to store each step
    signal a[64];
    signal b[64];

    // Initialize
    a[0] <== 1;
    b[0] <== 1;

    
    for (var i = 1; i < 64; i++) {
        a[i] <== b[i-1];
        b[i] <== a[i-1] + b[i-1];
    }

    // Assign the result to a variable
    signal result;
    result <== b[63];

    // Output and constraint use 'result'
    out <== result;
    expected_result === result;
}

component main = Fibonacci64();