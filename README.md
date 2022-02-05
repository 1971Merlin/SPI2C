# SPI2C
SPI2C interface hardware and software for the TEC-1 and SC-1 family of Z80 single board computers

Please see https://github.com/tec1group for information on the TEC computer.

The spi_7segs code links an 8 digit, 7-segment display (SPI bus, Duinotech XC-3714) to the SC1. 

The i2c test.asm code expands on the first sample, adding a DS1307 based clock module (i2c bus, Duinotech XC-4450) which then displays the time on the 7-segment SPI board. The i2c code is also designed to be 'universal', compiling for eithe rthe TEC-1 ir the SC-1 hardware platforms.

