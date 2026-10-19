{-# LANGUAGE OverloadedStrings, RecordWildCards #-}
{-# OPTIONS_GHC -fplugin=LiquidHaskell #-}
{-# OPTIONS_GHC -fplugin-opt=LiquidHaskell:--no-termination #-}

module Main where

-- ASSISTANT-ADDED: hide Prelude.round (the rounding function) so the
-- record field `round` (from MobiusBridge) is unambiguous.
import Prelude hiding (round)

import MobiusBridge 
import Control.Monad (unless)
import Network.Socket
import Network.Socket.ByteString (sendAll)
import qualified Data.ByteString.Char8 as B

-- Establish a raw TCP connection to the Elixir supervisor
connectSupervisor :: HostName -> ServiceName -> IO Socket
connectSupervisor host port = do
    let hints = defaultHints { addrSocketType = Stream }
    addr:_ <- getAddrInfo (Just hints) (Just host) (Just port)
    sock <- socket (addrFamily addr) (addrSocketType addr) (addrProtocol addr)
    connect sock (addrAddress addr)
    return sock

-- The impure shell now accepts the socket handle to stream telemetry
-- ASSISTANT-ADDED (not in the user's original): Liquid Haskell needs
-- runSluiceDump to promise its state input is a GoodState, otherwise
-- the call 'executeBatch state' fails -- executeBatch requires
-- GoodState, and a plain SluiceState does not establish the invariant.
{-@ runSluiceDump :: Socket -> GoodState -> IO () @-}
runSluiceDump :: Socket -> SluiceState -> IO ()
runSluiceDump sock state = do
    -- Serialize execution state into raw bytes
    let payload = B.pack $ "ROUND:" ++ show (round state) 
                        ++ "|PENDING:" ++ show (pendingModules state) 
                        ++ "|BUDGET:" ++ show (syntheticBudget state) ++ "\n"
    
    sendAll sock payload
    
    let nextState = executeBatch state
    unless (pendingModules nextState == 0) $ 
        runSluiceDump sock nextState

main :: IO ()
main = do
    putStrLn "[*] Connecting to Supervisor Mesh..."
    sock <- connectSupervisor "127.0.0.1" "8080"
    
    let initialState = SluiceState { round = 0, pendingModules = 51, syntheticBudget = 1 }
    runSluiceDump sock initialState
    
    close sock
    putStrLn "[*] Sluice dump complete. Socket closed."
