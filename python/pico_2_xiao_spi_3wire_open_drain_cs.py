import machine

spi = machine.SPI(0, baudrate=1000000, polarity=1, phase=1, bits=8, firstbit=machine.SPI.MSB,
                  sck=machine.Pin(2), mosi=machine.Pin(3), miso=machine.Pin(4))

spi_cs = machine.Pin(1, machine.Pin.OPEN_DRAIN)
spi_cs.value(1) # active low
write_bytes = bytearray([0x00] * 2)

print("Write to Address 0x00 Data 0xE5")
spi_cs.value(0)
spi.write_readinto(bytearray([0x00, 0xE5]),write_bytes)
spi_cs.value(1) 
print(list(map(hex, write_bytes)))

# buffer for echoed first write byte and then two bytes read data
read_bytes = bytearray([0x00] * 3)

print("Read from Address 0x00")
spi_cs.value(0)
spi.write_readinto(bytearray([0x80, 0x00, 0x00]),read_bytes)
spi_cs.value(1) 
print(list(map(hex, read_bytes)))

print("Write to Address 0x00 Data 0x01, 41ms until SPI_CS interrupt")
spi_cs.value(0)
spi.write_readinto(bytearray([0x00, 0x01]),write_bytes)
spi_cs.value(1)

print("Trigger timer by writing any non-zero value to address 0x01")
spi_cs.value(0)
spi.write_readinto(bytearray([0x01, 0x01]),write_bytes)
spi_cs.value(1)

def callback(pin):
    spi_cs.irq(trigger=0, handler=None)
    if (spi_cs.value() == 1):
        print("Write to Address 0x00 Data 0x01, 41ms until SPI_CS interrupt")
        spi_cs.value(0)
        spi.write_readinto(bytearray([0x01, 0x01]),write_bytes)
        spi_cs.value(1)
        spi_cs.irq(trigger=machine.Pin.IRQ_RISING, handler=callback)

callback(1)