module Main where

import System.Environment
import System.IO
import qualified Data.ByteString.Char8 as B
import Control.Parallel.Strategies
import Control.Concurrent.Chan
import Control.Concurrent

pipeData messages progress chunkSize (name, inputHandle, outputHandle) = do
  chunk <- B.hGet inputHandle chunkSize
  if chunk == B.empty
    then do
      hClose inputHandle
      hClose outputHandle
      return ()
    else do
      writeChan messages (name, progress)
      B.hPut outputHandle chunk
      hFlush outputHandle
      pipeData messages (progress + chunkSize) chunkSize (name, inputHandle, outputHandle)

monitor messages delay done = do
  stop <- isEmptyMVar done
  if stop
    then putMVar done ()
    else do
      msg <- readChan messages
      print msg
      threadDelay delay
      monitor messages delay done

main :: IO ()
main = do
  (input:outputs) <- getArgs
  putStrLn $ "Reading from " ++ input ++ " and writing to " ++ (show outputs)

  handles <- sequence $ map (\file -> do
                 inputHandle <- openFile input ReadMode
                 outputHandle <- openFile file WriteMode
                 return (input ++ " -> " ++ file, inputHandle, outputHandle)) outputs :: IO [(String, Handle, Handle)]
  messages <- newChan
  done <- newMVar ()
  thread <- forkIO (monitor messages 1000 done)
  sequence_ $ parMap rpar (pipeData messages 0 4096) handles
  takeMVar done
  takeMVar done
