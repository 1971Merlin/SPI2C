This is a practical example of putting the SPI2C board to good use. It allows the conection of an AT or PS/2 keyoard, or a PS/2 mouse.

Sample code is provided to read in keystrokes or mouse data, and putputs it to the serial terminal. Note you will need the spi2c_library.asm file from the main SPI2C folder also, to assemble the code yourself.

The following diagram shows how the connectors should be wired. Note that only *ONE* device can be connected at a time - you cannot have both a keyboard and a mouse both connected at the same time.

![Connector Schematic](Connector%20Schematic.jpg)
