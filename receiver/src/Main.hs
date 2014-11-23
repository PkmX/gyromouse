{-# LANGUAGE ScopedTypeVariables #-}

module Main (main) where

import Control.Applicative
import Control.Exception
import Control.Lens
import Control.Monad
import Data.Bits
import Foreign.Ptr
import Foreign.Storable
import Foreign.C.String
import Foreign.C.Types
import Foreign.Marshal
import CBindings
import Network.Socket
import System.Environment
import System.IO
import System.Posix.Files
import System.Posix.IO
import System.Posix.Types

getUInput :: IO Fd
getUInput = do
    fd <- openFd "/dev/uinput" WriteOnly Nothing $ defaultFileFlags { nonBlock = True }
    when (fd < 0) $ throwIO $ userError "open() failed"

    ioctlFd' fd uiSetEvBit evKey
    ioctlFd' fd uiSetKeyBit btnLeft
    ioctlFd' fd uiSetRelBit relx
    ioctlFd' fd uiSetRelBit rely
    ioctlFd' fd uiSetEvBit evRel
    with (C'uinput_user_dev (fmap castCharToCChar "gyrorecv") (C'input_id c'BUS_USB 0 0 0)) $ fdWriteBuf' fd
    ioctlFd' fd uiDevCreate 0
    return fd

closeUInput :: Fd -> IO ()
closeUInput fd = do
    ioctlFd' fd uiDevDestroy 0
    closeFd fd

sendMouseEvent :: Fd -> Int -> Int -> IO ()
sendMouseEvent fd x y = do
    time <- alloca $ \ptv -> c'gettimeofday ptv nullPtr >> peek ptv

    with (C'input_event time evRel relx (fi x)) $ fdWriteBuf' fd
    with (C'input_event time evRel rely (fi y)) $ fdWriteBuf' fd
    with (C'input_event time evSyn synReport 0) $ fdWriteBuf' fd

getSocket :: String -> String -> IO Socket
getSocket ip port = do
    addr : _ <- getAddrInfo Nothing (Just ip) (Just port)
    sock <- socket (addrFamily addr) Datagram defaultProtocol
    bindSocket sock (addrAddress addr)
    hPutStrLn stderr $ "Listening on " ++ show (addrAddress addr)
    return sock

handler :: Socket -> Fd -> IO ()
handler sock fd = forever $ do
    [x, y, z] :: [Double] <- (map read . words . view _1) <$> recvFrom sock 4096
    sendMouseEvent fd (round $ x * (-5)) (round $ y * 20)
    return ()

main :: IO ()
main = do
    ip : port : _ <- getArgs
    bracket (getSocket ip port) sClose $ \s -> bracket getUInput closeUInput (handler s)

ioctlFd' :: Fd -> Int -> Int -> IO ()
ioctlFd' fd x y = ioctlFd fd x y >>= \ret -> when (ret < 0) $ throwIO $ userError "ioctl() failed"

fdWriteBuf' :: forall a. (Storable a) => Fd -> Ptr a -> IO ()
fdWriteBuf' fd p = fdWriteBuf fd (castPtr p) (fi len) >>= \ret -> when (ret /= fi len) $ throwIO $ userError "write() failed"
  where len = sizeOf (undefined :: a)

fi :: (Integral a, Num b) => a -> b
fi = fromIntegral