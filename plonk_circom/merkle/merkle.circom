pragma circom 2.0.0;

include "../circomlib/circuits/poseidon.circom";
include "../circomlib/circuits/comparators.circom";

template MerkleProof(depth) {
    signal input leaf;
    signal input proof[depth];
    signal input indexBits[depth];
    signal input root;

    signal output out;

    signal hashPath[depth + 1];
    hashPath[0] <== leaf;

    signal left[depth];
    signal right[depth];
    signal notIndex[depth];
    signal leftA[depth];
    signal leftB[depth];
    signal rightA[depth];
    signal rightB[depth];
    component poseidonHash[depth];

    for (var i = 0; i < depth; i++) {
        notIndex[i] <== 1 - indexBits[i];

        leftA[i] <== indexBits[i] * proof[i];
        leftB[i] <== notIndex[i] * hashPath[i];
        left[i] <== leftA[i] + leftB[i];

        rightA[i] <== indexBits[i] * hashPath[i];
        rightB[i] <== notIndex[i] * proof[i];
        right[i] <== rightA[i] + rightB[i];

        poseidonHash[i] = Poseidon(2);
        poseidonHash[i].inputs[0] <== left[i];
        poseidonHash[i].inputs[1] <== right[i];
        hashPath[i + 1] <== poseidonHash[i].out;
    }

    component eq = IsEqual();
    eq.in[0] <== hashPath[depth];
    eq.in[1] <== root;
    out <== eq.out;
}

component main = MerkleProof(3);