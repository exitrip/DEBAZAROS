/*
 *
 * Xilinx, Inc.
 * XILINX IS PROVIDING THIS DESIGN, CODE, OR INFORMATION "AS IS" AS A 
 * COURTESY TO YOU.  BY PROVIDING THIS DESIGN, CODE, OR INFORMATION AS
 * ONE POSSIBLE   IMPLEMENTATION OF THIS FEATURE, APPLICATION OR 
 * STANDARD, XILINX IS MAKING NO REPRESENTATION THAT THIS IMPLEMENTATION 
 * IS FREE FROM ANY CLAIMS OF INFRINGEMENT, AND YOU ARE RESPONSIBLE 
 * FOR OBTAINING ANY RIGHTS YOU MAY REQUIRE FOR YOUR IMPLEMENTATION
 * XILINX EXPRESSLY DISCLAIMS ANY WARRANTY WHATSOEVER WITH RESPECT TO 
 * THE ADEQUACY OF THE IMPLEMENTATION, INCLUDING BUT NOT LIMITED TO 
 * ANY WARRANTIES OR REPRESENTATIONS THAT THIS IMPLEMENTATION IS FREE 
 * FROM CLAIMS OF INFRINGEMENT, IMPLIED WARRANTIES OF MERCHANTABILITY 
 * AND FITNESS FOR A PARTICULAR PURPOSE.
 */

/*
 * 
 *
 * This file is a generated sample test application.
 *
 * This application is intended to test and/or illustrate some 
 * functionality of your system.  The contents of this file may
 * vary depending on the IP in your system and may use existing
 * IP driver functions.  These drivers will be generated in your
 * SDK application project when you run the "Generate Libraries" menu item.
 *
 */

#include <stdio.h>
#include "xparameters.h"
#include "xil_cache.h"
#include "xi2srx_header.h"
#include "xgpio.h"
#include "gpio_header.h"
#include "gpio_intr_header.h"
#include "axivdma_header.h"

#define GPIO_CHANNEL1 1

#define GPIO_CHANNEL1 1
int main () 
{
   static XGpio HDMI_0_axi_gpio_hdmi_Gpio;
   static XGpio HDMI_1_axi_gpio_hdmi_Gpio;
   Xil_ICacheEnable();
   Xil_DCacheEnable();
   print("---Entering main---\n\r");


	  {
	  int Status;


	  print("\r\nRunning I2srx_SelfTest_Example() for Audio_DMA_i2s_receiver_0...\r\n");

	  Status = I2srx_SelfTest_Example(XPAR_AUDIO_DMA_I2S_RECEIVER_0_DEVICE_ID);

	  if (Status == 0) {
	  print("I2srx_SelfTest_Example PASSED\r\n");
      }
	      else {
	      print("I2srx_SelfTest_Example FAILED\r\n");
      }
   }



   {
      u32 status;
      u32 DataRead;
      
      print("\r\nRunning GpioInputExample() for HDMI_0_axi_gpio_hdmi...\r\n");

      
      status = GpioInputExample(XPAR_HDMI_0_AXI_GPIO_HDMI_DEVICE_ID, &DataRead);
      
      if (status == 0) {
         xil_printf("GpioInputExample PASSED. Read data:0x%X\r\n", DataRead);
      }
      else {
         print("GpioInputExample FAILED.\r\n");
      }
   }
   {
      
      int Status;
        
      u32 DataRead;
      
      print(" Press button to Generate Interrupt\r\n");
//
//      Status = GpioIntrExample(&intc, &HDMI_0_axi_gpio_hdmi_Gpio, \
//                               XPAR_HDMI_0_AXI_GPIO_HDMI_DEVICE_ID, \
//                               XPAR_FABRIC_HDMI_0_AXI_GPIO_HDMI_IP2INTC_IRPT_INTR, \
//                               GPIO_CHANNEL1, &DataRead);
	
      if (Status == 0 ){
             if(DataRead == 0)
                print("No button pressed. \r\n");
             else
                print("Gpio Interrupt Test PASSED. \r\n"); 
      } 
      else {
         print("Gpio Interrupt Test FAILED.\r\n");
      }
	
   }



   {
      int status;


      print("\r\n Running AxiVDMASelfTestExample() for HDMI_0_axi_vdma_0...\r\n");

      status = AxiVDMASelfTestExample(XPAR_HDMI_0_AXI_VDMA_0_DEVICE_ID);

      if (status == 0) {
         print("AxiVDMASelfTestExample PASSED\r\n");
      }
      else {
         print("AxiVDMASelfTestExample FAILED\r\n");
      }
   }



   {
      u32 status;
      u32 DataRead;
      
      print("\r\nRunning GpioInputExample() for HDMI_1_axi_gpio_hdmi...\r\n");

      
      status = GpioInputExample(XPAR_HDMI_1_AXI_GPIO_HDMI_DEVICE_ID, &DataRead);
      
      if (status == 0) {
         xil_printf("GpioInputExample PASSED. Read data:0x%X\r\n", DataRead);
      }
      else {
         print("GpioInputExample FAILED.\r\n");
      }
   }
   {
      
      int Status;
        
      u32 DataRead;
      
      print(" Press button to Generate Interrupt\r\n");
      
//      Status = GpioIntrExample(&intc, &HDMI_1_axi_gpio_hdmi_Gpio, \
//                               XPAR_HDMI_1_AXI_GPIO_HDMI_DEVICE_ID, \
//                               XPAR_FABRIC_HDMI_1_AXI_GPIO_HDMI_IP2INTC_IRPT_INTR, \
//                               GPIO_CHANNEL1, &DataRead);
	
      if (Status == 0 ){
             if(DataRead == 0)
                print("No button pressed. \r\n");
             else
                print("Gpio Interrupt Test PASSED. \r\n"); 
      } 
      else {
         print("Gpio Interrupt Test FAILED.\r\n");
      }
	
   }



   {
      int status;


      print("\r\n Running AxiVDMASelfTestExample() for HDMI_1_axi_vdma_0...\r\n");

      status = AxiVDMASelfTestExample(XPAR_HDMI_1_AXI_VDMA_0_DEVICE_ID);

      if (status == 0) {
         print("AxiVDMASelfTestExample PASSED\r\n");
      }
      else {
         print("AxiVDMASelfTestExample FAILED\r\n");
      }
   }


   print("---Exiting main---\n\r");
   Xil_DCacheDisable();
   Xil_ICacheDisable();
   return 0;
}
