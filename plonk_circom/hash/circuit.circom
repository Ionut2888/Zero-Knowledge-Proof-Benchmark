pragma circom 2.0.0;
include "../circomlib/circuits/poseidon.circom";

template Main() {
    signal input secret;
    signal input publicHash;     // public input to compare against
    signal output computedHash;

    component hasher = Poseidon(1);
    hasher.inputs[0] <== secret;
    computedHash <== hasher.out;

    // Assert that the computed hash matches the given public hash
    computedHash === publicHash;
}

component main = Main();
