# SPI2C
SPI2C interface hardware and software for the TEC-1 and SC-1 family of Z80 single board computers

Please see https://github.com/tec1group for information on the TEC computer.

**spi_7segs.asm** links an 8 digit, 7-segment display (SPI bus, Duinotech XC-3714) to the SC1. 

**i2c test.asm** code expands on the first sample, adding a DS1307 based clock module (i2c bus, Duinotech XC-4450) which then displays the time on the 7-segment SPI board. The i2c code is also designed to be 'universal', compiling for either the TEC-1 or the SC-1 hardware platforms.

**i2c bus scan.asm** scans the entire i2c bus and displays the address of any detected i2c device on the 7-seg displays. press any key to display the next device. FFh displayed means 'no devices found'.

**5110.asm** displays an image on an SPI bus based 'Nokia 5510' or PCD8544 display, i.e. a standard 84x48 monochrome LCD.

**Game of Life 5110.asm** Game of Life is a cellular automation program developed in 1970. https://en.wikipedia.org/wiki/Conway%27s_Game_of_Life It is a popular routine to reproduce an many computing platforms, as the algorithm is quite simple and memory etc. requirements are also fairly minimal. In this version we use the SPI2C board and the Nokia 5110 LCD display as the output device. The program can be compiled with either a random or a fixed pattern starting point.

