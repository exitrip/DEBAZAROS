 /*
  *
  * Since you'd rather hack around, okay, here's the dirty way to do it:
	Change the devicetree of your kernel and alter the "memory" parameter,
	so that your memory range is no longer part of the normal RAM.
	Add the SIMPLEFB driver to your kernel through the menuconfig.
	Add the memory address, range, width height and stride parameters
	of your framebuffer to the configuration setting in the devicetree.
	Install this on your system, and you should now have a working /dev/fb0
	that can be mmapped like any framebuffer.
  *
  *
  */


#include "display_demo.h"
#include "../display_ctrl/display_ctrl.h"
#include <stdio.h>
#include <ctype.h>
#include <stdlib.h>
#include "../inc/xil_types.h"
#include "../timer_ps/timer_ps.h"
#include "../IP_Driver.h"
#include "../mixer_v1_0/src/mixer.h"
#include <argp.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <errno.h>

#define xil_printf printf

/*
 * XPAR redefines
 */
#define DYNCLK_BASEADDR XPAR_AXI_DYNCLK_0_BASEADDR
//#define DYNCLK_BASEADDR 0

#define HDMI_0_VDMA_ID XPAR_HDMI_0_AXI_VDMA_0_DEVICE_ID
#define HDMI_1_VDMA_ID XPAR_HDMI_1_AXI_VDMA_0_DEVICE_ID
#define DISP_0_VTC_ID XPAR_HDMI_0_V_TC_0_DEVICE_ID
//#define DISP_1_VTC_ID XPAR_HDMI_1_V_TC_0_DEVICE_ID
#define VID_VTC_IRPT_ID XPS_FPGA3_INT_ID
#define VID_GPIO_IRPT_ID XPS_FPGA4_INT_ID
#define SCU_TIMER_ID XPAR_SCUTIMER_DEVICE_ID
#define UART_BASEADDR XPAR_PS7_UART_1_BASEADDR

#define NU_MIXER_0_ADDR XPAR_HDMI_0_MIXERMATRIX_MIXER_0_S00_AXI_BASEADDR

#define TEST_GAIN_0_ADDR  XPAR_HDMI_0_COLORGAINMAIN_AXI_GPIO_0_BASEADDR
#define TEST_GAIN_1_ADDR  XPAR_HDMI_1_COLORGAINMAIN_AXI_GAIN_1_BASEADDR

/* ------------------------------------------------------------ */
/*				Global Variables								*/
/* ------------------------------------------------------------ */

/*
 * Display Driver structs
 */
DisplayCtrl dispCtrl0, dispCtrl1;
XAxiVdma vdma0, vdma1;
int showmenu = 0;

// --------------------------------------------------------------
//                 system-user.dtsi template
// --------------------------------------------------------------

/*


/include/ "system-conf.dtsi"
/ {
        chosen {
            bootargs = "earlycon console=ttyPS0,115200 clk_ignore_unused root=/dev/mmcblk0p2 rw rootwait cma=256M uio_pdrv_genirq.of_id=generic-uio";
	};

	reserved-memory {
	      #address-cells = <1>;
	      #size-cells = <1>;
	      ranges;
	      // HDMI Output frame buffer
	      hdmi_fb_reserved_region@0x08000000 {
		 compatible = "removed-dma-pool";
		 no-map;
		 reg = <0x08000000 0x01000000>;
	      };
	};

	   hdmi_fb: framebuffer@0x08000000 {           // HDMI out
	      compatible = "simple-framebuffer";
	      // 512M (M modules)
	      reg = <0x08000000 (1280 * 720 * 4)>;
	      width = <1280>;
	      height = <720>;
	      stride = <(1280 * 4)>;
	      format = "a8b8g8r8";
	      status = "okay";
	   };

	   // Color formats: "r5g6b5" "r5g5b5a1" "x1r5g5b5" "a1r5g5b5" "r8g8b8"
	   //                "x8r8g8b8" "a8r8g8b8" "a8b8g8r8"
	   //                "x2r10g10b10" "a2r10g10b10"

};

&HDMI_axi_gpio_0 {
	compatible = "generic-uio";
	reg = <0x41230000 0x10000 0xFFFC0000 0x20000>;
};

 *
 *
 */
// --------------------------------------------------------------

/*
 * Framebuffers for video data
 */
// Don't allocate here, but map into the reserved memory
//u8 *  frameBuf0;
//u8 *  frameBuf1;
//u8 *  frameBuf2;
//u8 *  frameBuf3;
//u8 *  frameBuf4;
//u8 *  frameBuf5;
u8 *  pFramesPhysical0[DISPLAY_NUM_FRAMES]; //array of pointers to the frame buffers
u8 *  pFramesVirtual0[DISPLAY_NUM_FRAMES]; //array of pointers to the frame buffers
u8 *  pFramesPhysical1[DISPLAY_NUM_FRAMES]; //array of pointers to the frame buffers
u8 *  pFramesVirtual1[DISPLAY_NUM_FRAMES]; //array of pointers to the frame buffers

// These are the structs containing physical <-> virtual memory mapping ...
// ... for the DMA framebuffer ...
mm_IP fb_mm_IP;
// ... and for all the Vivado IP's needing to be configured
mm_IP scu_timer_mm_IP;
mm_IP vdma_0_mm_IP, vdma_1_mm_IP;
mm_IP vtc_0_mm_IP;//, vtc_1_mm_IP;
mm_IP dynclk_mm_IP;
mm_IP testMix_IP[9];
mm_IP testGain0_IP, testGain1_IP;
mm_IP testLED_IP;

/* ------------------------------------------------------------ */
/*				Procedure Definitions							*/
/* ------------------------------------------------------------ */

/*	-------			Argument parsing		  ------------------*/
const char *argp_program_version = "DEBAZAROS 0.1";
const char *argp_program_bug_address = "<your@email.address>";
static char doc[] = "Set the resolution and optionally display color bars for the DEBAZAROS HDMI output.";
static char args_doc[] = "[FILENAME]...";
static struct argp_option options[] = {
    { "menu", 'm', 0, 0, "Show a menu to change settings."},
	{ "resolution", 'r', 0, 0, "Set the resolution: 640x480 800x600 1280x1024 or 1280x720. Default=1280x720"},
    { 0 }
};


static error_t parse_opt(int key, char *arg, struct argp_state *state) {
    switch (key) {
		case 'm':
			showmenu = -1; break;
		case 'r':
			if(strcmp(state->argv[state->next],"640x480")==0)
				dispCtrl0.vMode = VMODE_640x480;
			else if(strcmp(state->argv[state->next], "800x600")==0)
				dispCtrl0.vMode = VMODE_800x600;
			else if(strcmp(state->argv[state->next],"1280x720x50Hz")==0)
				dispCtrl0.vMode = VMODE_1280x720x50Hz;
			else if(strcmp(state->argv[state->next],"1280x720x30Hz")==0) {
				/* both displays: shared pixel clock */
				dispCtrl0.vMode = VMODE_1280x720x30Hz;
				dispCtrl1.vMode = VMODE_1280x720x30Hz;
			}
			else if(strcmp(state->argv[state->next],"1920x1080x25Hz")==0)
				dispCtrl0.vMode = VMODE_1920x1080x25Hz;
			else if(strcmp(state->argv[state->next],"1920x1080x60Hz")==0)
				dispCtrl0.vMode = VMODE_1920x1080x60Hz;
			else
				dispCtrl0.vMode = VMODE_1280x720x50Hz;
			break;
		case ARGP_KEY_ARG: return 0;
		default: return ARGP_ERR_UNKNOWN;
    }
    return 0;
}

static struct argp argpo = { options, parse_opt, args_doc, doc, 0, 0};

#define BUFFER_SIZE 4096
#define PORT 8888
#define MAX_PACKET_SIZE 1024

typedef struct {
    unsigned char buffer[BUFFER_SIZE];
    size_t head;
    size_t tail;
    size_t count;
} CircularBuffer;

void initBuffer(CircularBuffer *cb) {
    cb->head = 0;
    cb->tail = 0;
    cb->count = 0;
    memset(cb->buffer, 0, BUFFER_SIZE);
}

int writeBuffer(CircularBuffer *cb, const unsigned char *data, size_t length) {
    if (cb->count + length > BUFFER_SIZE) {
        return -1; // Buffer would overflow
    }

    for (size_t i = 0; i < length; i++) {
        cb->buffer[cb->head] = data[i];
        cb->head = (cb->head + 1) % BUFFER_SIZE;
        cb->count++;
    }
    return 0;
}

//int setNonBlocking(int sockfd) {
//    int flags = fcntl(sockfd, F_GETFL, 0);
//    if (flags == -1) {
//        perror("fcntl F_GETFL");
//        return -1;
//    }
//    if (fcntl(sockfd, F_SETFL, flags | O_NONBLOCK) == -1) {
//        perror("fcntl F_SETFL O_NONBLOCK");
//        return -1;
//    }Quick Access
//    return 0;
//}

/* ======== DVI input capture VDMA (S2MM only) ==================
 *
 * Chain: TMDS in -> dvi2rgb (recovered pixel clock; needs FCLK3 =
 * 200 MHz for its IDELAYCTRL RefClk - the FSBL programs FCLK3, NOT
 * the bitstream, see CLAUDE.md "FSBL clock trap") -> v_vid_in_axi4s
 * (async FIFO CDC) -> axis_subset_converter 24->32 (alpha=0xff)
 * -> this VDMA S2MM -> HP1 -> DDR slot 4.
 *
 * CRITICAL - driver: the hacked XAxiVdma_ReadReg/WriteReg must apply
 * (BaseAddress - mm_IP base) so S2MM registers land at +0x30/+0xA0.
 * The old fork discarded the base and could only address MM2S.
 *
 * CRITICAL - shutdown: NEVER clear DMACR.RS while the stream is
 * running mid-frame. The abandoned burst wedges the HP-port AFI FIFO
 * in the PS; soft reset then never completes and only a PS reset
 * recovers (this can hang the whole board). Stop capture with a soft
 * reset (DMACR bit2) while the stream is healthy, or not at all.
 *
 * All 3 frame stores point at slot 4 (park on frame 0) until
 * double-buffered capture (slots 4+5) is implemented.
 * CHECK against Address Editor + BD customization:
 *   base address, S2MmWordLen, S2MmBufDepth, S2MmStreamWidth      */
#define CAPTURE_VDMA_BASE   0x43020000  /* <- Address Editor value */
#define CAPTURE_FRAME_SLOT  4           /* 0-1 disp0, 2-3 disp1    */
#define CAPTURE_W           1280
#define CAPTURE_H           720

XAxiVdma captureVdma;
XAxiVdma_DmaSetup captureSetup;
mm_IP vdma_cap_mm_IP;

static XAxiVdma_Config captureCfg = {
	.DeviceId           = 2,
	.BaseAddress        = CAPTURE_VDMA_BASE,
	.MaxFrameStoreNum   = 3,     /* keep 3: third-port rule      */
	.HasMm2S            = 0,
	.HasS2Mm            = 1,
	.HasS2MmDRE         = 0,
	.S2MmWordLen        = 32,    /* BD: M_AXI_S2MM data width    */
	.HasSG              = 0,
	.EnableVIDParamRead = 0,
	.UseFsync           = 0,
	.FlushonFsync       = 0,
	.S2MmBufDepth       = 2048,  /* BD: write linebuffer depth   */
	.S2MmGenLock        = 0,
	.InternalGenLock    = 0,
	.S2MmSOF            = 1,     /* BD: SOF-on-tuser must be ON  */
	.S2MmStreamWidth    = 32,    /* BD: S_AXIS_S2MM tdata width  */
	.AddrWidth          = 32,
};

int CaptureInitialize(void)
{
	int Status, i;
	u32 capPhys = fb_mm_IP.base_address + CAPTURE_FRAME_SLOT * DEMO_MAX_FRAME;

	vdma_cap_mm_IP.base_address = CAPTURE_VDMA_BASE;
	vdma_cap_mm_IP.size_in_k = 64;
	create_IP_driver(&vdma_cap_mm_IP);

	Status = XAxiVdma_CfgInitialize(&vdma_cap_mm_IP, &captureVdma,
	                                &captureCfg, CAPTURE_VDMA_BASE);
	if (Status != XST_SUCCESS) {
		xil_printf("Capture VDMA init failed %d\r\n", Status);
		return Status;
	}

	captureSetup.VertSizeInput      = CAPTURE_H;
	captureSetup.HoriSizeInput      = CAPTURE_W * 4;   /* bytes  */
	captureSetup.Stride             = CAPTURE_W * 4;
	captureSetup.FrameDelay         = 0;
	captureSetup.EnableCircularBuf  = 0;  /* park on one slot     */
	captureSetup.EnableSync         = 0;
	captureSetup.PointNum           = 0;
	captureSetup.EnableFrameCounter = 0;
	captureSetup.FixedFrameStoreAddr = 0;
	for (i = 0; i < 3; i++)               /* all fstores -> slot 4 */
		captureSetup.FrameStoreStartAddr[i] = capPhys;

	Status = XAxiVdma_DmaConfig(&vdma_cap_mm_IP, &captureVdma,
	                            XAXIVDMA_WRITE, &captureSetup);
	if (Status != XST_SUCCESS) {
		xil_printf("Capture VDMA DmaConfig failed %d\r\n", Status);
		return Status;
	}

	Status = XAxiVdma_DmaSetBufferAddr(&vdma_cap_mm_IP, &captureVdma,
	                XAXIVDMA_WRITE, captureSetup.FrameStoreStartAddr);
	if (Status != XST_SUCCESS) {
		xil_printf("Capture VDMA SetBufferAddr failed %d\r\n", Status);
		return Status;
	}

	Status = XAxiVdma_DmaStart(&vdma_cap_mm_IP, &captureVdma, XAXIVDMA_WRITE);
	if (Status != XST_SUCCESS) {
		xil_printf("Capture VDMA DmaStart failed %d\r\n", Status);
		return Status;
	}

	Status = XAxiVdma_StartParking(&vdma_cap_mm_IP, &captureVdma, 0,
	                              XAXIVDMA_WRITE);
	if (Status != XST_SUCCESS) {
		xil_printf("Capture VDMA StartParking failed %d\r\n", Status);
		return Status;
	}
	xil_printf("Capture VDMA running: %dx%d -> 0x%08x\r\n",
	           CAPTURE_W, CAPTURE_H,
	           fb_mm_IP.base_address + CAPTURE_FRAME_SLOT * DEMO_MAX_FRAME);
	return XST_SUCCESS;
}


/*	-------			main			  ------------------*/
int main(int argc, char *argv[])
{

	// default resolution

	dispCtrl0.vMode = VMODE_1280x720x60Hz;

	dispCtrl1.vMode = VMODE_1280x720x60Hz;

	/* unbuffered stdout: a SIGBUS on a stale register address must not
	 * swallow the diagnostics printed before it */
	setvbuf(stdout, NULL, _IONBF, 0);

	printf("colorbars started %s\r\n", dispCtrl0.vMode.label);

	argp_parse(&argpo, argc, argv, 0, 0, 0);


	DemoInitialize();

//	mm_IP scu_timer_mm_IP;
//	TimerInitialize(&scu_timer_mm_IP, SCU_TIMER_ID);
//    int sockfd;
//    struct sockaddr_in servaddr, cliaddr;
//    CircularBuffer cb;
//    struct timeval last_print = {0, 0};
//
//    // Initialize circular buffer
//    initBuffer(&cb);
//
//    // Create UDP socket
//    if ((sockfd = socket(AF_INET, SOCK_DGRAM, 0)) < 0) {
//        perror("socket creation failed");
//        exit(EXIT_FAILURE);
//    }
//
//    // Set socket to non-blocking mode
////    if (setNonBlocking(sockfd) < 0) {
////        close(sockfd);
////        exit(EXIT_FAILURE);
////    }
//
//    memset(&servaddr, 0, sizeof(servaddr));
//    memset(&cliaddr, 0, sizeof(cliaddr));
//
//    // Server configuration
//    servaddr.sin_family = AF_INET;
//    servaddr.sin_addr.s_addr = INADDR_ANY;
//    servaddr.sin_port = htons(PORT);
//
//    // Bind socket to address
//    if (bind(sockfd, (const struct sockaddr *)&servaddr, sizeof(servaddr)) < 0) {
//        perror("bind failed");
//        exit(EXIT_FAILURE);
//    }

//    printf("Non-blocking UDP server listening on port %d\n", PORT);

	// show the colorbars
	// DemoPrintTest(pFramesVirtual0[dispCtrl0.curFrame], dispCtrl0.vMode.width, dispCtrl0.vMode.height, DEMO_STRIDE, DEMO_PATTERN_1);
	//DemoPrintTest(pFramesVirtual0[dispCtrl0.curFrame], dispCtrl0.vMode.width, dispCtrl0.vMode.height, dispCtrl0.stride, DEMO_PATTERN_RED);
	//DemoPrintTest(pFramesVirtual1[dispCtrl1.curFrame], dispCtrl1.vMode.width, dispCtrl1.vMode.height, dispCtrl1.stride, DEMO_PATTERN_GREEN);
	/* LED GPIO at 0x41240000 was removed from the BD (LED is driven by an
	 * xlconstant now) - touching it bus-errors (SIGBUS, external abort) */
//	testLED_IP.base_address = 0x41240000;
//	testLED_IP.size_in_k = 4;
//	create_IP_driver(&testLED_IP);
	int ledState = 0x1;
	if(showmenu) {
		DemoRun();
	} else {
		printf("Loop furever\n");
//		IP_driver_write(&testLED_IP, 0, ledState);
		DemoPrintTest(pFramesVirtual0[dispCtrl0.curFrame], dispCtrl0.vMode.width, dispCtrl0.vMode.height, dispCtrl0.stride, DEMO_PATTERN_D);
		DemoPrintTest(pFramesVirtual1[dispCtrl1.curFrame], dispCtrl1.vMode.width, dispCtrl1.vMode.height, dispCtrl1.stride, DEMO_PATTERN_D);
		for (;;) {
//			TimerDelay(&scu_timer_mm_IP, 100000);  //SEGV!!!
			sleep(10);
			ledState ^= 0x1;
			printf("T%dck\n", ledState);
//			IP_driver_write(&testLED_IP, 0, ledState);
			DemoPrintTest(pFramesVirtual1[dispCtrl1.curFrame], dispCtrl1.vMode.width, dispCtrl1.vMode.height, dispCtrl1.stride, DEMO_PATTERN_D);
//			DemoPrintTest(pFramesVirtual0[dispCtrl0.curFrame], dispCtrl0.vMode.width, dispCtrl0.vMode.height, dispCtrl0.stride, DEMO_PATTERN_D);

//			ssize_t n = recvfrom(sockfd, packet, MAX_PACKET_SIZE, 0,
//					(struct sockaddr *)&cliaddr, &len);
//
//			if (n < 0) {
//				if (errno != EAGAIN && errno != EWOULDBLOCK) {
//					perror("recvfrom failed");
//				}
//				// No data available, do other processing here
//				usleep(1000);  // Sleep for 1ms to prevent CPU spinning
//				continue;
//			}

//			// Write received data to circular buffer
//			if (writeBuffer(&cb, packet, n) < 0) {
//				printf("Buffer full! Dropping packet.\n");
//				continue;
//			}
//			while (n--) {
//				iPixelAddr = (xMid+xInc)*4 + (yMid+yInc)*dispCtrl0.stride;
//				iPixelAddr -=4;
//				pFramesVirtual0[dispCtrl0.curFrame][iPixelAddr] = wRed/2;
//				pFramesVirtual0[dispCtrl0.curFrame][iPixelAddr+1] = wGreen/2;
//				pFramesVirtual0[dispCtrl0.curFrame][iPixelAddr+2] = wBlue/2;
//				iPixelAddr -= dispCtrl0.stride;
//			}
//			// Print status every second
//			struct timeval now;
//			gettimeofday(&now, NULL);
//			if (now.tv_sec > last_print.tv_sec) {
//				printf("Received %zd bytes. Buffer usage: %zu/%d\n",
//					   n, cb.count, BUFFER_SIZE);
//				last_print = now;
//			}
		}
	}
//	close(sockfd);
	destroy_IP_driver(&scu_timer_mm_IP);
	destroy_IP_driver(&fb_mm_IP);
	destroy_IP_driver(&vdma_0_mm_IP);
	destroy_IP_driver(&vdma_1_mm_IP);
	destroy_IP_driver(&vtc_0_mm_IP);
//	destroy_IP_driver(&vtc_1_mm_IP);
	destroy_IP_driver(&dynclk_mm_IP);
//	for (int i = 0; i < 9; i++) {
//		destroy_IP_driver(&(testMix_IP[i]));
//	}
	destroy_IP_driver(&testMix_IP);
	destroy_IP_driver(&testGain0_IP);
	destroy_IP_driver(&testGain1_IP);
	destroy_IP_driver(&testLED_IP);
	return 0;
}

int gm[9][8] = {0};
//int g1[8] = {0,0,0,
//			0,0,0,
//			0,0};
//int g2[8] = {0,0,0,
//			0,0,0,
//			0,0};
//int g6[8] = {0,0,0,
//			0,0,0,
//			0,0,0};
//int g7[8] = {0,0,0,
//			0,0,0,
int gains[2] = {0x00ffffff, 0x00ffffff};
//set rr, gg, bb to steady gain
int cs1[9] = {0xf, 0x1, 0x1,
		0x1, 0xf, 0x1,
		0x1, 0x1, 0xf};


void DemoInitialize()
{
	int Status;
	XAxiVdma_Config *vdma0Config, *vdma1Config;
	//int i;

	/*
	 * Initialize a timer used for a simple delay
	 */
	TimerInitialize(&scu_timer_mm_IP, SCU_TIMER_ID);

//
//	testLED_IP.base_address = 0x41240000;
//	testLED_IP.size_in_k = 64;
//	create_IP_driver(&testLED_IP);
////	dummy = IP_driver_write(&testLED_IP, 0);
//	IP_driver_write(&testLED_IP, 0, 0x1);
////	dummy = IP_driver_write(&testLED_IP, 0);
//
//	TimerDelay(&scu_timer_mm_IP, 1000000);
//	IP_driver_write(&testLED_IP, 0, 0x0);
//	TimerDelay(&scu_timer_mm_IP, 500000);
//	IP_driver_write(&testLED_IP, 0, 0x1);
//	TimerDelay(&scu_timer_mm_IP, 1000000);
//	IP_driver_write(&testLED_IP, 0, 0x0);
//	TimerDelay(&scu_timer_mm_IP, 500000);
//	IP_driver_write(&testLED_IP, 0, 0x1);

	// map the physical VDMA framebuffer memory area to a virtual address
	fb_mm_IP.base_address = 0x08000000;
	fb_mm_IP.size_in_k = 97200; // > 1920x1080x4x6/1024 Bytes
	create_IP_driver(&fb_mm_IP);

	pFramesPhysical0[0] = (u8 *)  fb_mm_IP.base_address;
	pFramesPhysical0[1] = (u8 *) (fb_mm_IP.base_address  +     DEMO_MAX_FRAME);
//	pFramesPhysical0[2] = (u8 *) (fb_mm_IP.base_address  + 2 * DEMO_MAX_FRAME);

	pFramesVirtual0[0] = (u8 *)  fb_mm_IP.ptr;
	pFramesVirtual0[1] = (u8 *) (fb_mm_IP.ptr  +     DEMO_MAX_FRAME);
//	pFramesVirtual0[2] = (u8 *) (fb_mm_IP.ptr  + 2 * DEMO_MAX_FRAME);

	pFramesPhysical1[0] = (u8 *) (fb_mm_IP.base_address  + 2 * DEMO_MAX_FRAME);
	pFramesPhysical1[1] = (u8 *) (fb_mm_IP.base_address  + 3 * DEMO_MAX_FRAME);
//	pFramesPhysical1[2] = (u8 *) (fb_mm_IP.base_address  + 5 * DEMO_MAX_FRAME);

	pFramesVirtual1[0] = (u8 *) (fb_mm_IP.ptr  + 2 * DEMO_MAX_FRAME);
	pFramesVirtual1[1] = (u8 *) (fb_mm_IP.ptr  + 3 * DEMO_MAX_FRAME);
//	pFramesVirtual1[2] = (u8 *) (fb_mm_IP.ptr  + 5 * DEMO_MAX_FRAME);
	/*
	 * Initialize an array of pointers to the 3 frame buffers
	 */
	//for (i = 0; i < DISPLAY_NUM_FRAMES; i++)
	//{
	//	pFrames[i] = frameBuf[i];
	//}

	/*
	 * Initialize VDMA driverssssssssssssss
	 */


	vdma0Config = XAxiVdma_LookupConfig(HDMI_0_VDMA_ID);
	if (!vdma0Config)
	{
		xil_printf("No video DMA found for ID %d\r\n", HDMI_0_VDMA_ID);
		return;
	}
	// create the IP_driver for vdma
	vdma_0_mm_IP.base_address = vdma0Config->BaseAddress;
	vdma_0_mm_IP.size_in_k = 64;
	create_IP_driver(&vdma_0_mm_IP);

	Status = XAxiVdma_CfgInitialize(&vdma_0_mm_IP, &vdma0, vdma0Config, vdma0Config->BaseAddress);
	if (Status != XST_SUCCESS)
	{
		xil_printf("VDMA 0 Configuration Initialization failed %d\r\n", Status);
		return;
	}

	vdma1Config = XAxiVdma_LookupConfig(HDMI_1_VDMA_ID);
	if (!vdma1Config)
	{
		xil_printf("No video DMA found for ID %d\r\n", HDMI_1_VDMA_ID);
		return;
	}
	// create the IP_driver for vdma
	vdma_1_mm_IP.base_address = vdma1Config->BaseAddress;
	vdma_1_mm_IP.size_in_k = 64;
	create_IP_driver(&vdma_1_mm_IP);

	Status = XAxiVdma_CfgInitialize(&vdma_1_mm_IP, &vdma1, vdma1Config, vdma1Config->BaseAddress);
	if (Status != XST_SUCCESS)
	{
		xil_printf("VDMA 1 Configuration Initialization failed %d\r\n", Status);
		return;
	}

	// create the IP_driver for dynclk
	dynclk_mm_IP.base_address = DYNCLK_BASEADDR;
	dynclk_mm_IP.size_in_k = 64;
	create_IP_driver(&dynclk_mm_IP);


	/*
	 * Initialize the Display controller and start it
	 */
	//Status = DisplayInitialize(&vtc_0_mm_IP, &dynclk_mm_IP, &dispCtrl0, &vdma0, DISP_0_VTC_ID, DYNCLK_BASEADDR, pFramesPhysical0, DEMO_STRIDE);
	Status = DisplayInitialize(&vtc_0_mm_IP, &dynclk_mm_IP, &dispCtrl0, &vdma0, DISP_0_VTC_ID, DYNCLK_BASEADDR, pFramesPhysical0, dispCtrl0.vMode.width*4);
		if (Status != XST_SUCCESS)
	{
		xil_printf("Display Ctrl 0 initialization failed during demo initialization - %d\r\n", Status);
		return;
	}
	Status = DisplayStart(&vtc_0_mm_IP,&vdma_0_mm_IP,&dynclk_mm_IP, &dispCtrl0);
	if (Status != XST_SUCCESS)
	{
		xil_printf("Couldn't start display 0 during demo initialization - %d\r\n", Status);
		return;
	}

	Status = DisplayInitialize(&vtc_0_mm_IP, &dynclk_mm_IP, &dispCtrl1, &vdma1, DISP_0_VTC_ID, DYNCLK_BASEADDR, pFramesPhysical1, dispCtrl1.vMode.width*4);
	if (Status != XST_SUCCESS)
	{
		xil_printf("Display Ctrl 1 initialization failed during demo initialization - %d\r\n", Status);
		return;
	}
	Status = DisplayStart(&vtc_0_mm_IP,&vdma_1_mm_IP,&dynclk_mm_IP, &dispCtrl1);
	if (Status != XST_SUCCESS)
	{
		xil_printf("Couldn't start display 1 during demo initialization - %d\r\n", Status);
		return;
	}

	CaptureInitialize();

	//GG DemoPrintTest(dispCtrl0.framePtr[dispCtrl0.curFrame], dispCtrl0.vMode.width, dispCtrl0.vMode.height, dispCtrl0.stride, DEMO_PATTERN_1);
	//DemoPrintTest(pFramesVirtual0[dispCtrl0.curFrame], dispCtrl0.vMode.width, dispCtrl0.vMode.height, dispCtrl0.stride, DEMO_PATTERN_1);
	testGain0_IP.base_address = TEST_GAIN_0_ADDR;
	testGain0_IP.size_in_k = 64;
	create_IP_driver(&testGain0_IP);
	IP_driver_write(&testGain0_IP, 0, 0x00ffffff);


	testGain1_IP.base_address = TEST_GAIN_1_ADDR;
	testGain1_IP.size_in_k = 64;
	create_IP_driver(&testGain1_IP);
	IP_driver_write(&testGain1_IP, 0, 0x00010101);

	testMix_IP[0].base_address = NU_MIXER_0_ADDR;
	testMix_IP[0].size_in_k = 64;
//	testMix_IP[1].base_address = TEST_MIXER_1_ADDR;
//	testMix_IP[1].size_in_k = 64;
//	testMix_IP[2].base_address = TEST_MIXER_2_ADDR;
//	testMix_IP[2].size_in_k = 64;

//	testMix_IP[3].base_address = TEST_MIXER_3_ADDR;
//	testMix_IP[3].size_in_k = 64;
//	testMix_IP[4].base_address = TEST_MIXER_4_ADDR;
//	testMix_IP[4].size_in_k = 64;
//	testMix_IP[5].base_address = TEST_MIXER_5_ADDR;
//	testMix_IP[5].size_in_k = 64;
//
//	testMix_IP[6].base_address = TEST_MIXER_6_ADDR;
//	testMix_IP[6].size_in_k = 64;
//	testMix_IP[7].base_address = TEST_MIXER_7_ADDR;
//	testMix_IP[7].size_in_k = 64;
//	testMix_IP[8].base_address = TEST_MIXER_8_ADDR;
//	testMix_IP[8].size_in_k = 64;


//	for (int i = 0; i < 9; i++) {
//		if (i != 1 && i != 2) {
//			create_IP_driver(&(testMix_IP[i]));
//			IP_driver_write(&(testMix_IP[i]), MIXER_S00_AXI_SLV_REG8_OFFSET, cs[i]);
//	////    IP_driver_write(&(testMix_IP[i]), MIXER_S00_AXI_SLV_REG9_OFFSET, cs[1]);
//			IP_driver_write(&(testMix_IP[i]), 0, gs[i]);
//	//		IP_driver_write(&(testMix_IP[i]), MIXER_S00_AXI_SLV_REG1_OFFSET, g2[i]);
//	//		IP_driver_write(&(testMix_IP[i]), MIXER_S00_AXI_SLV_REG2_OFFSET, g3[i]);
//		}
//	}
	create_IP_driver(&testMix_IP);
//	IP_driver_write(&testGain0_IP, 0, gains[0]);
//	IP_driver_write(&testGain1_IP, 0, gains[1]);
//	for (int i = 0; i < 9; i++) {
//		create_IP_driver(&(testMix_IP[i]));
//		IP_driver_write(&(testMix_IP[i]), MIXER_S00_AXI_SLV_REG0_OFFSET, 0x0);
//		IP_driver_write(&(testMix_IP[i]), MIXER_S00_AXI_SLV_REG1_OFFSET, 0x0);
//		IP_driver_write(&(testMix_IP[i]), MIXER_S00_AXI_SLV_REG2_OFFSET, 0x0);
//		IP_driver_write(&(testMix_IP[i]), MIXER_S00_AXI_SLV_REG8_OFFSET, 0x3);
//		IP_driver_write(&(testMix_IP[i]), MIXER_S00_AXI_SLV_REG9_OFFSET, 0x0);
//	}
//
//	IP_driver_write(&(testMix_IP[0]), MIXER_S00_AXI_SLV_REG0_OFFSET, 0xffff);
//	IP_driver_write(&(testMix_IP[5]), MIXER_S00_AXI_SLV_REG0_OFFSET, 0xffff);
//	IP_driver_write(&(testMix_IP[6]), MIXER_S00_AXI_SLV_REG0_OFFSET, 0xffff);

	return;
}


void DemoRun()
{
	int nextFrame = 0;
	char userInput = 0;

	int hold = 1;
	/*
	 * Initialize a timer used for a simple delay
    */
	// create the IP_driver for SCU Timer
	// it will be set inside TimweInitialize
	mm_IP scu_timer_mm_IP;
	TimerInitialize(&scu_timer_mm_IP, SCU_TIMER_ID);


	// Flush UART FIFO
	/*
	while (XUartPs_IsReceiveData(UART_BASEADDR))
	{
		XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
	}
	*/
	//system ("/bin/stty raw");
	while (userInput != 'q')
	{
		DemoPrintMenu();

		// Wait for data on UART
		//while (!XUartPs_IsReceiveData(UART_BASEADDR))
		//{}
		userInput = getchar();
		// Store the first character in the UART receive FIFO and echo it
		//if (XUartPs_IsReceiveData(UART_BASEADDR))
		//{
		//	userInput = XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
		//	xil_printf("%c", userInput);
		//}
		printf("%c",userInput);

		u32 xcoi, ycoi;
		u32 iPixelAddr;
		u8 wRed = 0, wBlue = 128, wGreen= 255, wAlpha = 255;
		int wCurrentInt = 40000;
		double fRed, fBlue, fGreen, fColor;
		int xLeft, xMid, xRight, xInt = 1;
		int yMid, yInt = 1;
		int xInc = 0, yInc = 0;

		switch (userInput)
		{
//		case ')':
//			for (int i = 0; i < 9; i+=4) {
//				if (i != 1 && i != 2) {
//					IP_driver_write(&(testMix_IP[i]), MIXER_S00_AXI_SLV_REG8_OFFSET, 0x0);
//					IP_driver_write(&(testMix_IP[i]), MIXER_S00_AXI_SLV_REG9_OFFSET, 0x0);
//				}
//			}
//			break;
//		case '!':
//			for (int i = 0; i < 9; i+=4) {
//				if (i != 1 && i != 2) {
//					IP_driver_write(&(testMix_IP[i]), MIXER_S00_AXI_SLV_REG8_OFFSET, 0x1);
//					IP_driver_write(&(testMix_IP[i]), MIXER_S00_AXI_SLV_REG9_OFFSET, 0x1);
//				}
//			}
//			break;
//		case '@':
//			for (int i = 0; i < 9; i+=4) {
//				if (i != 1 && i != 2) {
//					IP_driver_write(&(testMix_IP[i]), MIXER_S00_AXI_SLV_REG8_OFFSET, 0x2);
//					IP_driver_write(&(testMix_IP[i]), MIXER_S00_AXI_SLV_REG9_OFFSET, 0x2);
//				}
//			}
//			break;
//		case '#':
//			for (int i = 0; i < 9; i+=4) {
//				if (i != 1 && i != 2) {
//					IP_driver_write(&(testMix_IP[i]), MIXER_S00_AXI_SLV_REG8_OFFSET, 0x3);
//					IP_driver_write(&(testMix_IP[i]), MIXER_S00_AXI_SLV_REG9_OFFSET, 0x3);
//				}
//			}
//			break;
		case 'f':
			for (int h = 9000; h < 10000; h+=100) {
				for (int i =0; i < 0xff; i++) {
					IP_driver_write(&testGain0_IP, 0, (i << 16) + (i << 8) + i);
					int j = 1280;
					while(j--){
						IP_driver_write(&testMix_IP, (j%9)*8, j&0xffff);
					}
				}
			}
			break;
		case 'j':

			yMid = dispCtrl1.vMode.height/2;
			xMid = dispCtrl1.vMode.width/2;
			wCurrentInt = 40000;
			while (wCurrentInt--) {
				iPixelAddr = (xMid+xInc)*4 + (yMid+yInc)*dispCtrl1.stride;
				iPixelAddr -=4;
				pFramesVirtual1[dispCtrl1.curFrame][iPixelAddr] = wRed/2;
				pFramesVirtual1[dispCtrl1.curFrame][iPixelAddr+1] = wGreen/2;
				pFramesVirtual1[dispCtrl1.curFrame][iPixelAddr+2] = wBlue/2;
				iPixelAddr -= dispCtrl1.stride;
				pFramesVirtual1[dispCtrl1.curFrame][iPixelAddr] = wRed/2;
				pFramesVirtual1[dispCtrl1.curFrame][iPixelAddr+1] = wGreen/2;
				pFramesVirtual1[dispCtrl1.curFrame][iPixelAddr+2] = wBlue/2;
				iPixelAddr = (xMid+xInc)*4 + (yMid+yInc)*dispCtrl1.stride;
				pFramesVirtual1[dispCtrl1.curFrame][iPixelAddr] = wRed;
				pFramesVirtual1[dispCtrl1.curFrame][iPixelAddr+1] = wGreen;
				pFramesVirtual1[dispCtrl1.curFrame][iPixelAddr+2] = wBlue;
				iPixelAddr +=4;
				pFramesVirtual1[dispCtrl1.curFrame][iPixelAddr] = wRed/2;
				pFramesVirtual1[dispCtrl1.curFrame][iPixelAddr+1] = wGreen/2;
				pFramesVirtual1[dispCtrl1.curFrame][iPixelAddr+2] = wBlue/2;
				iPixelAddr += dispCtrl1.stride;
				pFramesVirtual1[dispCtrl1.curFrame][iPixelAddr] = wRed/2;
				pFramesVirtual1[dispCtrl1.curFrame][iPixelAddr+1] = wGreen/2;
				pFramesVirtual1[dispCtrl1.curFrame][iPixelAddr+2] = wBlue/2;

				xInc += xInt;
				if (xInc % 6 == 0) yInc += yInt;
				if (xInc >= 300) {
					xInt = -1;
				} else if (xInc <= -300) {
					xInt = 1;
				}
				if (yInc >= 300) {
					yInt = -2;
				} else if (yInc <= -300) {
					yInt = 2;
				}
			}
			break;
		case 'i':

			yMid = dispCtrl0.vMode.height/2;
			xMid = dispCtrl0.vMode.width/2;
			wCurrentInt = 40000;
			while (wCurrentInt--) {
				iPixelAddr = (xMid+xInc)*4 + (yMid+yInc)*dispCtrl0.stride;
				iPixelAddr -=4;
				pFramesVirtual0[dispCtrl0.curFrame][iPixelAddr] = wRed/2;
				pFramesVirtual0[dispCtrl0.curFrame][iPixelAddr+1] = wGreen/2;
				pFramesVirtual0[dispCtrl0.curFrame][iPixelAddr+2] = wBlue/2;
				iPixelAddr -= dispCtrl0.stride;
				pFramesVirtual0[dispCtrl0.curFrame][iPixelAddr] = wRed/2;
				pFramesVirtual0[dispCtrl0.curFrame][iPixelAddr+1] = wGreen/2;
				pFramesVirtual0[dispCtrl0.curFrame][iPixelAddr+2] = wBlue/2;
				iPixelAddr = (xMid+xInc)*4 + (yMid+yInc)*dispCtrl0.stride;
				pFramesVirtual0[dispCtrl0.curFrame][iPixelAddr] = wRed;
				pFramesVirtual0[dispCtrl0.curFrame][iPixelAddr+1] = wGreen;
				pFramesVirtual0[dispCtrl0.curFrame][iPixelAddr+2] = wBlue;
				iPixelAddr +=4;
				pFramesVirtual0[dispCtrl0.curFrame][iPixelAddr] = wRed/2;
				pFramesVirtual0[dispCtrl0.curFrame][iPixelAddr+1] = wGreen/2;
				pFramesVirtual0[dispCtrl0.curFrame][iPixelAddr+2] = wBlue/2;
				iPixelAddr += dispCtrl0.stride;
				pFramesVirtual0[dispCtrl0.curFrame][iPixelAddr] = wRed/2;
				pFramesVirtual0[dispCtrl0.curFrame][iPixelAddr+1] = wGreen/2;
				pFramesVirtual0[dispCtrl0.curFrame][iPixelAddr+2] = wBlue/2;

				xInc += xInt;
				if (xInc % 4 == 0) yInc += yInt;
				if (xInc >= 200) {
					xInt = -1;
				} else if (xInc <= -200) {
					xInt = 1;
				}
				if (yInc >= 200) {
					yInt = -2;
				} else if (yInc <= -200) {
					yInt = 2;
				}
			}
			break;
		case 'c':
//			while (hold) {
				//for i in $(seq 1 0xff); do devmem 0x43c50000 32 $i; done
				for (int i = 0; i < 9; i++) {
//					IP_driver_write(&(testMix_IP[i]), MIXER_S00_AXI_SLV_REG8_OFFSET, cs[i]);
////					IP_driver_write(&(testMix_IP[i]), MIXER_S00_AXI_SLV_REG9_OFFSET, cs[1]);
//					IP_driver_write(&(testMix_IP[i]), 0, g0[i]);
//					IP_driver_write(&(testMix_IP[i]), MIXER_S00_AXI_SLV_REG1_OFFSET, g0[i]);
//					IP_driver_write(&(testMix_IP[i]), MIXER_S00_AXI_SLV_REG2_OFFSET, g0[i]);
				}
				IP_driver_write(&testGain0_IP, 0, gains[0]);
				IP_driver_write(&testGain1_IP, 0, gains[1]);
//			}
			break;
		case '1':
			DemoChangeRes();
			break;
		case '2':
			nextFrame = dispCtrl0.curFrame + 1;
			nextFrame = dispCtrl1.curFrame + 1;
			if (nextFrame >= DISPLAY_NUM_FRAMES)
			{
				nextFrame = 0;
			}
			DisplayChangeFrame(&vdma_0_mm_IP, &dispCtrl0, nextFrame);
			DisplayChangeFrame(&vdma_1_mm_IP, &dispCtrl1, nextFrame);
			break;

		case 'a': {
			/* cycle live HDMI_2 input: off -> display 1 -> display 0 -> off
			 * frame index 1 of the chosen display is repointed at the
			 * capture slot; index 0 keeps the normal content so restoring
			 * is just parking back on index 0.
			 *
			 * CRITICAL: a START_ADDRESS register write reads back fine but
			 * the scanout keeps fetching the PREVIOUSLY committed address
			 * until VSIZE is rewritten. XAxiVdma_DmaStart on a running
			 * channel skips the RS write and just rewrites VSIZE - that is
			 * the recommit. Without it this toggle displays stale memory
			 * (looks like RAM noise) instead of the capture. */
			static int liveInputState = 0;
			u32 capAddr = fb_mm_IP.base_address
					+ CAPTURE_FRAME_SLOT * DEMO_MAX_FRAME;
			switch (liveInputState) {
			case 0:	/* off -> input on display 1 */
				dispCtrl1.vdmaConfig.FrameStoreStartAddr[1] = capAddr;
				XAxiVdma_DmaSetBufferAddr(&vdma_1_mm_IP, &vdma1,
					XAXIVDMA_READ, dispCtrl1.vdmaConfig.FrameStoreStartAddr);
				/* recommit: address regs only latch on next VSIZE write */
				XAxiVdma_DmaStart(&vdma_1_mm_IP, &vdma1, XAXIVDMA_READ);
				DisplayChangeFrame(&vdma_1_mm_IP, &dispCtrl1, 1);
				xil_printf("\n\rlive input -> display 1");
				liveInputState = 1;
				break;
			case 1:	/* display 1 back to normal, input on display 0 */
				dispCtrl1.vdmaConfig.FrameStoreStartAddr[1] =
					(u32) pFramesPhysical1[1];
				XAxiVdma_DmaSetBufferAddr(&vdma_1_mm_IP, &vdma1,
					XAXIVDMA_READ, dispCtrl1.vdmaConfig.FrameStoreStartAddr);
				/* recommit: address regs only latch on next VSIZE write */
				XAxiVdma_DmaStart(&vdma_1_mm_IP, &vdma1, XAXIVDMA_READ);
				DisplayChangeFrame(&vdma_1_mm_IP, &dispCtrl1, 0);

				dispCtrl0.vdmaConfig.FrameStoreStartAddr[1] = capAddr;
				XAxiVdma_DmaSetBufferAddr(&vdma_0_mm_IP, &vdma0,
					XAXIVDMA_READ, dispCtrl0.vdmaConfig.FrameStoreStartAddr);
				/* recommit: address regs only latch on next VSIZE write */
				XAxiVdma_DmaStart(&vdma_0_mm_IP, &vdma0, XAXIVDMA_READ);
				DisplayChangeFrame(&vdma_0_mm_IP, &dispCtrl0, 1);
				xil_printf("\n\rlive input -> display 0");
				liveInputState = 2;
				break;
			default: /* display 0 back to normal, input off */
				dispCtrl0.vdmaConfig.FrameStoreStartAddr[1] =
					(u32) pFramesPhysical0[1];
				XAxiVdma_DmaSetBufferAddr(&vdma_0_mm_IP, &vdma0,
					XAXIVDMA_READ, dispCtrl0.vdmaConfig.FrameStoreStartAddr);
				/* recommit: address regs only latch on next VSIZE write */
				XAxiVdma_DmaStart(&vdma_0_mm_IP, &vdma0, XAXIVDMA_READ);
				DisplayChangeFrame(&vdma_0_mm_IP, &dispCtrl0, 0);
				xil_printf("\n\rlive input off");
				liveInputState = 0;
				break;
			}
			break;
		}
		case 'r':
			// DemoPrintTest(pFramesVirtual0[dispCtrl0.curFrame], dispCtrl0.vMode.width, dispCtrl0.vMode.height, DEMO_STRIDE, DEMO_PATTERN_0);
			DemoPrintTest(pFramesVirtual0[dispCtrl0.curFrame], dispCtrl0.vMode.width, dispCtrl0.vMode.height, dispCtrl0.stride, DEMO_PATTERN_RED);
			DemoPrintTest(pFramesVirtual1[dispCtrl1.curFrame], dispCtrl1.vMode.width, dispCtrl1.vMode.height, dispCtrl1.stride, DEMO_PATTERN_RED);
			break;
		case '3':
			// DemoPrintTest(pFramesVirtual0[dispCtrl0.curFrame], dispCtrl0.vMode.width, dispCtrl0.vMode.height, DEMO_STRIDE, DEMO_PATTERN_0);
			DemoPrintTest(pFramesVirtual0[dispCtrl0.curFrame], dispCtrl0.vMode.width, dispCtrl0.vMode.height, dispCtrl0.stride, DEMO_PATTERN_0);
			DemoPrintTest(pFramesVirtual1[dispCtrl1.curFrame], dispCtrl1.vMode.width, dispCtrl1.vMode.height, dispCtrl1.stride, DEMO_PATTERN_0);
			break;
		case '4':
			//DemoPrintTest(pFramesVirtual0[dispCtrl0.curFrame], dispCtrl0.vMode.width, dispCtrl0.vMode.height, DEMO_STRIDE, DEMO_PATTERN_1);
			DemoPrintTest(pFramesVirtual0[dispCtrl0.curFrame], dispCtrl0.vMode.width, dispCtrl0.vMode.height, dispCtrl0.stride, DEMO_PATTERN_1);
			DemoPrintTest(pFramesVirtual1[dispCtrl1.curFrame], dispCtrl1.vMode.width, dispCtrl1.vMode.height, dispCtrl1.stride, DEMO_PATTERN_1);
			break;
		case '5':
			//GG DemoInvertFrame(dispCtrl0.frramePtr[dispCtrl0.curFrame], dispCtrl0.framePtr[dispCtrl0.curFrame], dispCtrl0.vMode.width, dispCtrl0.vMode.height, dispCtrl0.stride);
			DemoInvertFrame(pFramesVirtual0[dispCtrl0.curFrame], pFramesVirtual0[dispCtrl0.curFrame], dispCtrl0.vMode.width, dispCtrl0.vMode.height, dispCtrl0.stride);
			DemoInvertFrame(pFramesVirtual1[dispCtrl1.curFrame], pFramesVirtual1[dispCtrl1.curFrame], dispCtrl1.vMode.width, dispCtrl1.vMode.height, dispCtrl1.stride);
			break;
		case '6':
			nextFrame = dispCtrl0.curFrame + 1;
			if (nextFrame >= DISPLAY_NUM_FRAMES)
			{
				nextFrame = 0;
			}
			DemoInvertFrame(pFramesVirtual0[dispCtrl0.curFrame], pFramesVirtual0[nextFrame], dispCtrl0.vMode.width, dispCtrl0.vMode.height, dispCtrl0.stride);
			DisplayChangeFrame(&vdma_0_mm_IP, &dispCtrl0, nextFrame);
			DemoInvertFrame(pFramesVirtual1[dispCtrl1.curFrame], pFramesVirtual1[nextFrame], dispCtrl1.vMode.width, dispCtrl1.vMode.height, dispCtrl1.stride);
			DisplayChangeFrame(&vdma_1_mm_IP, &dispCtrl1, nextFrame);
			break;
		case 'q':
			break;
		default :
			xil_printf("\n\rInvalid Selection");
			//TimerDelay(&scu_timer_mm_IP, 500000);
		}
	}
	//system ("/bin/stty cooked");
	return;
}

void DemoPrintMenu()
{
	xil_printf("\x1B[H"); //Set cursor to top left of terminal
	xil_printf("\x1B[2J"); //Clear terminal
	xil_printf("**************************************************\n\r");
	xil_printf("*               DEBAZAROS Display Demo            *\n\r");
	xil_printf("**************************************************\n\r");
	xil_printf("*Display Resolution: %28s*\n\r", dispCtrl0.vMode.label);
	printf("*Display Pixel Clock Freq. (MHz): %15.3f*\n\r", dispCtrl0.pxlFreq);
	xil_printf("*Display Frame Index: %27d*\n\r", dispCtrl0.curFrame);
	xil_printf("**************************************************\n\r");
	xil_printf("\n\r");
	xil_printf("1 - Change Display Resolution\n\r");
	xil_printf("2 - Change Display Framebuffer Index\n\r");
	xil_printf("3 - Print Blended Test Pattern to Display Framebuffer\n\r");
	xil_printf("4 - Print Color Bar Test Pattern to Display Framebuffer\n\r");
	xil_printf("5 - Invert Current Frame colors\n\r");
	xil_printf("6 - Invert Current Frame colors seamlessly\n\r");
	xil_printf("a - Cycle live HDMI input (off / display 1 / display 0)\n\r");
	xil_printf("q - Quit\n\r");
	xil_printf("\n\r");
	xil_printf("\n\r");
	xil_printf("Enter a selection:");
}

void DemoChangeRes()
{
	int fResSet = 0;
	int status[2];
	char userInput = 0;

	// Flush UART FIFO
	//while (XUartPs_IsReceiveData(UART_BASEADDR))
	//{
	//	XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
	//}

	while (!fResSet)
	{
		DemoCRMenu();

		// Wait for data on UART
		//while (!XUartPs_IsReceiveData(UART_BASEADDR))
		//{}
		userInput = getchar();

		// Store the first character in the UART recieve FIFO and echo it
		//userInput = XUartPs_ReadReg(UART_BASEADDR, XUARTPS_FIFO_OFFSET);
		xil_printf("%c", userInput);
		status[0] = XST_SUCCESS;
		status[1] = XST_SUCCESS;
		switch (userInput)
		{
		case '1':
			status[0] = DisplayStop(&vdma_0_mm_IP, &vtc_0_mm_IP, &dispCtrl0);
			status[1] = DisplayStop(&vdma_1_mm_IP, &vtc_0_mm_IP, &dispCtrl1);
			DisplaySetMode(&vdma_0_mm_IP, &vtc_0_mm_IP, &dispCtrl0, &VMODE_640x480);
			DisplaySetMode(&vdma_1_mm_IP, &vtc_0_mm_IP, &dispCtrl1, &VMODE_640x480);
			DisplayStart(&vtc_0_mm_IP,&vdma_0_mm_IP, &dynclk_mm_IP, &dispCtrl0);
			DisplayStart(&vtc_0_mm_IP,&vdma_1_mm_IP, &dynclk_mm_IP, &dispCtrl1);
			fResSet = 1;
			break;
		case '2':
			status[0] = DisplayStop(&vdma_0_mm_IP, &vtc_0_mm_IP, &dispCtrl0);
			status[1] = DisplayStop(&vdma_1_mm_IP, &vtc_0_mm_IP, &dispCtrl1);
			DisplaySetMode(&vdma_0_mm_IP, &vtc_0_mm_IP,&dispCtrl0, &VMODE_800x600);
			DisplaySetMode(&vdma_1_mm_IP, &vtc_0_mm_IP, &dispCtrl1, &VMODE_800x600);
			DisplayStart(&vtc_0_mm_IP,&vdma_0_mm_IP, &dynclk_mm_IP,&dispCtrl0);
			DisplayStart(&vtc_0_mm_IP,&vdma_1_mm_IP, &dynclk_mm_IP, &dispCtrl1);
			fResSet = 1;
			break;
		case '3':
			status[0] = DisplayStop(&vdma_0_mm_IP, &vtc_0_mm_IP, &dispCtrl0);
			status[1] = DisplayStop(&vdma_1_mm_IP, &vtc_0_mm_IP, &dispCtrl1);
			DisplaySetMode(&vdma_0_mm_IP, &vtc_0_mm_IP,&dispCtrl0, &VMODE_1280x720x60Hz);
			DisplaySetMode(&vdma_1_mm_IP, &vtc_0_mm_IP, &dispCtrl1, &VMODE_1280x720x60Hz);
			DisplayStart(&vtc_0_mm_IP,&vdma_0_mm_IP, &dynclk_mm_IP,&dispCtrl0);
			DisplayStart(&vtc_0_mm_IP,&vdma_1_mm_IP, &dynclk_mm_IP, &dispCtrl1);
			fResSet = 1;
			break;

		case '4':
			status[0] = DisplayStop(&vdma_0_mm_IP, &vtc_0_mm_IP, &dispCtrl0);
			status[1] = DisplayStop(&vdma_1_mm_IP, &vtc_0_mm_IP, &dispCtrl1);
			DisplaySetMode(&vdma_0_mm_IP, &vtc_0_mm_IP,&dispCtrl0, &VMODE_1280x720x50Hz);
			DisplaySetMode(&vdma_1_mm_IP, &vtc_0_mm_IP, &dispCtrl1, &VMODE_1280x720x50Hz);
			DisplayStart(&vtc_0_mm_IP,&vdma_0_mm_IP, &dynclk_mm_IP,&dispCtrl0);
			DisplayStart(&vtc_0_mm_IP,&vdma_1_mm_IP, &dynclk_mm_IP, &dispCtrl1);
			fResSet = 1;
			break;

		case '5':
			status[0] = DisplayStop(&vdma_0_mm_IP, &vtc_0_mm_IP, &dispCtrl0);
			status[1] = DisplayStop(&vdma_1_mm_IP, &vtc_0_mm_IP, &dispCtrl1);
			DisplaySetMode(&vdma_0_mm_IP, &vtc_0_mm_IP,&dispCtrl0, &VMODE_1280x720x45Hz);
			DisplaySetMode(&vdma_1_mm_IP, &vtc_0_mm_IP, &dispCtrl1, &VMODE_1280x720x45Hz);
			DisplayStart(&vtc_0_mm_IP,&vdma_0_mm_IP, &dynclk_mm_IP,&dispCtrl0);
			DisplayStart(&vtc_0_mm_IP,&vdma_1_mm_IP, &dynclk_mm_IP, &dispCtrl1);
			fResSet = 1;
			break;


		case '6':
			status[0] = DisplayStop(&vdma_0_mm_IP, &vtc_0_mm_IP, &dispCtrl0);
			status[1] = DisplayStop(&vdma_1_mm_IP, &vtc_0_mm_IP, &dispCtrl1);
			DisplaySetMode(&vdma_0_mm_IP, &vtc_0_mm_IP,&dispCtrl0, &VMODE_1280x720x30Hz);
			DisplaySetMode(&vdma_1_mm_IP, &vtc_0_mm_IP, &dispCtrl1, &VMODE_1280x720x30Hz);
			DisplayStart(&vtc_0_mm_IP,&vdma_0_mm_IP, &dynclk_mm_IP,&dispCtrl0);
			DisplayStart(&vtc_0_mm_IP,&vdma_1_mm_IP, &dynclk_mm_IP, &dispCtrl1);
			fResSet = 1;
			break;

		case '7':
			status[0] = DisplayStop(&vdma_0_mm_IP, &vtc_0_mm_IP, &dispCtrl0);
			status[1] = DisplayStop(&vdma_1_mm_IP, &vtc_0_mm_IP, &dispCtrl1);
			DisplaySetMode(&vdma_0_mm_IP, &vtc_0_mm_IP,&dispCtrl0, &VMODE_1280x720x25Hz);
			DisplaySetMode(&vdma_1_mm_IP, &vtc_0_mm_IP, &dispCtrl1, &VMODE_1280x720x25Hz);
			DisplayStart(&vtc_0_mm_IP,&vdma_0_mm_IP, &dynclk_mm_IP,&dispCtrl0);
			DisplayStart(&vtc_0_mm_IP,&vdma_1_mm_IP, &dynclk_mm_IP, &dispCtrl1);
			fResSet = 1;
			break;


		case '8':
			status[0] = DisplayStop(&vdma_0_mm_IP, &vtc_0_mm_IP, &dispCtrl0);
			status[1] = DisplayStop(&vdma_1_mm_IP, &vtc_0_mm_IP, &dispCtrl1);
			DisplaySetMode(&vdma_0_mm_IP, &vtc_0_mm_IP,&dispCtrl0, &VMODE_1280x1024);
			DisplaySetMode(&vdma_1_mm_IP, &vtc_0_mm_IP, &dispCtrl1, &VMODE_1280x1024);
			DisplayStart(&vtc_0_mm_IP,&vdma_0_mm_IP, &dynclk_mm_IP,&dispCtrl0);
			DisplayStart(&vtc_0_mm_IP,&vdma_1_mm_IP, &dynclk_mm_IP, &dispCtrl1);
			fResSet = 1;
			break;
		case '9':
			status[0] = DisplayStop(&vdma_0_mm_IP, &vtc_0_mm_IP, &dispCtrl0);
			status[1] = DisplayStop(&vdma_1_mm_IP, &vtc_0_mm_IP, &dispCtrl1);
			DisplaySetMode(&vdma_0_mm_IP, &vtc_0_mm_IP,&dispCtrl0, &VMODE_1920x1080x60Hz);
			DisplaySetMode(&vdma_1_mm_IP, &vtc_0_mm_IP, &dispCtrl1, &VMODE_1920x1080x60Hz);
			DisplayStart(&vtc_0_mm_IP,&vdma_0_mm_IP, &dynclk_mm_IP,&dispCtrl0);
			DisplayStart(&vtc_0_mm_IP,&vdma_1_mm_IP, &dynclk_mm_IP, &dispCtrl1);
			fResSet = 1;
			break;
		case 'a':
			status[0] = DisplayStop(&vdma_0_mm_IP, &vtc_0_mm_IP, &dispCtrl0);
			status[1] = DisplayStop(&vdma_1_mm_IP, &vtc_0_mm_IP, &dispCtrl1);
			DisplaySetMode(&vdma_0_mm_IP, &vtc_0_mm_IP,&dispCtrl0, &VMODE_1920x1080x30Hz);
			DisplaySetMode(&vdma_1_mm_IP, &vtc_0_mm_IP, &dispCtrl1, &VMODE_1920x1080x30Hz);
			DisplayStart(&vtc_0_mm_IP,&vdma_0_mm_IP, &dynclk_mm_IP,&dispCtrl0);
			DisplayStart(&vtc_0_mm_IP,&vdma_1_mm_IP, &dynclk_mm_IP, &dispCtrl1);
			fResSet = 1;
			break;
		case 'b':
			status[0] = DisplayStop(&vdma_0_mm_IP, &vtc_0_mm_IP, &dispCtrl0);
			status[1] = DisplayStop(&vdma_1_mm_IP, &vtc_0_mm_IP, &dispCtrl1);
			DisplaySetMode(&vdma_0_mm_IP, &vtc_0_mm_IP,&dispCtrl0, &VMODE_1920x1080x25Hz);
			DisplaySetMode(&vdma_1_mm_IP, &vtc_0_mm_IP, &dispCtrl1, &VMODE_1920x1080x25Hz);
			DisplayStart(&vtc_0_mm_IP,&vdma_0_mm_IP, &dynclk_mm_IP,&dispCtrl0);
			DisplayStart(&vtc_0_mm_IP,&vdma_1_mm_IP, &dynclk_mm_IP, &dispCtrl1);
			fResSet = 1;
			break;
		case 'q':
			fResSet = 1;
			break;
		default :
			xil_printf("\n\rInvalid Selection");
			//TimerDelay(500000);
		}
		if (status[0] == XST_DMA_ERROR || status[1] == XST_DMA_ERROR)
		{
			xil_printf("\n\rWARNING: AXI VDMA Error detected and cleared\n\r");
		}
	}
}

void DemoCRMenu()
{
	xil_printf("\x1B[H"); //Set cursor to top left of terminal
	xil_printf("\x1B[2J"); //Clear terminal
	xil_printf("**************************************************\n\r");
	xil_printf("*           DEBAZAROS Display Demo                *\n\r");
	xil_printf("**************************************************\n\r");
	xil_printf("*Current Resolution: %28s*\n\r", dispCtrl0.vMode.label);
	printf("*Pixel Clock Freq. (MHz): %23.3f*\n\r", dispCtrl0.pxlFreq);
	xil_printf("**************************************************\n\r");
	xil_printf("\n\r");
	xil_printf("1 - %s\n\r", VMODE_640x480.label);
	xil_printf("2 - %s\n\r", VMODE_800x600.label);
	xil_printf("3 - %s\n\r", VMODE_1280x720x60Hz.label);
	xil_printf("4 - %s\n\r", VMODE_1280x720x50Hz.label);
	xil_printf("5 - %s\n\r", VMODE_1280x720x45Hz.label);
	xil_printf("6 - %s\n\r", VMODE_1280x720x30Hz.label);
	xil_printf("7 - %s\n\r", VMODE_1280x720x25Hz.label);
	xil_printf("8 - %s\n\r", VMODE_1280x1024.label);
	xil_printf("9 - %s\n\r", VMODE_1920x1080x60Hz.label);
	xil_printf("a - %s\n\r", VMODE_1920x1080x30Hz.label);
	xil_printf("b - %s\n\r", VMODE_1920x1080x25Hz.label);
	xil_printf("q - Quit (don't change resolution)\n\r");
	xil_printf("\n\r");
	xil_printf("Select a new resolution:");
}

void DemoInvertFrame(u8 *srcFrame, u8 *destFrame, u32 width, u32 height, u32 stride)
{
	u32 xcoi, ycoi;
	u32 lineStart = 0;
	for(ycoi = 0; ycoi < height; ycoi++)
	{
		for(xcoi = 0; xcoi < (width * 4); xcoi+=4)
		{
			destFrame[xcoi + lineStart] = ~srcFrame[xcoi + lineStart];         //Red
			destFrame[xcoi + lineStart + 1] = ~srcFrame[xcoi + lineStart + 1]; //Blue
			destFrame[xcoi + lineStart + 2] = ~srcFrame[xcoi + lineStart + 2]; //Green
		}
		lineStart += stride;
	}
	//
	// * Flush the framebuffer memory range to ensure changes are written to the
	// * actual memory, and therefore accessible by the VDMA.
	// *
	//GG Xil_DCacheFlushRange((unsigned int) destFrame, DEMO_MAX_FRAME);
}


void DemoPrintTest(u8 *frame, u32 width, u32 height, u32 stride, int pattern)
{
	u32 xcoi, ycoi;
	u32 iPixelAddr;
	u8 wRed = 255, wBlue = 128, wGreen= 0, wAlpha = 255;
	u32 wCurrentInt;
	double fRed, fBlue, fGreen, fColor;
	u32 xLeft, xMid, xRight, xInt;
	u32 yMid, yInt;
	double xInc, yInc;

	switch (pattern)
	{
	case DEMO_PATTERN_GREEN:
		wRed = 0; wBlue = 0; wGreen= 255; wAlpha = 255;
		for(xcoi = 0; xcoi < (width*4); xcoi+=4)
		{
			iPixelAddr = xcoi;
			for(ycoi = 0; ycoi < height; ycoi++)
			{
				//TODO square with pixel format... gets reordered straight out of DMA then furth futcked
				frame[iPixelAddr] = wBlue;
				frame[iPixelAddr + 1] = wGreen;
				frame[iPixelAddr + 2] = wRed;
				frame[iPixelAddr + 3] = wAlpha;
				//
				// * This pattern is printed one vertical line at a time, so the address must be incremented
				// * by the stride instead of just 1.
				//
				iPixelAddr += stride;
			}
		}
		break;
	case DEMO_PATTERN_RED:
		wRed = 255; wBlue = 0; wGreen= 0; wAlpha = 255;
		for(xcoi = 0; xcoi < (width*4); xcoi+=4)
		{
			iPixelAddr = xcoi;
			for(ycoi = 0; ycoi < height; ycoi++)
			{
				//TODO square with pixel format... gets reordered straight out of DMA then furth futcked
				frame[iPixelAddr] = wBlue;
				frame[iPixelAddr + 1] = wGreen;
				frame[iPixelAddr + 2] = wRed;
				frame[iPixelAddr + 3] = wAlpha;
				//
				// * This pattern is printed one vertical line at a time, so the address must be incremented
				// * by the stride instead of just 1.
				//
				iPixelAddr += stride;
			}
		}
		break;
	case DEMO_PATTERN_BLANK:
		for(xcoi = 0; xcoi < (width*4); xcoi+=4)
		{
			iPixelAddr = xcoi;
			for(ycoi = 0; ycoi < height; ycoi++)
			{

				frame[iPixelAddr] = 0;
				frame[iPixelAddr + 1] = 0;
				frame[iPixelAddr + 2] = 0;
				//
				// * This pattern is printed one vertical line at a time, so the address must be incremented
				// * by the stride instead of just 1.
				//
				iPixelAddr += stride;
			}
		}
		break;
	case DEMO_PATTERN_0:

		xInt = width / 4; //Four intervals, each with width/4 pixels
		xLeft = xInt * 3;
		xMid = xInt * 2 * 3;
		xRight = xInt * 3 * 3;
		xInc = 256.0 / ((double) xInt); //256 color intensities are cycled through per interval (overflow must be caught when color=256.0)

		yInt = height / 2; //Two intervals, each with width/2 lines
		yMid = yInt;
		yInc = 256.0 / ((double) yInt); //256 color intensities are cycled through per interval (overflow must be caught when color=256.0)

		fBlue = 0.0;
		fRed = 256.0;
		for(xcoi = 0; xcoi < (width*4); xcoi+=4)
		{
			//
			// * Convert color intensities to integers < 256, and trim values >=256
			//
			wRed = (fRed >= 256.0) ? 255 : ((u8) fRed);
			wBlue = (fBlue >= 256.0) ? 255 : ((u8) fBlue);
			iPixelAddr = xcoi;
			fGreen = 0.0;
			for(ycoi = 0; ycoi < height; ycoi++)
			{

				wGreen = (fGreen >= 256.0) ? 255 : ((u8) fGreen);
				frame[iPixelAddr] = wRed;
				frame[iPixelAddr + 1] = wBlue;
				frame[iPixelAddr + 2] = wGreen;
				if (ycoi < yMid)
				{
					fGreen += yInc;
				}
				else
				{
					fGreen -= yInc;
				}

				//
				// * This pattern is printed one vertical line at a time, so the address must be incremented
				// * by the stride instead of just 1.
				//
				iPixelAddr += stride;
			}

			if (xcoi < xLeft)
			{
				fBlue = 0.0;
				fRed -= xInc;
			}
			else if (xcoi < xMid)
			{
				fBlue += xInc;
				fRed += xInc;
			}
			else if (xcoi < xRight)
			{
				fBlue -= xInc;
				fRed -= xInc;
			}
			else
			{
				fBlue += xInc;
				fRed = 0;
			}
		}
		//
		// * Flush the framebuffer memory range to ensure changes are written to the
		// * actual memory, and therefore accessible by the VDMA.
		//
		//Xil_DCacheFlushRange((unsigned int) frame, DEMO_MAX_FRAME);
		break;
	case DEMO_PATTERN_D:

			xInt = width / 4; //Four intervals, each with width/4 pixels
			xLeft = xInt * 3;
			xMid = xInt * 2 * 3;
			xRight = xInt * 3 * 3;
			xInc = 128.0 / ((double) xInt); //256 color intensities are cycled through per interval (overflow must be caught when color=256.0)

			yInt = height / 2; //Two intervals, each with width/2 lines
			yMid = yInt;
			yInc = 128.0 / ((double) yInt); //256 color intensities are cycled through per interval (overflow must be caught when color=256.0)

			fBlue = 0.0;
			fRed = 128.0;
			for(xcoi = 0; xcoi < (width*4); xcoi+=4)
			{
				//
				// * Convert color intensities to integers < 256, and trim values >=256
				//
				wRed = (fRed >= 256.0) ? 255 : ((u8) fRed);
				wBlue = (fBlue >= 256.0) ? 255 : ((u8) fBlue);
				iPixelAddr = xcoi;
				fGreen = 0.0;
				for(ycoi = 0; ycoi < height; ycoi++)
				{

					wGreen = (fGreen >= 256.0) ? 255 : ((u8) fGreen);
					frame[iPixelAddr] = wRed;
					frame[iPixelAddr + 1] = wBlue;
					frame[iPixelAddr + 2] = wGreen;
					if (ycoi < yMid)
					{
						fGreen += yInc;
					}
					else
					{
						fGreen -= yInc;
					}

					//
					// * This pattern is printed one vertical line at a time, so the address must be incremented
					// * by the stride instead of just 1.
					//
					iPixelAddr += stride;
				}

				if (xcoi < xLeft)
				{
					fBlue = 0.0;
					fRed -= xInc;
				}
				else if (xcoi < xMid)
				{
					fBlue += xInc;
					fRed += xInc;
				}
				else if (xcoi < xRight)
				{
					fBlue -= xInc;
					fRed -= xInc;
				}
				else
				{
					fBlue += xInc;
					fRed = 0;
				}
			}
			//
			// * Flush the framebuffer memory range to ensure changes are written to the
			// * actual memory, and therefore accessible by the VDMA.
			//
			//Xil_DCacheFlushRange((unsigned int) frame, DEMO_MAX_FRAME);
			break;
	case DEMO_PATTERN_1:

		xInt = width / 7; //Seven intervals, each with width/7 pixels
		xInc = 256.0 / ((double) xInt); //256 color intensities per interval. Notice that overflow is handled for this pattern.

		fColor = 0.0;
		wCurrentInt = 1;
		for(xcoi = 0; xcoi < (width*4); xcoi+=4)
		{

			//
			// * Just draw white in the last partial interval (when width is not divisible by 7)
			//
			if (wCurrentInt > 7)
			{
				wRed = 255;
				wBlue = 255;
				wGreen = 255;
			}
			else
			{
				if (wCurrentInt & 0b001)
					wRed = (u8) fColor;
				else
					wRed = 0;

				if (wCurrentInt & 0b010)
					wBlue = (u8) fColor;
				else
					wBlue = 0;

				if (wCurrentInt & 0b100)
					wGreen = (u8) fColor;
				else
					wGreen = 0;
			}

			iPixelAddr = xcoi;

			for(ycoi = 0; ycoi < height; ycoi++)
			{
				frame[iPixelAddr] = wRed;
				frame[iPixelAddr + 1] = wBlue;
				frame[iPixelAddr + 2] = wGreen;
				//
				// * This pattern is printed one vertical line at a time, so the address must be incremented
				// * by the stride instead of just 1.
				//
				iPixelAddr += stride;
			}

			fColor += xInc;
			if (fColor >= 256.0)
			{
				fColor = 0.0;
				wCurrentInt++;
			}
		}
		//
		// * Flush the framebuffer memory range to ensure changes are written to the
		// * actual memory, and therefore accessible by the VDMA.
		//
		//GG Xil_DCacheFlushRange((unsigned int) frame, DEMO_MAX_FRAME);
		break;
	default :
		xil_printf("Error: invalid pattern passed to DemoPrintTest");
	}
}


