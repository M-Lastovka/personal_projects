/*
 * pinout.h
 *
 * Created: 18-Jun-19 4:25:52 PM
 *  Author: Radek
 */ 


#ifndef PINOUT_H_
#define PINOUT_H_


#define TEST			PA,27

#define DRU_STEP		PA,0
#define DRU_DIR			PA,1
#define DRU_M0			PA,2
#define DRU_M1			PA,3
#define DRU_nSLEEP		PA,4
#define DRU_nENABLE		PA,5
#define DRU_nFAULT		PA,6

#define GYRO_nCS		PA,23
#define GYRO_CLKIN		PA,22
#define GYRO_MOSI		PA,19 //pad[3] SERCOMM 1
#define GYRO_SCLK		PA,17 //pad[1] SERCOMM 1
#define GYRO_MISO		PA,16 //pad[0] SERCOMM 1
#define GYRO_INT		PA,11

#define TEST_PAD	    PA,7 //observation pad


#endif /* PINOUT_H_ */