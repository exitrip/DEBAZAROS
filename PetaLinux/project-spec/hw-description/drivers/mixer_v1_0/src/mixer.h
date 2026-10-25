
#ifndef MIXER_H
#define MIXER_H


/****************** Include Files ********************/
#include "xil_types.h"
#include "xstatus.h"


#define MIXER_S00_AXI_REG0_OFFSET 0
#define MIXER_S00_AXI_REG1_OFFSET 4
#define MIXER_S00_AXI_REG2_OFFSET 8
#define MIXER_S00_AXI_REG3_OFFSET 12
#define MIXER_S00_AXI_REG4_OFFSET 16
#define MIXER_S00_AXI_REG5_OFFSET 20
#define MIXER_S00_AXI_REG6_OFFSET 24
#define MIXER_S00_AXI_REG7_OFFSET 28
#define MIXER_S00_AXI_REG8_OFFSET 32
#define MIXER_S00_AXI_REG9_OFFSET 36
#define MIXER_S00_AXI_REG10_OFFSET 40
#define MIXER_S00_AXI_REG11_OFFSET 44
#define MIXER_S00_AXI_REG12_OFFSET 48
#define MIXER_S00_AXI_REG13_OFFSET 52
#define MIXER_S00_AXI_REG14_OFFSET 56
#define MIXER_S00_AXI_REG15_OFFSET 60
#define MIXER_S00_AXI_REG16_OFFSET 64
#define MIXER_S00_AXI_REG17_OFFSET 68
#define MIXER_S00_AXI_REG18_OFFSET 72
#define MIXER_S00_AXI_REG19_OFFSET 76
#define MIXER_S00_AXI_REG20_OFFSET 80
#define MIXER_S00_AXI_REG21_OFFSET 84
#define MIXER_S00_AXI_REG22_OFFSET 88
#define MIXER_S00_AXI_REG23_OFFSET 92
#define MIXER_S00_AXI_REG24_OFFSET 96
#define MIXER_S00_AXI_REG25_OFFSET 100
#define MIXER_S00_AXI_REG26_OFFSET 104
#define MIXER_S00_AXI_REG27_OFFSET 108
#define MIXER_S00_AXI_REG28_OFFSET 112
#define MIXER_S00_AXI_REG29_OFFSET 116
#define MIXER_S00_AXI_REG30_OFFSET 120
#define MIXER_S00_AXI_REG31_OFFSET 124
#define MIXER_S00_AXI_REG32_OFFSET 128
#define MIXER_S00_AXI_REG33_OFFSET 132
#define MIXER_S00_AXI_REG34_OFFSET 136
#define MIXER_S00_AXI_REG35_OFFSET 140
#define MIXER_S00_AXI_REG36_OFFSET 144
#define MIXER_S00_AXI_REG37_OFFSET 148
#define MIXER_S00_AXI_REG38_OFFSET 152
#define MIXER_S00_AXI_REG39_OFFSET 156
#define MIXER_S00_AXI_REG40_OFFSET 160
#define MIXER_S00_AXI_REG41_OFFSET 164
#define MIXER_S00_AXI_REG42_OFFSET 168
#define MIXER_S00_AXI_REG43_OFFSET 172
#define MIXER_S00_AXI_REG44_OFFSET 176
#define MIXER_S00_AXI_REG45_OFFSET 180
#define MIXER_S00_AXI_REG46_OFFSET 184
#define MIXER_S00_AXI_REG47_OFFSET 188
#define MIXER_S00_AXI_REG48_OFFSET 192
#define MIXER_S00_AXI_REG49_OFFSET 196
#define MIXER_S00_AXI_REG50_OFFSET 200
#define MIXER_S00_AXI_REG51_OFFSET 204
#define MIXER_S00_AXI_REG52_OFFSET 208
#define MIXER_S00_AXI_REG53_OFFSET 212
#define MIXER_S00_AXI_REG54_OFFSET 216
#define MIXER_S00_AXI_REG55_OFFSET 220
#define MIXER_S00_AXI_REG56_OFFSET 224
#define MIXER_S00_AXI_REG57_OFFSET 228
#define MIXER_S00_AXI_REG58_OFFSET 232
#define MIXER_S00_AXI_REG59_OFFSET 236
#define MIXER_S00_AXI_REG60_OFFSET 240
#define MIXER_S00_AXI_REG61_OFFSET 244
#define MIXER_S00_AXI_REG62_OFFSET 248
#define MIXER_S00_AXI_REG63_OFFSET 252
#define MIXER_S00_AXI_REG64_OFFSET 256
#define MIXER_S00_AXI_REG65_OFFSET 260
#define MIXER_S00_AXI_REG66_OFFSET 264
#define MIXER_S00_AXI_REG67_OFFSET 268
#define MIXER_S00_AXI_REG68_OFFSET 272
#define MIXER_S00_AXI_REG69_OFFSET 276
#define MIXER_S00_AXI_REG70_OFFSET 280
#define MIXER_S00_AXI_REG71_OFFSET 284
#define MIXER_S00_AXI_REG72_OFFSET 288
#define MIXER_S00_AXI_REG73_OFFSET 292
#define MIXER_S00_AXI_REG74_OFFSET 296
#define MIXER_S00_AXI_REG75_OFFSET 300
#define MIXER_S00_AXI_REG76_OFFSET 304
#define MIXER_S00_AXI_REG77_OFFSET 308
#define MIXER_S00_AXI_REG78_OFFSET 312
#define MIXER_S00_AXI_REG79_OFFSET 316
#define MIXER_S00_AXI_REG80_OFFSET 320
#define MIXER_S00_AXI_REG81_OFFSET 324
#define MIXER_S00_AXI_REG82_OFFSET 328
#define MIXER_S00_AXI_REG83_OFFSET 332
#define MIXER_S00_AXI_REG84_OFFSET 336
#define MIXER_S00_AXI_REG85_OFFSET 340
#define MIXER_S00_AXI_REG86_OFFSET 344
#define MIXER_S00_AXI_REG87_OFFSET 348
#define MIXER_S00_AXI_REG88_OFFSET 352
#define MIXER_S00_AXI_REG89_OFFSET 356
//#define MIXER_S00_AXI_REG90_OFFSET 360
//#define MIXER_S00_AXI_REG91_OFFSET 364
//#define MIXER_S00_AXI_REG92_OFFSET 368
//#define MIXER_S00_AXI_REG93_OFFSET 372
//#define MIXER_S00_AXI_REG94_OFFSET 376
//#define MIXER_S00_AXI_REG95_OFFSET 380
//#define MIXER_S00_AXI_REG96_OFFSET 384
//#define MIXER_S00_AXI_REG97_OFFSET 388
//#define MIXER_S00_AXI_REG98_OFFSET 392
//#define MIXER_S00_AXI_REG99_OFFSET 396
//#define MIXER_S00_AXI_REG100_OFFSET 400
//#define MIXER_S00_AXI_REG101_OFFSET 404
//#define MIXER_S00_AXI_REG102_OFFSET 408
//#define MIXER_S00_AXI_REG103_OFFSET 412
//#define MIXER_S00_AXI_REG104_OFFSET 416
//#define MIXER_S00_AXI_REG105_OFFSET 420
//#define MIXER_S00_AXI_REG106_OFFSET 424
//#define MIXER_S00_AXI_REG107_OFFSET 428
//#define MIXER_S00_AXI_REG108_OFFSET 432
//#define MIXER_S00_AXI_REG109_OFFSET 436
//#define MIXER_S00_AXI_REG110_OFFSET 440
//#define MIXER_S00_AXI_REG111_OFFSET 444
//#define MIXER_S00_AXI_REG112_OFFSET 448
//#define MIXER_S00_AXI_REG113_OFFSET 452
//#define MIXER_S00_AXI_REG114_OFFSET 456
//#define MIXER_S00_AXI_REG115_OFFSET 460
//#define MIXER_S00_AXI_REG116_OFFSET 464
//#define MIXER_S00_AXI_REG117_OFFSET 468
//#define MIXER_S00_AXI_REG118_OFFSET 472
//#define MIXER_S00_AXI_REG119_OFFSET 476
//#define MIXER_S00_AXI_REG120_OFFSET 480
//#define MIXER_S00_AXI_REG121_OFFSET 484
//#define MIXER_S00_AXI_REG122_OFFSET 488
//#define MIXER_S00_AXI_REG123_OFFSET 492
//#define MIXER_S00_AXI_REG124_OFFSET 496
//#define MIXER_S00_AXI_REG125_OFFSET 500
//#define MIXER_S00_AXI_REG126_OFFSET 504
//#define MIXER_S00_AXI_REG127_OFFSET 508


/**************************** Type Definitions *****************************/
/**
 *
 * Write a value to a MIXER register. A 32 bit write is performed.
 * If the component is implemented in a smaller width, only the least
 * significant data is written.
 *
 * @param   BaseAddress is the base address of the MIXERdevice.
 * @param   RegOffset is the register offset from the base to write to.
 * @param   Data is the data written to the register.
 *
 * @return  None.
 *
 * @note
 * C-style signature:
 * 	void MIXER_mWriteReg(u32 BaseAddress, unsigned RegOffset, u32 Data)
 *
 */
#define MIXER_mWriteReg(BaseAddress, RegOffset, Data) \
  	Xil_Out32((BaseAddress) + (RegOffset), (u32)(Data))

/**
 *
 * Read a value from a MIXER register. A 32 bit read is performed.
 * If the component is implemented in a smaller width, only the least
 * significant data is read from the register. The most significant data
 * will be read as 0.
 *
 * @param   BaseAddress is the base address of the MIXER device.
 * @param   RegOffset is the register offset from the base to write to.
 *
 * @return  Data is the data from the register.
 *
 * @note
 * C-style signature:
 * 	u32 MIXER_mReadReg(u32 BaseAddress, unsigned RegOffset)
 *
 */
#define MIXER_mReadReg(BaseAddress, RegOffset) \
    Xil_In32((BaseAddress) + (RegOffset))

/************************** Function Prototypes ****************************/
/**
 *
 * Run a self-test on the driver/device. Note this may be a destructive test if
 * resets of the device are performed.
 *
 * If the hardware system is not built correctly, this function may never
 * return to the caller.
 *
 * @param   baseaddr_p is the base address of the MIXER instance to be worked on.
 *
 * @return
 *
 *    - XST_SUCCESS   if all self-test code passed
 *    - XST_FAILURE   if any self-test code failed
 *
 * @note    Caching must be turned off for this function to work.
 * @note    Self test may fail if data memory and device are not on the same bus.
 *
 */
XStatus MIXER_Reg_SelfTest(void * baseaddr_p);

#endif // MIXER_H

