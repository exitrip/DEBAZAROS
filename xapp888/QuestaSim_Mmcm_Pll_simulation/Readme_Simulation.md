*************************************************************************
```
   ____  ____
  /   /\/   /
 /___/  \  /
 \   \   \/    Copyright 2019 Xilinx, Inc. All rights reserved.
  \   \        This file contains confidential and proprietary
  /   /        information of Xilinx, Inc. and is protected under U.S.
 /___/   /\    and international copyright and other intellectual
 \   \  /  \   property laws.
  \___\/\___\
```
*************************************************************************
```
Vendor:                 Xilinx
Current:                ReadMe.txt (For simulation)
Version:                1.01
Date Last Modified:     26-Jun-2019
Date Created:           09-Oct-2018
Associated Filename:    xapp888.zip
Associated Document:    XAPP888.
Supported Device(s):    7-Series, UltraScale, Ultrascale+ and Ultrascale+Zync FPGAs
```
*************************************************************************
Disclaimer:
```
      This disclaimer is not a license and does not grant any rights to
      the materials distributed herewith. Except as otherwise provided in
      a valid license issued to you by Xilinx, and to the maximum extent
      permitted by applicable law: (1) THESE MATERIALS ARE MADE AVAILABLE
      "AS IS" AND WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL
      WARRANTIES AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY,
      INCLUDING BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY,
      NON-INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
      (2) Xilinx shall not be liable (whether in contract or tort,
      including negligence, or under any other theory of liability) for
      any loss or damage of any kind or nature related to, arising under
      or in connection with these materials, including for any direct, or
      any indirect, special, incidental, or consequential loss or damage
      (including loss of data, profits, goodwill, or any type of loss or
      damage suffered as a result of any action brought by a third party)
      even if such damage or loss was reasonably foreseeable or Xilinx
      had been advised of the possibility of the same.
```
Critical Applications:
```
      Xilinx products are not designed or intended to be fail-safe, or
      for use in any application requiring fail-safe performance, such as
      life-support or safety devices or systems, Class III medical
      devices, nuclear facilities, applications related to the deployment
      of airbags, or any other applications that could lead to death,
      personal injury, or severe property or environmental damage
      (individually and collectively, "Critical Applications"). Customer
      assumes the sole risk and liability of any use of Xilinx products
      in Critical Applications, subject only to applicable laws and
      regulations governing limitations on product liability.
```
THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS PART OF THIS FILE AT ALL TIMES.
*************************************************************************
## Simulation starts here.

## ReadMe files in the design Hierarchy
  *A md file is a Markdown text file.*
  *It can be opened with a normal editor, as if it was a txt file.*
  *Opening it in a markdown reader or in a web browser provides better readable layout.*
**PLEASE**: Read the "...ReadMe...md" files in the different folders.

Simulation directory setup

```
-- /QuestaSim_Mmcm_Pll_Simulation
		Readme_Simulation.md
		/SimScripts
			This directory contains all scripts to run and visualize a simulation for
			one of the MMCM or PLL available.
			!!! instructions how to run the simulation, see below !!!
          	Files in the order they are exectuted by the scripts:
          	transcipt (QuestaSim command, warning and error log file).
          - MmcmPll_TopFuncSim.tcl
          - MmcmPll_FuncSim.do
          	Waveform files, only one is executed depending the entered technology.
          - MmcmPll_FuncWave_7Series_Mmcm.do
          - MmcmPll_FuncWave_7Series_Pll.do
          - MmcmPll_FuncWave_Ultrscl_Mmcm.do
          - MmcmPll_FuncWave_Ultrscl_Pll.do
          - MmcmPll_FuncWave_UltrsclPls_Mmcm.do
          - MmcmPll_FuncWave_UltrsclPls_Pll.do
		/Simulation
			Directory used by the QuestaSim simulator to store compiled
			and synthesized simulation models.
```

Open and read the */SimScripts/Readme_Simulation.md* file, follow the instructions how to
operate the simulation. Simulation is run in Modelsim QuestaSim but operating the simulation
in a different simulator will require the same steps as described in this Readme file.
**REMARK:** The best, most complete and comprehensive simulation of the design is obtained
by implementing a minimal version of the design and control it through a VIO while
gathering visual, waveforms, information in a ILA.

At a glance this design setup:
- One MMCM and PLL directory per available technology.
  - MMCME2_DRP: Reference design for 7-Series MMCM use
  - MMCME3_DRP: Reference design for Ultrascale MMCM use
  - MMCME4_DRP: Reference design for Ultrascale-Plus MMCM use
  - PLLE2_DRP: Reference design for 7-Series PLL use
  - PLLE3_DRP: Reference design for Ultrascale PLL use
  - PLLE4_DRP: Reference design for Ultrascale-Plus PLL use
- QuestaSim_Mmcm_Pll_simulation
  - This directory contains simulation options to simulate the reference
    designs with the Mentor Questa Simulator.
  - See below how to invoke simulation with QuestaSim.
  - REMARK: Each of the directories can be simulated using the VIVADO simulator too.

### Invoke and start Quesasim.

- Open a terminal(Linux) or command window(Windows).
- Change directory to the folder where you found this "Readme_Simulation.md" file.
    Example: *cd C:\Projects\Xapp888\Project\QuestaSim_Mmcm_Pll_simulation*
- Type "*questasim*" for Windows or "*vsim*" when simulating in Linux.
    - Above command starts Mentor QuestaSim tool.
    - In the directory where QuestaSim started a *transcript* file will be created.
    - This is a log file of everything that happens during the time QuestaSim is running. 
      Find in there al used commands, warnings, errors and much more.
      For convenience the directory contains an example transcript file.
      WARNING: that file will be overwritten when a new QuestaSim run is started.
- In QuestaSim do:
    - Click the **[Tools]** tap.
    - Select from the fall down menu: **[Tcl]**
    - Under **[Tcl]** select **[Execute Macro]**
    - Browse to the *SimScripts* directory and select the: **MmcmPll_TopFuncSim.tcl** file.
    - Click **[Open]**

The simulation will start.
Answer the questions in the Questasim transcript window, asking questions about FPGA family and MMCM or PLL simulation. After a while the waveform window will pop up.
The simulation will run a in the **MmcmPll_TopFuncSim.tcl** file predefined number
of cycles. type in the transcript window 'run xxxxxx' to run extra cycles.
The waveform window will now show waveform actions.

### REMARK_0:
- If a simulation contains verilog coded files, then: to get simulation working a special
  file must be included in the compiler file list of the **<ProjectName>_FuncSim.do**.
- This line must contain the compilation for simulation of the global 3-state and reset
  nets in a design (glbl.v)
- Depending the installation of the Xilinx Vivado tools it might be necessary to change
  this setting in the **<ProjectName>_FuncSim.do** file.
- Default the line is entered in the **<ProjectName>_FuncSim.do** file using a hard coded
  path pointing to the installation of the Xilinx Vivado tool chain.
  ```
  vlog -work work {<drive>:/Path/ToTools/Xilinx/Vivado/20xx.n/data/verilog/src/glbl.v}
      Where "xx" is the year and n" is the year version number of the Vivado software.
  ```
- On Windows systems the environment variable XILINX_VIVADO is set by the Xilinx Vivado
  tools and points to the installation of the Vivado tool chain. The line in the .do
  file can then look as:

    ```
    vlog -work work $env(XILINX_VIVADO)/data/verilog/src/glbl.v
    ```
- On stand alone Linux systems it is possible that the "XILINX_VIVADO" environment variable
  is set when the Vivado tools are started, but that it's unset when the Vivado tools are
  closed or not running.
- On networked Linux systems where the Vivado software is installed central, it is very likely
  that the environment "XILINX_VIVADO" is not set at all on a user machine or as in previous
  point the environment variable is set when the Vivado tools are started/running.
- In both above cases it might be a good solution to find out where and what Vivado tools
  are used and then leave a hard coded path to the "glbl.v" library.

### REMARK_1:
- Questasim runs default in a 'ns' setup. This simulation allows that a clock is modified
  with a deviation on the normal clock cycle. This deviation is given in 'fs'.
  In order to let the waveform window display the deviation of the clock the simulation
  must be run and displayed in 'fs'.
- The **<ProjectName>_FuncSim.do** file runs the simulation in 'fs' using this command line:
  ```
  vsim -t fs -L unisims_ver -L secureip xil_defaultlib...
  ```
- To make Questasim display the waveforms in fs, the timing needs to be changed in the
  **modelsim.ini** file.

  - Change under the header **[vsim]** the **resolution** from ns to fs.

### REMARK_2:

- It necessary that the Xilinx simulation libraries are synthesized for QuestaSim_10.7d
- To synthesize simulation libraries do:
  - Create a folder for hosting the compiled Xilinx libraries.
    - Example:
    ```
      /<Folder/Where/CompiledSimulation/Libraries/Stored>/XilinxQuestaLibraries
    ```
    - Open a terminal(Linux)/command window(Windows).
    - Change directory (cd) to the earlier created folder.
    - Start Vivado (Type: vivado or vivado &).
    - In the GUI select the **[Tools]** tab and from the fall down menu
      select **[Compile Simulation Libraries...]**.
    - In the new pop-up menu select:
      - Simulator: QuestaSim
      - Language: All, VHDL or Verilog
          ​      For mixed designs leave: All
      - Library: All, Simprim, Unisim
          ​      Leave it to 'All' when behavioural and timing simulation must be done.
      - Family: All or select <A Family>
          ​      Leave it to all when this is the master library folder for used for
          ​      all design simulations.
      - Compiled Library Location:
          The folder created to contain the simulation libraries/models.
          <Path_To_Folder_Where_all_Projects_Are>/XilinxQuestaLibraries
      - Simulator Executable Path:
          Find the path to the QuestaSim executable.
          Example:  ../../QuestaSim64_10_6b/win64
      - Click [Compile]
          All or selected libraries for all or selected FPGA families will be compiled and
          stored in the given folder. There is a "modelsim.ini" file generated and stored
          in that folder. Several options are open to make use of this 'local' modelsim.ini
          file.
- Option_1:
  - Open the modelsim.ini file (make it writable first) in the installation
    folder of QuestaSim.
  - Add following lines:
  ```
    ; Xilinx Libraries       <-- comments
    others = ../XilinxLibraries/modelsim.ini  <-- Path to the local ini file.
  ```
- Option_2:
  - Create an environment: MODELSIM
  - Like this:
  ```
      MODELSIM=/Folder/Where/CustomSimulation/Libraries/AreStored/QuestaSimLibs/modelsim.ini
  ```
  - Starting Questasim will now look into this folder and add the libraries to
    the loaded simulation libraries.

### REMARK_3:

- Whenever changes are done to any of the VHDL files, the syntheses run for simulation
  must be redone.
- Do this as:
    - Type in the command line of the transcript window following commands.
      ```
      quit -sim : This will close a running simulation
      ```
- With the up and down arrows it's possible to browse through earlier executed command.
- Find the "do" command and run it again.
    ```
    do <Path_to_the_>/Simscripts/Byte_Top_RxTx_Prbs_Nat_FuncSim.do
    ```
- To run the simulation longer or shorted as the "run" command in the .do file, type:
    ```
    run <value>
    ```
### REMARK_4:
- The QuestaSim transcript log file will be written into this /SimScripts folder.
- The transcripts folder allows you to find all simulation commands, warnings
   and errors that have also been displayed in the GUI transcript window.


Kind regards,

XILINX
