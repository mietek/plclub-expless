module Wh where

----------------------------------------------------------------------

postulate undefined : ∀{ℓ} {A : Set ℓ} → A

open import Function
open import Data.Nat
open import Data.Fin hiding ( lift ) renaming ( Fin to Var; zero to here; suc to there )
open import Relation.Nullary.Decidable using ( True )
open import Data.Vec

----------------------------------------------------------------------

data Wh (γ : ℕ) : Set
data Nu (γ : ℕ) : Set

Env : ℕ → ℕ → Set
Env φ = Vec (Wh φ)

infix 2 _`/_
record Bind (γ : ℕ) : Set where
  inductive
  constructor _`/_
  field
    {scope} : ℕ
    env : Env γ scope
    val : Wh (suc scope)

data Wh γ where
  `Type : Wh γ
  `Π : (A : Wh γ) (B : Bind γ) → Wh γ
  `λ : (b : Bind γ) → Wh γ
  `[_] : Nu γ → Wh γ

data Nu γ where
  `var : (i : Var γ) → Nu γ
  _`∙_ : (f : Nu γ) (a : Wh γ) → Nu γ

----------------------------------------------------------------------

postulate
  wkn : ∀{γ} → Wh γ → Wh (suc γ)
  idEnv : ∀{γ} → Env γ γ

----------------------------------------------------------------------

`∣_∣ : ∀{γ} → Wh (suc γ) → Bind γ
`∣ a ∣ = idEnv `/ a

infixr 3 _`→_
_`→_ : ∀{γ} (A B : Wh γ) → Wh γ
A `→ B = `Π A `∣ wkn B ∣

----------------------------------------------------------------------

`xᴺ : ∀ γ {δ} {γ<δ : True (suc γ ≤? δ)} → Nu δ
`xᴺ γ {γ<δ = γ<δ} = `var (#_ γ {m<n = γ<δ})

`x : ∀ γ {δ} {γ<δ : True (suc γ ≤? δ)} → Wh δ
`x γ {γ<δ = γ<δ} = `[ `xᴺ γ {γ<δ = γ<δ} ]

lift : ∀{φ γ} → Env φ γ → Env (suc φ) (suc γ)
lift σ = `x 0 ∷ map wkn σ

----------------------------------------------------------------------

{-# NO_TERMINATION_CHECK #-}
wh-hsub : ∀{φ γ} → Env φ γ → Wh γ → Wh φ
wh-hsubᴺ : ∀{φ γ} → Env φ γ → Nu γ → Wh φ

wh-hsubᴮ : ∀{φ γ} → Env φ γ → Bind γ → Bind φ
wh-hsubᴮ σ (ρ `/ b) = map (wh-hsub σ) ρ `/ b

_∙_ : ∀{γ} → Wh γ → Wh γ → Wh γ
`λ (σ `/ b) ∙ a = wh-hsub (a ∷ σ) b
`[ f ] ∙ a = `[ f `∙ a ]
f ∙ a = undefined

wh-hsub σ `Type = `Type
wh-hsub σ (`Π A B) = `Π (wh-hsub σ A) (wh-hsubᴮ σ B)
wh-hsub σ (`λ b) = `λ (wh-hsubᴮ σ b)
wh-hsub σ `[ a ] = wh-hsubᴺ σ a

wh-hsubᴺ σ (`var i) = lookup i σ
wh-hsubᴺ σ (f `∙ a) = wh-hsubᴺ σ f ∙ wh-hsub σ a

----------------------------------------------------------------------

data Nf (γ : ℕ) : Set
data Ne (γ : ℕ) : Set

data Nf γ where
  `Type : Nf γ
  `Π : (A : Nf γ) (B : Nf (suc γ)) → Nf γ
  `λ : (b : Nf (suc γ)) → Nf γ
  `[_] : Ne γ → Nf γ

data Ne γ where
  `var : (i : Var γ) → Ne γ
  _`∙_ : (f : Ne γ) (a : Nf γ) → Ne γ

----------------------------------------------------------------------

{-# NO_TERMINATION_CHECK #-}
force : ∀{γ} → Wh γ → Nf γ
forceᴺ : ∀{γ} → Nu γ → Ne γ

forceᴮ : ∀{γ} → Bind γ → Nf (suc γ)
forceᴮ (σ `/ a) = force (wh-hsub (lift σ) a)

force `Type = `Type
force (`Π A B) = `Π (force A) (forceᴮ B)
force (`λ b) = `λ (forceᴮ b)
force `[ a ] = `[ forceᴺ a ]

forceᴺ (`var i) = `var i
forceᴺ (f `∙ a) = forceᴺ f `∙ force a

----------------------------------------------------------------------

data Exp (γ : ℕ) : Set where
  `λ : (b : Exp (suc γ)) → Exp γ
  `var : (i : Var γ) → Exp γ
  _`∙_ : (f : Exp γ) (a : Exp γ) → Exp γ

----------------------------------------------------------------------

Pi : Wh 0
Pi = `Π `Type `∣ `x 0 `→ `Type ∣ `→ `Type

Π' : Wh 0
Π' = `λ `∣ `λ `∣ `Π (`x 1) `∣ `[ `xᴺ 1 `∙ `x 0 ] ∣ ∣ ∣

Prim : ℕ
Prim = 2

----------------------------------------------------------------------

prelude : Env 0 Prim
prelude = Π' ∷ `Type ∷ []

----------------------------------------------------------------------

wh-norm : ∀{γ} → Exp γ → Wh γ
wh-norm (`λ b) = `λ `∣ wh-norm b ∣
wh-norm (`var i) = `[ `var i ]
wh-norm (f `∙ a) = wh-norm f ∙ wh-norm a 

prim-wh-norm : Exp Prim → Wh 0
prim-wh-norm = wh-hsub prelude ∘ wh-norm

norm : ∀{γ} → Exp γ → Nf γ
norm = force ∘ wh-norm

prim-norm : Exp Prim → Nf 0
prim-norm = force ∘ prim-wh-norm

----------------------------------------------------------------------

