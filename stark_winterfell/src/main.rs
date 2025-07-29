use std::time::Instant;
use winterfell::{
    crypto::{DefaultRandomCoin, MerkleTree, hashers::Rp64_256, ElementHasher},
    math::{fields::f64::BaseElement, FieldElement, ToElements},
    Air, AirContext, Assertion, EvaluationFrame, ProofOptions, Prover, StarkDomain, TraceInfo,
    TraceTable, BatchingMethod, FieldExtension,
    AuxRandElements, CompositionPoly, CompositionPolyTrace,
    DefaultConstraintCommitment, DefaultConstraintEvaluator, DefaultTraceLde, TransitionConstraintDegree,
    matrix::ColMatrix,Proof,
};

const TRACE_WIDTH: usize = 6;
const TRACE_LENGTH: usize = 8;

#[derive(Clone, Debug, PartialEq)]
pub struct PublicInputs {
    pub input: [BaseElement; 4],
    pub hash: [BaseElement; 2],
}
impl ToElements<BaseElement> for PublicInputs {
    fn to_elements(&self) -> Vec<BaseElement> {
        let mut elts = self.input.to_vec();
        elts.extend(self.hash);
        elts
    }
}

pub struct RpoHashAir {
    context: AirContext<BaseElement>,
    input: [BaseElement; 4],
    hash: [BaseElement; 2],
}
impl Air for RpoHashAir {
    type BaseField = BaseElement;
    type PublicInputs = PublicInputs;

    fn new(trace_info: TraceInfo, pub_inputs: PublicInputs, options: ProofOptions) -> Self {
        let degrees = vec![
            TransitionConstraintDegree::new(1),
            TransitionConstraintDegree::new(1),
            TransitionConstraintDegree::new(1),
        ];
        Self {
            context: AirContext::new(trace_info, degrees, TRACE_WIDTH, options),
            input: pub_inputs.input,
            hash: pub_inputs.hash,
        }
    }

    fn context(&self) -> &AirContext<Self::BaseField> {
        &self.context
    }

    fn evaluate_transition<E: FieldElement<BaseField = Self::BaseField>>(
        &self,
        _frame: &EvaluationFrame<E>,
        _periodic_values: &[E],
        result: &mut [E],
    ) {
        result.fill(E::ZERO);
    }

    fn get_assertions(&self) -> Vec<Assertion<Self::BaseField>> {
        vec![
            Assertion::single(0, 0, self.input[0]),
            Assertion::single(1, 0, self.input[1]),
            Assertion::single(2, 0, self.input[2]),
            Assertion::single(3, 0, self.input[3]),
            Assertion::single(4, TRACE_LENGTH - 1, self.hash[0]),
            Assertion::single(5, TRACE_LENGTH - 1, self.hash[1]),
        ]
    }
    
}

struct RpoProver {
    options: ProofOptions,
}
impl RpoProver {
    pub fn new(options: ProofOptions) -> Self {
        Self { options }
    }
}
impl Prover for RpoProver {
    type BaseField = BaseElement;
    type Air = RpoHashAir;
    type Trace = TraceTable<BaseElement>;
    type HashFn = Rp64_256;
    type VC = MerkleTree<Rp64_256>;
    type RandomCoin = DefaultRandomCoin<Rp64_256>;
    type TraceLde<E: FieldElement<BaseField = Self::BaseField>> =
        DefaultTraceLde<E, Self::HashFn, Self::VC>;
    type ConstraintCommitment<E: FieldElement<BaseField = Self::BaseField>> =
        DefaultConstraintCommitment<E, Self::HashFn, Self::VC>;
    type ConstraintEvaluator<'a, E: FieldElement<BaseField = Self::BaseField>> =
        DefaultConstraintEvaluator<'a, Self::Air, E>;

    fn get_pub_inputs(&self, trace: &Self::Trace) -> PublicInputs {
        PublicInputs {
            input: [
                trace.get(0, 0),
                trace.get(1, 0),
                trace.get(2, 0),
                trace.get(3, 0),
            ],
            hash: [
                trace.get(4, TRACE_LENGTH - 1),
                trace.get(5, TRACE_LENGTH - 1),
            ],
        }
    }

    fn options(&self) -> &ProofOptions {
        &self.options
    }

    fn new_trace_lde<E: FieldElement<BaseField = Self::BaseField>>(
        &self,
        trace_info: &TraceInfo,
        main_trace: &ColMatrix<Self::BaseField>,
        domain: &StarkDomain<Self::BaseField>,
        partition_option: winterfell::PartitionOptions,
    ) -> (Self::TraceLde<E>, winterfell::TracePolyTable<E>) {
        DefaultTraceLde::new(trace_info, main_trace, domain, partition_option)
    }

    fn build_constraint_commitment<E: FieldElement<BaseField = Self::BaseField>>(
        &self,
        composition_poly_trace: CompositionPolyTrace<E>,
        num_constraint_composition_columns: usize,
        domain: &StarkDomain<Self::BaseField>,
        partition_options: winterfell::PartitionOptions,
    ) -> (Self::ConstraintCommitment<E>, CompositionPoly<E>) {
        DefaultConstraintCommitment::new(
            composition_poly_trace,
            num_constraint_composition_columns,
            domain,
            partition_options,
        )
    }

    fn new_evaluator<'a, E: FieldElement<BaseField = Self::BaseField>>(
        &self,
        air: &'a Self::Air,
        aux_rand_elements: Option<AuxRandElements<E>>,
        composition_coefficients: winterfell::ConstraintCompositionCoefficients<E>,
    ) -> Self::ConstraintEvaluator<'a, E> {
        DefaultConstraintEvaluator::new(air, aux_rand_elements, composition_coefficients)
    }
}

fn main() {
    // Set up inputs
    let input = [
        BaseElement::new(111),
        BaseElement::new(222),
        BaseElement::new(333),
        BaseElement::new(444),
    ];

    let digest = Rp64_256::hash_elements(&input);
    let hash_elems = digest.as_elements();

    let mut cols = vec![vec![BaseElement::ZERO; TRACE_LENGTH]; 6];
    for i in 0..4 {
        cols[i][0] = input[i];
    }
    cols[4][TRACE_LENGTH - 1] = hash_elems[0];
    cols[5][TRACE_LENGTH - 1] = hash_elems[1];

    let trace = TraceTable::init(cols);

    let options = ProofOptions::new(
        32, 8, 0,
        FieldExtension::None,
        2, 15,
        BatchingMethod::Linear,
        BatchingMethod::Linear,
    );

    // Match the stylized runner output!
    println!("---------------------");

    // Proof generation with timing
    let now = Instant::now();
    let prover = RpoProver::new(options.clone());
    let proof = prover.prove(trace.clone()).unwrap();
    let ms = now.elapsed().as_millis();
    println!("Proof generated in {} ms", ms);

    let proof_bytes = proof.to_bytes();
    let proof_size_kb = (proof_bytes.len() as f64) / 1024.0;
    println!("Proof size: {:.1} KB", proof_size_kb);

    let conjectured_security_level = 60; // Use the appropriate value if available!
    println!("Proof security: {} bits", conjectured_security_level);

    // Print a hash of the proof bytes using blake3
    

    println!("---------------------");
    let parsed_proof = Proof::from_bytes(&proof_bytes).unwrap();
    assert_eq!(proof, parsed_proof);

    let pub_inputs = PublicInputs {
        input,
        hash: [hash_elems[0], hash_elems[1]],
    };

    let min_opts = winterfell::AcceptableOptions::MinConjecturedSecurity(conjectured_security_level);
    let now = Instant::now();
    let is_ok = winterfell::verify::<RpoHashAir, Rp64_256, DefaultRandomCoin<Rp64_256>, MerkleTree<Rp64_256>>(
        parsed_proof, // proof
        pub_inputs.clone(),
        &min_opts,
    );
    let verify_ms = now.elapsed().as_micros() as f64 / 1000.0;

    match is_ok {
        Ok(_) => println!("Proof verified in {:.1} ms", verify_ms),
        Err(e) => println!("Failed to verify proof: {e:?}"),
    }
}
