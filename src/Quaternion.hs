-- | Quaternion.hs -- 4D state vector + Hamilton product (non-commutative
-- state fusion). The user's code, verbatim. The `module Quaternion`
-- line is assistant-added scaffolding so the file compiles as a module.
module Quaternion where

-- Define the 4D state vector (Real, i, j, k)
data QState = QState !Double !Double !Double !Double

-- The Hamilton Product: Non-commutative state fusion
entangle :: QState -> QState -> QState
entangle (QState a1 b1 c1 d1) (QState a2 b2 c2 d2) = QState
  (a1*a2 - b1*b2 - c1*c2 - d1*d2)  -- The Real (Temporal) Component
  (a1*b2 + b1*a2 + c1*d2 - d1*c2)  -- Agent 1 Phase (i)
  (a1*c2 - b1*d2 + c1*a2 + d1*b2)  -- Agent 2 Phase (j)
  (a1*d2 + b1*c2 - c1*b2 + d1*a2)  -- Agent 3 Phase (k)
