% OpenEMS FDTD Analysis Automation Script
%
% To be run with GNU Octave or MATLAB.
% FreeCAD to OpenEMS plugin by Lubomir Jagos, 
% see https://github.com/LubomirJagos/FreeCAD-OpenEMS-Export
%
% This file has been automatically generated. Manual changes may be overwritten.
%

close all
clear
clc

%% Change the current folder to the folder of this m-file.
if(~isdeployed)
  mfile_name          = mfilename('fullpath');
  [pathstr,name,ext]  = fileparts(mfile_name);
  cd(pathstr);
end

%% constants
physical_constants;
unit    = 0.001; % Model coordinates and lengths will be specified in mm.
fc_unit = 0.001; % STL files are exported in FreeCAD standard units (mm).

%% switches & options
postprocessing_only = 0;
draw_3d_pattern = 0; % this may take a while...
use_pml = 0;         % use pml boundaries instead of mur

currDir = strrep(pwd(), '\', '\\');
display(currDir);

% --no-simulation : dry run to view geometry, validate settings, no FDTD computations
% --debug-PEC     : generated PEC skeleton (use ParaView to inspect)
openEMS_opts = '';

%% prepare simulation folder
Sim_Path = 'simulation_output';
Sim_CSX = '3xHDMI-openEMS-TopyIn1-simple.xml';
[status, message, messageid] = rmdir( Sim_Path, 's' ); % clear previous directory
[status, message, messageid] = mkdir( Sim_Path ); % create empty simulation folder

%% setup FDTD parameter & excitation function
max_timesteps = 20000;
min_decrement = 0.01; % 10*log10(min_decrement) dB  (i.e. 1E-5 means -50 dB)
FDTD = InitFDTD( 'NrTS', max_timesteps, 'EndCriteria', min_decrement);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% BOUNDARY CONDITIONS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
BC = {"MUR","MUR","MUR","MUR","MUR","MUR"};
FDTD = SetBoundaryCond( FDTD, BC );

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% COORDINATE SYSTEM
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
CSX = InitCSX('CoordSystem', 0); % Cartesian coordinate system.
mesh.x = []; % mesh variable initialization (Note: x y z implies type Cartesian).
mesh.y = [];
mesh.z = [];
CSX = DefineRectGrid(CSX, unit, mesh); % First call with empty mesh to set deltaUnit attribute.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% EXCITATION step
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
FDTD = SetStepExcite(FDTD);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% MATERIALS AND GEOMETRY
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
CSX = AddMetal( CSX, 'PEC' );

%% MATERIAL - PEC
CSX = AddMetal(CSX, 'PEC');
CSX = ImportSTL(CSX, 'PEC', 9800, [currDir '/copper_gen_model.stl'], 'Transform', {'Scale', fc_unit/unit});

%% MATERIAL - air
CSX = AddMaterial(CSX, 'air');
CSX = SetMaterialProperty(CSX, 'air', 'Epsilon', 1, 'Mue', 1);
CSX = ImportSTL(CSX, 'air', 9600, [currDir '/air_gen_model.stl'], 'Transform', {'Scale', fc_unit/unit});

%% MATERIAL - fr4
CSX = AddMaterial(CSX, 'fr4');
CSX = SetMaterialProperty(CSX, 'fr4', 'Epsilon', 4.2, 'Mue', 1);
CSX = ImportSTL(CSX, 'fr4', 9700, [currDir '/fr4_gen_model.stl'], 'Transform', {'Scale', fc_unit/unit});

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% GRID LINES
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% GRID - xyz - air (Fixed Distance)
mesh.x(mesh.x >= 146 & mesh.x <= 256) = [];
mesh.x = [ mesh.x (146:0.05:256) ];
mesh.y(mesh.y >= -113 & mesh.y <= -73) = [];
mesh.y = [ mesh.y (-113:0.05:-73) ];
mesh.z(mesh.z >= -5 & mesh.z <= 5) = [];
mesh.z = [ mesh.z (-5:0.05:5) ];
CSX = DefineRectGrid(CSX, unit, mesh);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% PORTS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
portNamesAndNumbersList = containers.Map();

%% PORT - portPin - portPin
portStart = [ 182.8, -78.1, 1.6 ];
portStop  = [ 185.3, -77.6, 1.6315 ];
portR = 50;
portUnits = 1;
portExcitationAmplitude = 2200.0;
portDirection = [1 0 0]*portExcitationAmplitude;
[CSX port{1}] = AddLumpedPort(CSX, 9900, 1, portR*portUnits, portStart, portStop, portDirection, true);
portNamesAndNumbersList("portPin") = 1;


%% PORT - portPout - portPout
portStart = [ 196.9, -99.9, 1.6 ];
portStop  = [ 198.1, -99.4, 1.6315 ];
portR = 50;
portUnits = 1;
portExcitationAmplitude = 0.0;
portDirection = [1 0 0]*portExcitationAmplitude;
[CSX port{2}] = AddLumpedPort(CSX, 10000, 2, portR*portUnits, portStart, portStop, portDirection);
portNamesAndNumbersList("portPout") = 2;


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% PROBES
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% PROBE - ef - efield
dumpboxType = 0;
CSX = AddDump(CSX, 'ef_efield', 'DumpType', dumpboxType);
dumpboxStart = [ 146, -113, 1.5 ];
dumpboxStop  = [ 256, -73, 1.55 ];
CSX = AddBox(CSX, 'ef_efield', 0, dumpboxStart, dumpboxStop );


%% PROBE - hf - hfield
dumpboxType = 1;
CSX = AddDump(CSX, 'hf_hfield', 'DumpType', dumpboxType);
dumpboxStart = [ 146, -113, 1.4 ];
dumpboxStop  = [ 256, -73, 1.45 ];
CSX = AddBox(CSX, 'hf_hfield', 0, dumpboxStart, dumpboxStop );


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% RUN
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
WriteOpenEMS( [Sim_Path '/' Sim_CSX], FDTD, CSX );
CSXGeomPlot( [Sim_Path '/' Sim_CSX] );

if (postprocessing_only==0)
    %% run openEMS
    RunOpenEMS( Sim_Path, Sim_CSX, openEMS_opts );
end
