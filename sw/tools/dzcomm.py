#!/usr/bin/env python3
"""dzcomm.py - the PS7 controller side of the user I/O line tests (2026-11-04),
python3 only (no extra modules; the image has no stty or spidev module).
The board on the other end of the PL_KEY wires runs `dzbus` (sw/tools/dzbus.c)
or this script. Set the line functions first (debazd: dzctl /io/pin <n> <name>).

  dzcomm.py uart-echo <baud> <secs>       echo every byte back (/dev/ttyPS1)
  dzcomm.py uart-test <baud> <bytes>      send random bytes in chunks, compare
                                          the echo: errors, lost bytes, rate
  dzcomm.py spi <hz> <n> [cs]             n frames of 8 bytes (/dev/spidev0.<cs>,
                                          mode 0) against dzbus spisub: CISO
                                          byte k must equal COSI byte k-1
  dzcomm.py i2c <addr> write <reg> <b..>  /dev/i2c-0
  dzcomm.py i2c <addr> read <reg> <n>     (write reg, repeated START, read n)
  dzcomm.py i2c <addr> test <n>           n rounds of write 4 random bytes at a
                                          random reg, read them back, compare
"""
import array, fcntl, os, random, struct, sys, termios, time

BAUD = {9600: termios.B9600, 19200: termios.B19200, 38400: termios.B38400,
        57600: termios.B57600, 115200: termios.B115200, 230400: termios.B230400,
        460800: termios.B460800, 921600: termios.B921600}


def uart_open(baud, dev="/dev/ttyPS1"):
    fd = os.open(dev, os.O_RDWR | os.O_NOCTTY)
    a = termios.tcgetattr(fd)
    a[0] = 0                                    # iflag: raw
    a[1] = 0                                    # oflag
    a[2] = termios.CS8 | termios.CREAD | termios.CLOCAL
    a[3] = 0                                    # lflag
    a[4] = a[5] = BAUD[baud]
    a[6][termios.VMIN] = 0
    a[6][termios.VTIME] = 1                     # reads return after 0.1 s
    termios.tcsetattr(fd, termios.TCSANOW, a)
    termios.tcflush(fd, termios.TCIOFLUSH)
    return fd


def uart_echo(baud, secs):
    fd = uart_open(baud)
    n, end = 0, time.time() + secs
    while time.time() < end:
        b = os.read(fd, 4096)
        if b:
            os.write(fd, b)
            n += len(b)
    print(f"uart-echo {baud}: echoed {n} bytes")


def uart_test(baud, total):
    fd = uart_open(baud)
    rnd = random.Random(1)
    sent = got = bad = 0
    t0 = time.time()
    while sent < total:
        chunk = bytes(rnd.randrange(256) for _ in range(min(64, total - sent)))
        os.write(fd, chunk)
        sent += len(chunk)
        rx, t1 = b"", time.time()
        while len(rx) < len(chunk) and time.time() - t1 < 1.0:
            rx += os.read(fd, len(chunk) - len(rx))
        got += len(rx)
        bad += sum(1 for a, b in zip(chunk, rx) if a != b)
        if len(rx) < len(chunk):
            print(f"  lost {len(chunk) - len(rx)} of a chunk at byte {sent}")
            if not rx:
                break
    dt = time.time() - t0
    print(f"uart-test {baud}: sent {sent}, echoed {got}, wrong {bad}, "
          f"{got / dt:.0f} bytes/s round trip ({'PASS' if got == sent and not bad else 'FAIL'})")


SPI_IOC_WR_MODE = 0x40016B01
SPI_IOC_WR_MAX_SPEED_HZ = 0x40046B04


def SPI_IOC_MESSAGE(n):
    return 0x40006B00 | (32 * n) << 16


def spi(hz, frames, cs=0):
    fd = os.open(f"/dev/spidev0.{cs}", os.O_RDWR)
    fcntl.ioctl(fd, SPI_IOC_WR_MODE, struct.pack("B", 0))
    fcntl.ioctl(fd, SPI_IOC_WR_MAX_SPEED_HZ, struct.pack("I", hz))
    rnd = random.Random(2)
    ok = 0
    for f in range(frames):
        tx = array.array("B", (rnd.randrange(256) for _ in range(8)))
        rx = array.array("B", bytes(8))
        tr = struct.pack("QQIIHBBBBBB", tx.buffer_info()[0], rx.buffer_info()[0], 8, hz, 0, 8,
                         0, 0, 0, 0, 0)
        fcntl.ioctl(fd, SPI_IOC_MESSAGE(1), tr)
        want = bytes([0xA5]) + bytes(tx[:-1])
        good = bytes(rx) == want
        ok += good
        if f < 6 or not good:
            print(f"  COSI {bytes(tx).hex(' ')}  CISO {bytes(rx).hex(' ')}  {'ok' if good else 'want ' + want.hex(' ')}")
        time.sleep(0.02)
    print(f"spi {hz} Hz: {ok} of {frames} frames right ({'PASS' if ok == frames else 'FAIL'})")


I2C_RDWR = 0x0707
I2C_M_RD = 1


def i2c_xfer(fd, addr, msgs):
    """msgs: list of (read, data_or_len); returns the read buffers"""
    bufs, packed = [], b""
    for rd, d in msgs:
        b = array.array("B", bytes(d) if not rd else bytes(d))
        bufs.append(b)
        packed += struct.pack("HHHxxP", addr, I2C_M_RD if rd else 0, len(b), b.buffer_info()[0])
    arr = array.array("B", packed)
    fcntl.ioctl(fd, I2C_RDWR, struct.pack("PI", arr.buffer_info()[0], len(msgs)))
    return [bytes(b) for (rd, _), b in zip(msgs, bufs) if rd]


def i2c(args):
    addr = int(args[0], 0)
    fd = os.open("/dev/i2c-0", os.O_RDWR)
    op = args[1]
    if op == "write":
        reg, data = int(args[2], 0), [int(x, 0) for x in args[3:]]
        i2c_xfer(fd, addr, [(0, [reg] + data)])
        print(f"wrote {len(data)} bytes at reg 0x{reg:02X}")
    elif op == "read":
        reg, n = int(args[2], 0), int(args[3])
        r = i2c_xfer(fd, addr, [(0, [reg]), (1, n)])[0]
        print(f"reg 0x{reg:02X}: {r.hex(' ')}")
    elif op == "test":
        rnd, ok, n = random.Random(3), 0, int(args[2])
        for k in range(n):
            reg = rnd.randrange(250)
            data = [rnd.randrange(256) for _ in range(4)]
            try:
                i2c_xfer(fd, addr, [(0, [reg] + data)])
                back = i2c_xfer(fd, addr, [(0, [reg]), (1, 4)])[0]
            except OSError as e:
                print(f"  round {k}: {e}")
                continue
            good = list(back) == data
            ok += good
            if k < 4 or not good:
                print(f"  reg 0x{reg:02X} wrote {bytes(data).hex(' ')} read {back.hex(' ')} {'ok' if good else 'WRONG'}")
            time.sleep(0.01)
        print(f"i2c 0x{addr:02X}: {ok} of {n} rounds right ({'PASS' if ok == n else 'FAIL'})")


def main(a):
    if len(a) < 2:
        print(__doc__)
        return 2
    if a[1] == "uart-echo":
        uart_echo(int(a[2]), float(a[3]))
    elif a[1] == "uart-test":
        uart_test(int(a[2]), int(a[3]))
    elif a[1] == "spi":
        spi(int(a[2]), int(a[3]), int(a[4]) if len(a) > 4 else 0)
    elif a[1] == "i2c":
        i2c(a[2:])
    else:
        print(__doc__)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
