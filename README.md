# ZKP Benchmark Suite

A comprehensive benchmarking framework for Zero-Knowledge Proof systems comparing performance across different implementations and circuit types.

## Overview

This benchmark suite implements three main types of circuits:
- **Fibonacci**: Computing Fibonacci sequences with different iteration counts
- **Hash**: Poseidon hash function implementations
- **Merkle**: Merkle tree inclusion/exclusion proofs

Across three different ZKP systems:
- **Groth16 with ZoKrates**: Using the ZoKrates toolchain
- **PLONK with Circom**: Using Circom and SnarkJS
- **STARK with Winterfell**: Using the Winterfell library (Fibonacci and Merkle implementations use built-in examples from the Winterfell library)


Each circuit directory contains:
- Source code files (`.zok`, `.circom`, `.rs`)
- Test scripts (`test.sh`, `average.sh`)
- Generated artifacts (proofs, keys, witnesses)

## Prerequisites

### System Requirements
- **Linux** (tested on Ubuntu/Debian)
- **Node.js** (v16 or higher)
- **Python 3**
- **Rust** (latest stable)
- **ZoKrates** (latest version)
- **Circom** (v2.0+)
- **SnarkJS** (latest version)
- **Winterfell** (latest version)

### Install Dependencies

#### 1. Node.js and npm
```bash
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs
```

#### 2. ZoKrates
```bash
curl -LSfs get.zokrat.es | sh
```

#### 3. Circom
```bash
# Install from GitHub releases
wget https://github.com/iden3/circom/releases/latest/download/circom-linux-amd64
sudo mv circom-linux-amd64 /usr/local/bin/circom
sudo chmod +x /usr/local/bin/circom
```

#### 4. SnarkJS
```bash
npm install -g snarkjs
```

#### 5. Rust and Cargo
```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source ~/.cargo/env
```

#### 6. Python 3 (usually pre-installed)
```bash
sudo apt-get install python3 python3-pip
```

#### 7. Install Circomlib dependencies (for PLONK/Circom)
```bash
cd plonk_circom/circomlib
npm install
```

#### 8. Build Winterfell library
```bash
cd winterfell
cargo build --release
```

#### 9. Build Winterfell project (for STARK)
```bash
cd stark_winterfell
cargo build --release
```

## Running Benchmarks

### Groth16 with ZoKrates

#### Fibonacci
```bash
cd groth16_zokrates/fibonacci
./test.sh
# For averaged results over multiple runs:
./average.sh
```

#### Hash
```bash
cd groth16_zokrates/hash/scripts
./test.sh
# For averaged results:
./average.sh
```

#### Merkle Tree
```bash
cd groth16_zokrates/merkle
# Run with hardcoded parameters (depth 15):
./test.sh
# For averaged results with different depths:
./average.sh -n 3
./average.sh -n 7
./average.sh -n 15
```

### PLONK with Circom

#### Fibonacci
```bash
cd plonk_circom/fibonacci
./test.sh
# For averaged results:
./average.sh
```

#### Hash
```bash
cd plonk_circom/hash/scripts
./test.sh
# For averaged results:
./average.sh
```

#### Merkle Tree
```bash
cd plonk_circom/merkle
# Run with different tree depths (3, 7, or 15)
./test.sh -n 3
./test.sh -n 7
./test.sh -n 15
# For averaged results (specify depth with -n flag):
./average.sh -n 3
./average.sh -n 7
./average.sh -n 15
```

### STARK with Winterfell

#### Fibonacci
```bash
cd winterfell
./target/release/winterfell fib -n 1024
# Note: inputs should be powers of 2 up to 2^22
```

#### Hash 
```bash
cd stark_winterfell
cargo run --release
```

#### Merkle Tree
```bash
cd winterfell
./target/release/winterfell merkle -n 15
# Note: valid inputs are 3, 7, or 15
```

## Measured Metrics

Each benchmark measures:
- **Setup Time**: Key generation and circuit compilation (only for Groth16 and Plonk)
- **Witness Generation**: Computing private inputs
- **Proving Time**: ZK proof generation
- **Proof Size**: Size of generated proof in bytes/KB
- **Verification Time**: Proof verification duration

## Command Line Arguments

Some scripts accept command-line arguments for configuration:

### Merkle Tree Scripts
- **PLONK Circom**: Both `test.sh` and `average.sh` require the `-n` flag to specify tree depth:
  ```bash
  ./test.sh -n 15      # Test with depth 15
  ./average.sh -n 7    # Average results with depth 7
  ```
- **ZoKrates**: Only `average.sh` requires the `-n` flag; `test.sh` uses hardcoded depth 15:
  ```bash
  ./test.sh            # Uses depth 15 (hardcoded)
  ./average.sh -n 3    # Average results with depth 3
  ```

### Other Scripts
All other test and average scripts run without arguments and use predefined parameters.

## Statistical Analysis

Most directories contain `average.sh` scripts that run benchmarks multiple times and provide statistical analysis:
- Multiple iterations (can be configured)
- Trimmed mean calculation (removes outliers)
- Standard deviation reporting

## Advanced Usage

### Powers of Tau (for PLONK)
PLONK circuits require trusted setup parameters (Powers of Tau):
- Small circuits use `pot12_final.ptau` (included)
- Larger circuits use `pot15_final.ptau` (generated as needed)

### Circuit Parameter Modification
You can modify circuit parameters by editing:
- **ZoKrates**: `.zok` files in respective directories
- **Circom**: `.circom` files in respective directories

## Customization

### Customizing Circuit Parameters

You can modify the circuits to work with different inputs and parameters:

#### Fibonacci Circuits

**ZoKrates (`fibonacci.zok`)**:
```zokrates
def main(u64 expected_result) -> u64 {
    u64 mut a = 1;
    u64 mut b = 1;
    for u32 i in 2..64 {  // Change 64 to desired iteration count
        u64 next = a + b;
        a = b;
        b = next;
    }
    assert(b == expected_result);
    return b;
}
```

**Circom (`fibonacci64.circom`)**:
```circom
template Fibonacci64() {
    signal a[64];  // Change array size to match iterations
    signal b[64];  // Change array size to match iterations
    
    // Update loop bounds in the circuit accordingly
    for (var i = 1; i < 64; i++) {  // Change 64 to desired count
        // ...existing code...
    }
}
```

### Merkle Tree Circuits

**ZoKrates (`merkle.zok`)**:
```zokrates
def main(
    field leaf,
    field[15] proof,     // Change 15 to desired depth
    bool[15] indexBits,  // Change 15 to desired depth  
    field root
) -> bool {
    // ...existing code...
    for u32 i in 0..15 {  // Change 15 to desired depth
        // ...existing code...
    }
}
```

**Circom (`merkle.circom`)**:
```circom
template MerkleProof(depth) {  // Parameterized by depth
    signal input leaf;
    signal input proof[depth];      // Uses depth parameter
    signal input indexBits[depth];  // Uses depth parameter
    signal input root;
    // ...existing code...
}

component main = MerkleProof(15);  // Change 15 to desired depth
```

### Important Notes

1. **Field Size Limits**: All frameworks work with finite fields. Large numbers may need to be split across multiple field elements.

2. **Circuit Size**: Larger parameters increase:
   - Compilation time
   - Proof generation time
   - Memory requirements
   - Required Powers of Tau ceremony size (for PLONK)

3. **Trusted Setup**: PLONK circuits may need larger Powers of Tau files for bigger circuits. Generate with:
   ```bash
   snarkjs powersoftau new bn128 [power] ceremony.ptau
   # where power determines max circuit size (2^power constraints)
   ```

## Troubleshooting

### Common Issues

1. **Missing dependencies**: Ensure all tools are in PATH
2. **Permission errors**: Make scripts executable with `chmod +x *.sh`
3. **Memory issues**: Large circuits may require more RAM
4. **Path issues**: Run scripts from their respective directories

### ZoKrates Issues
```bash
# If ZoKrates command not found:
export PATH="$HOME/.zokrates/bin:$PATH"
```

### Circom Issues
```bash
# If circom command not found:
which circom
# Should show /usr/local/bin/circom or similar
```

### Node.js Issues
```bash
# If witness generation fails:
cd plonk_circom/circomlib
npm install
```

### Rust Issues
```bash
# If Cargo build fails:
cd stark_winterfell
cargo clean
cargo build --release
```

