

#include "sam.h"
#include "pin_macros.h" //for working with pin macros
#include "pinout.h" //definition of pinout
#include "gyro.h"

typedef float dist_m;
typedef float int_dist_ms;
typedef float vel_m_s;
typedef float acc_m_s2;
typedef float time_s;
typedef float freq_hz;
typedef float rad;

#define ABS_VAL(x) (x >= 0 ? x : -x)
#define GYRO_DEG_PER_S_PER_LSB 0.00013
#define MOTOR_STEP_DIST_M 0.0001 //radius = 0.025m, circ = 0.157m, 
#define TIME_STEP_CTRL_S 0.001
#define TIME_STEP_DEST_S 0.1
#define TIME_STEP_DEST_SQ_S (TIME_STEP_DEST_S*TIME_STEP_DEST_S) 
#define TIME_STEP_CTRL_INV_HZ 1000
#define TIME_STEP_CTRL_SQR_S 0.000001
#define FIR_ALPHA 0.2
#define TIME_STEP_DRV_S  0.0002
#define TIME_STEP_DRV_SQR_S 0.00000004
#define PEND_LEN_M 0.15
#define CRITICAL_ANGLE 1.0472 //60 degrees
#define OFFSET -255

#define STEP_DELAY_CYCLES 20


//global variables
//interrupt statistics and control 
uint32_t interrupt_stat_num_eic = 0;
uint32_t interrupt_stat_num_tc4 = 0;
uint8_t interrupt_num_tc4 = 0;

//control loop variables
volatile dist_m bot_pos_now = 0;	//bottom position now
 dist_m bot_pos_dest = 0;	//desired bottom position
 rad pend_angle	  = 0;  //pendulum angle
 dist_m bot_pos_traj = 0;	//trajectory of bottom
volatile vel_m_s bot_vel_traj = 0;	//velocity of bottom trajectory
volatile acc_m_s2 bot_acc_traj = 0;	//acceleration of bottom trajectory

 dist_m top_pos_now = 0;	//top position
 dist_m top_pos_old = 0;	
 vel_m_s top_pos_diff = 0;	//top position derivative
 vel_m_s top_pos_diff_last = 0;	//top position derivative
 vel_m_s top_pos_diff_filt = 0;	//top position derivative
 int_dist_ms top_pos_int = 0;	//top position integrated
 float const_prop = 1.06;	//PID parameters
 float const_diff = 0.1;//0.0002;
 float const_int = 0.0;

 
 //y[n] = alpha*x[k] + (1-alpha)x[k-1]


void delay_cycle(uint16_t num_cyc)
{
	 for(uint16_t i = 0; i < num_cyc; i++)
	 {
		 asm volatile ("nop");
	 }
}


void osc_init(void) 
{	
	SYSCTRL->XOSC.bit.STARTUP = 0xA; //startup time 3 1250us
	SYSCTRL->XOSC.bit.GAIN = 4;	//gain, max freq 30MHz
	SYSCTRL->XOSC.bit.XTALEN = 1; // external crystal
	
	// final oscillator enable
	SYSCTRL->XOSC.bit.ENABLE = 1; 
}



void clk_init(void) // HODINY
{
	// setting clock division
	/*GCLK->GENDIV.bit.ID = 0; // we select the 0th clock signal
	GCLK->GENDIV.bit.DIV = 0; // we do not wish to divide the oscillator signal
	
	// setting of the generator itself
	/*GCLK->GENCTRL.bit.ID = 0;
	GCLK->GENCTRL.bit.DIVSEL = 0; 
	GCLK->GENCTRL.bit.SRC = 0x0; 
	GCLK->GENCTRL.bit.GENEN = 1; */
	
	//while(GCLK->STATUS.bit.SYNCBUSY); // synchronization
	
	GCLK_GENDIV_Type gendiv;
	gendiv.bit.ID = 0; 
	gendiv.bit.DIV = 0; //12 / 10 * 48 / 3 = 19,2MHz
	while(GCLK->STATUS.bit.SYNCBUSY);
	GCLK->GENDIV.reg = gendiv.reg;
	
	GCLK_GENCTRL_Type genctrl = {0};
	genctrl.bit.ID = 0;
	genctrl.bit.DIVSEL = 0;
	genctrl.bit.SRC = 0x0;
	genctrl.bit.GENEN = 1;
	while(GCLK->STATUS.bit.SYNCBUSY);
	GCLK->GENCTRL.reg = genctrl.reg;

}

void drv_init(void) // DRV
{
	DIR_OUT(DRU_nSLEEP);	
	DIR_OUT(DRU_M0);
	DIR_OUT(DRU_M1);
	DIR_OUT(DRU_DIR);
	DIR_OUT(DRU_STEP);
	DIR_IN(DRU_nFAULT);
	DIR_OUT(TEST_PAD);
	//DIR_OUT(DRU_nENABLE);

	RESET(DRU_nSLEEP);
	RESET(DRU_nENABLE);

	SET(DRU_M0);	//dir 0 - 1/8 step
	SET(DRU_M1);
	SET(DRU_STEP);
	RESET(DRU_DIR);
	delay_cycle(300);
	
	SET(DRU_nSLEEP);
	//SET(DRU_M0);	
	//RESET(DRU_M1);
}


void gyro_clk_init(void) // GYRO - CLKIN 19,2 MHz
{
	// setting PLL:
	SYSCTRL->DPLLCTRLB.bit.DIV = 4;
	SYSCTRL->DPLLCTRLB.bit.REFCLK = 1; // PLL fed by external oscillator
	SYSCTRL->DPLLRATIO.bit.LDR = 47;
	SYSCTRL->DPLLRATIO.bit.LDRFRAC = 0;
	SYSCTRL->DPLLCTRLA.bit.ONDEMAND = 0;
	SYSCTRL->DPLLCTRLA.bit.ENABLE = 1;
	while(!SYSCTRL->DPLLSTATUS.bit.LOCK); // locking DPLL
	
	//modified CPU clock, output of PLL
	GCLK_GENDIV_Type gendiv_mod = {0};
	gendiv_mod.bit.ID = 0; // 
	gendiv_mod.bit.DIV = 2; // 1.2*48MHz/2
	while(GCLK->STATUS.bit.SYNCBUSY);
	GCLK->GENDIV.reg = gendiv_mod.reg;
	
	GCLK_GENCTRL_Type genctrl_mod = {0};
	genctrl_mod.bit.ID = 0;
	genctrl_mod.bit.DIVSEL = 0;
	genctrl_mod.bit.SRC = 0x08;
	genctrl_mod.bit.GENEN = 1;
	while(GCLK->STATUS.bit.SYNCBUSY);
	GCLK->GENCTRL.reg = genctrl_mod.reg;

	
	// setting clock division:
	GCLK_GENDIV_Type gendiv;
	gendiv.bit.ID = 6; 
	gendiv.bit.DIV = 3; //12 / 10 * 48 / 3 = 19,2MHz
	while(GCLK->STATUS.bit.SYNCBUSY);
	GCLK->GENDIV.reg = gendiv.reg;
	
	// enabling 6th clock generator:
	GCLK_GENCTRL_Type genctrl;
	genctrl.bit.ID = 6;
	genctrl.bit.DIVSEL = 0;
	genctrl.bit.SRC = 0x08;
	genctrl.bit.GENEN = 1;
	genctrl.bit.OE = 1;
	while(GCLK->STATUS.bit.SYNCBUSY);
	GCLK->GENCTRL.reg = genctrl.reg;
	
	// outputting of clock
	DIR_OUT(GYRO_CLKIN);
	PORT_MUX(GYRO_CLKIN, 7); //MUX na hodiny
}

void gyro_spi_init(void) // SERCOM1 - SPI s GYRO
{
	#define SPI_CLK_FREQ		12000000 // // peripheral is fed from oscillator = 12MHz
	#define SPI_BAUD			1000000 // Baud rate 1MHz = max frequency for SPI gyro bus
	
	// setting of pads:
	DIR_OUT(GYRO_nCS);
	SET(GYRO_nCS);
	DIR_OUT(GYRO_SCLK);
	DIR_OUT(GYRO_MOSI);
	DIR_IN(GYRO_MISO);
	
	PORT_MUX(GYRO_SCLK, 2); //SERCOM1
	PORT_MUX(GYRO_MOSI, 2);
	PORT_MUX(GYRO_MISO, 2);
	
	//peripheral must be first enabled
	//enabling clock:
	GCLK_CLKCTRL_Type clkctrl;
	clkctrl.bit.ID = 0x15; //SERCOMM 1
	clkctrl.bit.GEN = 0x0;
	clkctrl.bit.CLKEN = 0x1;
	while(GCLK->STATUS.bit.SYNCBUSY);
	GCLK->CLKCTRL.reg = clkctrl.reg;
	//REG_GCLK_CLKCTRL = GCLK_CLKCTRL_GEN_GCLK0 | GCLK_CLKCTRL_ID_SERCOM1_CORE | GCLK_CLKCTRL_CLKEN; //mazanej zapis do celeho registru ohledne hodin: hodiny z GCLK0 + jsem na SERCOM1 + enabluju hodiny
	
	//setting of power:
	PM->APBCMASK.bit.SERCOM1_ = 0x1;  //zapnuti periferie SERCOM1
	
	// setting register CTRLA:
	SERCOM1->SPI.CTRLA.bit.CPOL = 0x1; //rising sample, falling setup; eading edge = falling edge (hodiny zustavaj potom v '1')
	SERCOM1->SPI.CTRLA.bit.CPHA = 0x1;
	SERCOM1->SPI.CTRLA.bit.DORD = 0x0; //MSB first
	SERCOM1->SPI.CTRLA.bit.DIPO = 0x0;
	SERCOM1->SPI.CTRLA.bit.DOPO = 0x2;
	SERCOM1->SPI.CTRLA.bit.MODE = 0x3; // SPI master operation
	
	// setting register CTRLB:
	SERCOM1->SPI.CTRLB.bit.RXEN = 0x1;
	SERCOM1->SPI.CTRLB.bit.MSSEN = 0x0; 
	SERCOM1->SPI.CTRLB.bit.CHSIZE = 0x0; // 8-bit word size
	
	// Baud setting:
	uint8_t BAUD_REG = (SPI_CLK_FREQ / (2 * SPI_BAUD)) - 1;	
	SERCOM1->SPI.BAUD.reg =	BAUD_REG;
	
	SERCOM1->SPI.CTRLA.bit.ENABLE = 1; // synchronization
	while(SERCOM1->SPI.SYNCBUSY.bit.ENABLE);
}

void interrupt_gyro_init(void)
{
	DIR_IN(GYRO_INT);
	PORT_MUX(GYRO_INT, 0);
	
	//GCLK->CLKCTRL.reg = GCLK_CLKCTRL_GEN_GCLK0 | GCLK_CLKCTRL_ID_EIC | GCLK_CLKCTRL_CLKEN;
	GCLK->CLKCTRL.bit.GEN = 0; //GCLKGEN0
	GCLK->CLKCTRL.bit.ID = 0x05; //GCLK_EIC
	GCLK->CLKCTRL.bit.CLKEN = 1;
	PM->APBAMASK.bit.EIC_ = 1; //enabling EIC v PM
	
	EIC->INTENSET.bit.EXTINT11 = 1;
	EIC->CONFIG[1].bit.SENSE3 = 0x1;
	EIC->CTRL.bit.ENABLE = 1;
	
	NVIC_SetPriority(EIC_IRQn, 2);
	NVIC_EnableIRQ(EIC_IRQn);
}

void interrupt_timer_init(void)
{
	//enable timer 04
	PM->APBCMASK.bit.TC4_ = 0x1;
	
	GCLK_CLKCTRL_Type clkctrl;
	clkctrl.bit.ID = GCLK_CLKCTRL_ID_TC4_TC5_Val; 
	clkctrl.bit.GEN = 0x0;
	clkctrl.bit.CLKEN = 0x1;
	while(GCLK->STATUS.bit.SYNCBUSY);
	GCLK->CLKCTRL.reg = clkctrl.reg;
	
	//setting TC4 - compare mode
	TC4->COUNT16.CTRLA.bit.PRESCSYNC = 0x0;		//reset counter on first clock edge after comparison
	TC4->COUNT16.CTRLA.bit.PRESCALER = 0x0;		//no prescaling
	TC4->COUNT16.CTRLA.bit.WAVEGEN = 0x1;		//reset on preloaded value 
	TC4->COUNT16.CTRLA.bit.MODE = 0x0;			//16b counter

	TC4->COUNT16.CC[0].reg = (uint16_t)5760; //preload value, interrupt frequency of 5kHz	TODO: change this to macro
	
	//interrupt enable for channel 0 & 1
	TC4->COUNT16.INTENSET.bit.MC0 = 0x1;
	//TC4->COUNT16.INTENSET.bit.MC1 = 0x1;
	 TC4->COUNT16.CTRLA.bit.ENABLE = 0x1;	//enable TC4
	
	NVIC_SetPriority(TC4_IRQn, 1);
	NVIC_EnableIRQ(TC4_IRQn);
}


uint8_t gyro_spi_comm(uint8_t data)
{
	while(SERCOM1->SPI.INTFLAG.bit.DRE == 0);	//place a watchdog here?
	SERCOM1->SPI.DATA.reg = data;
	delay_cycle(10);
	while(SERCOM1->SPI.INTFLAG.bit.RXC == 0 || SERCOM1->SPI.INTFLAG.bit.TXC == 0);	//place a watchdog here?
	return (uint8_t)SERCOM1->SPI.DATA.reg;
}

uint8_t gyro_reg_read(uint8_t reg_addr)
{
	uint8_t volatile data;
	
	RESET(GYRO_nCS);
	gyro_spi_comm(GYRO_READ | reg_addr);
	data = gyro_spi_comm(0x00);
	SET(GYRO_nCS);
	return data;
}

void gyro_reg_write(uint8_t reg_addr, uint8_t data)
{
	RESET(GYRO_nCS);
	gyro_spi_comm(GYRO_WRITE | reg_addr);
	gyro_spi_comm(data);
	SET(GYRO_nCS);
}

uint8_t gyro_test_reg(uint8_t reg_addr ,uint8_t dummy_data)
{
	uint8_t volatile read_val;
	gyro_reg_write(reg_addr,dummy_data);	//write to a gyro register	
	delay_cycle(100);	//wait some time	
	read_val = gyro_reg_read(reg_addr);	//read the register
	
	if(read_val == dummy_data){return 1;} else {return 0;}
}

void gyro_reg_init() //initialize gyro registers
{
	gyro_reg_write(GYRO_REG_USER_CTRL, GYRO_DEVICE_RESET);	//reset gyro
	delay_cycle(150000);	//wait 100ms
	gyro_reg_write(GYRO_REG_PWR_MGMT_1, GYRO_SIG_COND_RESET);
	delay_cycle(150000);	//wait 100ms
	
	gyro_reg_write(GYRO_REG_PWR_MGMT_1, GYRO_DIS_SLEEP);	//disable sleep mode
	gyro_reg_write(GYRO_REG_SMPLRT_DIV, 0x00);	//set sample rate 1kHz
	gyro_reg_write(GYRO_REG_CONFIG, GYRO_DLPF_CFG_256);	//set digital low pass filter
	gyro_reg_write(GYRO_REG_GYRO_CONFIG,GYRO_FSEL_250);	//set gyro scale range
	gyro_reg_write(GYRO_REG_INT_ENABLE, GYRO_DATA_RDY_EN);	//interrupt source
	gyro_reg_write(GYRO_REG_USER_CTRL, GYRO_I2C_IF_DIS);	//disable i2c
	gyro_reg_write(GYRO_REG_PWR_MGMT_2, GYRO_STBY_XA | GYRO_STBY_YA | GYRO_STBY_ZA | GYRO_STBY_YG | GYRO_STBY_XG);	//leave only z-axis gyroscope enabled
	
	volatile uint8_t data;	//sanity test
	data = gyro_test_reg(0x28,0x13);
	data = gyro_reg_read(GYRO_REG_WHO_AM_I);
	data = gyro_reg_read(GYRO_REG_GYRO_ZOUT_MSB);
	
}

void EIC_Handler(void)
{
    //SET(TEST_PAD);
	interrupt_stat_num_eic++;
	
	//control loop
	
	//read gyro and update angle by integration
	 volatile int16_t temp = 0;
	 temp += gyro_reg_read(GYRO_REG_GYRO_ZOUT_LSB);
	 temp += gyro_reg_read(GYRO_REG_GYRO_ZOUT_MSB) << 8;
	 pend_angle -= ((temp-OFFSET)*(GYRO_DEG_PER_S_PER_LSB*TIME_STEP_CTRL_S));
	 //pend_angle += (OFFSET*GYRO_DEG_PER_S_PER_LSB*TIME_STEP_CTRL_S);
	 //pend_angle *= -1;
	 
	 if (ABS_VAL(pend_angle) > CRITICAL_ANGLE) //point of no return
	 {
		 TC4->COUNT16.CTRLA.bit.ENABLE = 0x0;	//disable driving loop
		 EIC->CTRL.bit.ENABLE = 0; //disable control loop
		 RESET(DRU_STEP);
		 RESET(DRU_nSLEEP);
	 }
	 
	 //compute desired bottom position (PID)
	 volatile dist_m debug_top = pend_angle*PEND_LEN_M;
	 top_pos_now = debug_top + bot_pos_now;
	 top_pos_diff_last = top_pos_diff;
	 top_pos_diff = (top_pos_now - top_pos_old)*TIME_STEP_CTRL_INV_HZ; //numerical differentiation
	 top_pos_diff_filt = FIR_ALPHA*top_pos_diff + (1-FIR_ALPHA)*top_pos_diff_last;
	 top_pos_int += (top_pos_now*TIME_STEP_CTRL_S);				   //numerical integration
	 bot_pos_dest = top_pos_now*const_prop + top_pos_diff_filt*const_diff + top_pos_int*const_int;	//new desired bottom position
	 
	 top_pos_old = top_pos_now; //update
	 
	 bot_acc_traj = (bot_pos_dest - bot_pos_now - bot_vel_traj*TIME_STEP_DEST_S)*(2/TIME_STEP_DEST_SQ_S); //compute acceleration
	//RESET(TEST_PAD); 	
	
	EIC->INTFLAG.reg = EIC_INTFLAG_EXTINT11;
	return;
}

void TC4_Handler()
{
	//SET(TEST_PAD);
	RESET(DRU_STEP);
	interrupt_stat_num_tc4++;
		
	//motor driving loop
	bot_vel_traj += (bot_acc_traj*TIME_STEP_DRV_S);
	bot_pos_traj += (bot_vel_traj*TIME_STEP_DRV_S);
	
	if (ABS_VAL(bot_pos_traj - bot_pos_now) >= (MOTOR_STEP_DIST_M))
	{ 
		if (bot_pos_traj - bot_pos_now > 0) //step forward
		{
			RESET(DRU_DIR);
			SET(DRU_STEP);
			bot_pos_now += MOTOR_STEP_DIST_M;	
		}
		else //step back
		{
			SET(DRU_DIR);
			SET(DRU_STEP);
			bot_pos_now -= MOTOR_STEP_DIST_M;
		}
		
	}
	//RESET(TEST_PAD);
		
	TC4->COUNT16.INTFLAG.bit.MC0 = 0x1; //reset flag
	return;
}


int main(void)
{
	//init functions
    SystemInit();
	osc_init();
	clk_init();
	drv_init();
	gyro_clk_init();
	gyro_spi_init();
	interrupt_gyro_init();
	interrupt_timer_init();
	gyro_reg_init();
	
	
	
	// inf loop:
    while (1) 
	{
		/*SET(DRU_M0);	//dir 0 - 1/8 step
		RESET(DRU_M1);
		SET(DRU_DIR)
		SET(DRU_STEP);
		delay_cycle(200);
		RESET(DRU_STEP);
		for (int i = 0; i < 500; ++i)
		{
			asm volatile ("nop");
		};*/

		/*volatile uint8_t a = VALUE(DRU_nFAULT);
		asm volatile ("nop");
		SET(DRU_STEP);
		for (int i = 0; i < 30000; ++i) // hloupá èekací smyèka
		{
			asm volatile ("nop");
		};
		RESET(DRU_STEP);
		for (int i = 0; i < 10000; ++i)
		{
			asm volatile ("nop");
		};*/
		
    }
}
