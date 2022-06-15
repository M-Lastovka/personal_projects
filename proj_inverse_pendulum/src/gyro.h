/*
 * gyro.h
 *
 * Created: 18.12.2021 15:50:08
 *  Author: BB
 */ 


#ifndef GYRO_H_
#define GYRO_H_

#define GYRO_READ						0x80
#define GYRO_WRITE						0x0
#define GYRO_FSEL_250				    0x00
#define GYRO_XG_FIFO_EN				    0x40
#define GYRO_DATA_RDY_EN				0x01
#define GYRO_DLPF_CFG_256				0x01
#define GYRO_I2C_IF_DIS					0x10
#define GYRO_SIG_COND_RESET				0x01
#define GYRO_STBY_XA					0x20
#define GYRO_STBY_YA					0x10
#define GYRO_STBY_ZA					0x08
#define GYRO_STBY_YG					0x02
#define GYRO_STBY_XG					0x04
#define GYRO_DEVICE_RESET				0x80
#define GYRO_DIS_SLEEP					0x00

#define GYRO_REG_WHO_AM_I				0x75
#define GYRO_REG_CONFIG				    0x1A
#define GYRO_REG_SMPLRT_DIV				0x19
#define GYRO_REG_GYRO_CONFIG			0x1B
#define GYRO_REG_FIFO_EN				0x23
#define GYRO_REG_INT_ENABLE				0x38
#define GYRO_REG_GYRO_ZOUT_MSB			0x47
#define GYRO_REG_GYRO_ZOUT_LSB			0x48
#define GYRO_REG_USER_CTRL				0x6A
#define GYRO_REG_PWR_MGMT_1				0x6B
#define GYRO_REG_PWR_MGMT_2				0x6C

#endif /* GYRO_H_ */ */