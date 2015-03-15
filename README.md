# GyroMouse

**GyroMouse** is an open-source app that enables one to use an Android device as a mouse on Linux, intended for VR-like control such as [Google Cardboard](https://cardboard.withgoogle.com/).

The implementation consists of two components:

* An Android app that sends current gyroscope readings over the network via UDP.
* A receiver on the Linux side that creates a virtual input device via `uinput` and translates the gyroscope data into mouse movement events.

## Usage

1. Build and install the Android app in `sender/` directory: `sbt install`.
2. Build the receiver in `receiver/` directory: `cabal build`.
3. Make sure you have read/write access to `/dev/uinput`, using udev rules:
```
    # cat > /etc/udev/rules.d/70-uinput.rules << EOF
    KENREL=="uinput", OWNER="$your_username_here"
    EOF
    # udevadm control --reload-rules
    # modprobe uinput
```
4. Run the receiver (specify the address and port to listen): `cabal run $ip $port`.
5. Open the app on Android and enter the IP address and port the receiver is listening on.
6. Tap "Enable" and rotating the device should also move the mouse on the receiver side.

## Notes

There is no support for authentication and encryption of the transmitted data, so it is essentially allowing remote control and sniffing of movement data of your mouse. It's highly recommended you run this in a secure private network, via a ssh-tunnel, or via Android USB tethering.

## License

GPLv3
