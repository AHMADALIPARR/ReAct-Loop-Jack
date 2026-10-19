# Stage 1: The Liquid Haskell / GHC Black Box Gate
FROM alpine:3.19 AS builder

# Install musl, static GMP, and Z3 for Liquid Haskell verification
RUN apk add --no-cache ghc cabal musl-dev gmp-dev z3 build-base linux-headers

WORKDIR /workspace
# Repo layout: Haskell sources live in src/ (hs-source-dirs: src),
# Lean proof in lean/, Elixir supervisor in supervisor/.
COPY . .

# Initialize cabal and compile. 
# GHC uses Liquid Haskell as a plugin; if GoodState is violated, it exits with a non-zero code.
RUN cabal update && \
    cabal build --enable-executable-static

# Extract the compiled binary path
RUN cp $(cabal list-bin mobius-worker) /mobius-worker

# Stage 2: The Sovereign Worker Node (Absolute Scratch)
FROM scratch
COPY --from=builder /mobius-worker /mobius-worker

ENTRYPOINT ["/mobius-worker"]
