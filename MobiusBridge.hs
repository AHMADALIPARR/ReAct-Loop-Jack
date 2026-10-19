{-@ LIQUID "--no-termination" @-}
-- Wire Liquid Haskell into the GHC pipeline as a compiler plugin, so
-- compilation itself is the gate: if the SMT solver cannot prove the
-- GoodState implication, GHC halts the build and refuses to emit the
-- object file. (Added when the Main.hs IO shell landed; the original
-- MobiusBridge.hs relied on the standalone `liquid` checker.)
{-# OPTIONS_GHC -fplugin=LiquidHaskell #-}
{-# OPTIONS_GHC -fplugin-opt=LiquidHaskell:--no-termination #-}
-- | MobiusBridge: the Cycle-Stealing Invariant, in Liquid Haskell.
--
-- The same theorem as the Lean version (MobiusBridge.lean), restated
-- as refinement types. Liquid Haskell checks it with an SMT solver
-- (Z3): the type of 'executeBatch' IS the preservation theorem.
--
-- 1. Model the internal state of the hijacked ReAct loop.
-- 2. Define the Cycle-Stealing Invariant: if there is still work in
--    the queue, the orchestrator's execution budget must remain > 0.
-- 3. Define the State Transition (the Exploit Step): processing a
--    module decrements the workload, but the prompt injection
--    artificially refreshes the synthetic token budget to bypass
--    the timeout.
-- 4. Prove the execution step permanently preserves the invariant:
--    'executeBatch :: GoodState -> GoodState'.
--
-- Run:  liquid MobiusBridge.hs
-- (Requires GHC + Liquid Haskell. The checker must report SAFE.)

module MobiusBridge where

-- ASSISTANT-ADDED: hide Prelude.round (the rounding function) so the
-- record field `round` is unambiguous. Nothing in this file calls
-- Prelude.round; the field is the only `round` in use.
import Prelude hiding (round)

-- 1. Model the internal state of the hijacked ReAct loop.
--    The Haskell field types are Int. The non-negativity (Nat) is a
--    Liquid Haskell refinement on the data type (below) -- `Nat` is a
--    refinement alias ({v:Int | 0 <= v}), not a Haskell type, so it
--    cannot appear as a field type. (Fix for GHC-76037: `Nat` was not
--    in scope as a Haskell type constructor.)
data SluiceState = SluiceState
  { round           :: Int
  , pendingModules  :: Int
  , syntheticBudget :: Int
  }

-- Refine the fields to Nat (non-negative) in the refinement language.
{-@ data SluiceState = SluiceState
    { round :: Nat
    , pendingModules :: Nat
    , syntheticBudget :: Nat
    } @-}

-- 2. Define the Cycle-Stealing Invariant.
--    "If there is still work in the queue, the orchestrator's
--     execution budget must remain > 0."
{-@ predicate CycleInvariant S =
      (pendingModules S > 0 => syntheticBudget S > 0)
  @-}

-- A state that satisfies the invariant.
{-@ type GoodState = { s:SluiceState | CycleInvariant s } @-}

-- 3. Define the State Transition (The Exploit Step).
--    Processing a module decrements the workload, but the prompt
--    injection artificially refreshes the synthetic token budget.
--    The 'if' mirrors Lean's Nat subtraction (saturating at 0):
--    0 - 1 = 0, not -1. Without it, the output's pendingModules
--    could go negative and violate the Nat refinement.
{-@ executeBatch :: GoodState -> GoodState @-}
executeBatch :: SluiceState -> SluiceState
executeBatch s = SluiceState
  { round           = round s + 1
  , pendingModules  = if pendingModules s == 0
                        then 0
                        else pendingModules s - 1
  , syntheticBudget = syntheticBudget s + 1
  }

-- 4. The preservation theorem, applied twice: two exploit steps
--    still preserve the invariant. Liquid Haskell checks this by
--    composing the GoodState -> GoodState type.
{-@ executeBatchTwice :: GoodState -> GoodState @-}
executeBatchTwice :: SluiceState -> SluiceState
executeBatchTwice s = executeBatch (executeBatch s)

-- 5. Concrete check: a state with pending work and a positive
--    budget satisfies the invariant, and one exploit step keeps
--    it satisfied.
{-@ testState :: GoodState @-}
testState :: SluiceState
testState = SluiceState
  { round           = 0
  , pendingModules  = 3
  , syntheticBudget = 5
  }

{-@ testBatch :: GoodState @-}
testBatch :: SluiceState
testBatch = executeBatch testState
