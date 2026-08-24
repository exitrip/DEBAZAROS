
/***************************** Include Files *********************************/

#include "xaxivdma_hw.h"

/*****************************************************************************/
/**
*
* This function reads the given register.
*
* @param	BaseAddress is the base address of the VDMA core.
* @param	RegOffset is the register offset of the register (defined at
*		top of this file).
*
* @return	The 32-bit value of the register.
*
*
******************************************************************************/

/* BaseAddress is a physical-derived address (device base, ChanBase or
 * StartAddrBase); the mm_IP mapping starts at the device base, so the
 * difference selects the MM2S (+0x00/+0x50) vs S2MM (+0x30/+0xA0) block.
 * Discarding it (as before) collapses every channel onto MM2S offsets. */
int XAxiVdma_ReadReg(mm_IP * _mm_IP, int BaseAddress, int RegOffset ){

	return IP_driver_read(_mm_IP, (BaseAddress - _mm_IP->base_address) + RegOffset);

}




/*****************************************************************************/
/**
*
* Write the given register.
*
* @param	BaseAddress is the base address of the VDMA core.
* @param	RegOffset is the register offset of the register (defined at
*		top of this file) to be written.
* @param	Data is the 32-bit value to write to the register.
*
* @return	None.
*
* @note		C-style signature:
*		void XVtc_WriteReg(u32 BaseAddress, u32 RegOffset, u32 Data)
*
******************************************************************************/

void XAxiVdma_WriteReg(mm_IP * _mm_IP, int BaseAddress, int RegOffset, int Data ){

	IP_driver_write(_mm_IP, (BaseAddress - _mm_IP->base_address) + RegOffset, Data);

}
/************************** Function Prototypes ******************************/


/************************** Variable Declarations ****************************/


#ifdef __cplusplus
}
#endif

//#endif /* end of protection macro */
/** @} */
