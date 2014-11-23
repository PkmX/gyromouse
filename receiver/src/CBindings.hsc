#include <bindings.dsl.h>
#include <fcntl.h>
#include <linux/uinput.h>
#include <sys/ioctl.h>
#include <sys/time.h>

module CBindings where
#strict_import
import Control.Applicative
import Foreign.Storable
import System.Posix.Types

#integral_t __u16
#integral_t __s32

#starttype struct input_id
#field bustype, <__u16>
#field vendor, <__u16>
#field product, <__u16>
#field version, <__u16>
#stoptype

#starttype struct uinput_user_dev
#array_field name, CChar
#field id, <struct input_id>
#stoptype

#starttype struct timeval
#stoptype

#starttype struct input_event
#field time, <struct timeval>
#field type, <__u16>
#field code, <__u16>
#field value, <__s32>
#stoptype

evSyn, evKey, evRel :: (Num a) => a
#num EV_SYN
evSyn = c'EV_SYN
#num EV_KEY
evKey = c'EV_KEY
#num EV_REL
evRel = c'EV_REL

synReport, relx, rely, btnLeft :: (Num a) => a
#num SYN_REPORT
synReport = c'SYN_REPORT
#num REL_X
relx = c'REL_X
#num REL_Y
rely = c'REL_Y
#num BTN_LEFT
btnLeft = c'BTN_LEFT

uiSetEvBit, uiSetRelBit, uiSetKeyBit, uiDevCreate, uiDevDestroy, busUsb :: (Num a) => a
#num UI_SET_EVBIT
uiSetEvBit = c'UI_SET_EVBIT
#num UI_SET_KEYBIT
uiSetKeyBit = c'UI_SET_KEYBIT
#num UI_SET_RELBIT
uiSetRelBit = c'UI_SET_RELBIT
#num UI_DEV_CREATE
uiDevCreate = c'UI_DEV_CREATE
#num UI_DEV_DESTROY
uiDevDestroy = c'UI_DEV_DESTROY
#num BUS_USB
busUsb = c'BUS_USB

#ccall ioctl, CInt -> CInt -> CInt -> IO CInt
ioctlFd :: Fd -> Int -> Int -> IO Fd
ioctlFd (Fd fd) x y = (Fd . fromIntegral) <$> c'ioctl fd (fromIntegral x) (fromIntegral y)

#ccall gettimeofday, Ptr <timeval> -> Ptr () -> IO CInt