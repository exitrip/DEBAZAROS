% Plot S11
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

Sim_Path = 'simulation_output';
currDir = strrep(pwd(), '\', '\\');
display(currDir);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% COORDINATE SYSTEM
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
CSX = InitCSX('CoordSystem', 0); % Cartesian coordinate system.
mesh.x = []; % mesh variable initialization (Note: x y z implies type Cartesian).
mesh.y = [];
mesh.z = [];
CSX = DefineRectGrid(CSX, unit, mesh); % First call with empty mesh to set deltaUnit attribute.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% EXCITATION sinpos_fund
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
f0 = 72.0*1000000.0;
fc = 0;
max_res = c0 / f0 / 20;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% MATERIALS AND GEOMETRY
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
CSX = AddMetal( CSX, 'PEC' );

%% MATERIAL - PEC
CSX = AddMetal(CSX, 'PEC');

%% MATERIAL - air
CSX = AddMaterial(CSX, 'air');
CSX = SetMaterialProperty(CSX, 'air', 'Epsilon', 1, 'Mue', 1);

%% MATERIAL - fr4
CSX = AddMaterial(CSX, 'fr4');
CSX = SetMaterialProperty(CSX, 'fr4', 'Epsilon', 4.2, 'Mue', 1);

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
portR = 50.0;
portUnits = 1;
portExcitationAmplitude = 2200.0;
portDirection = [1 0 0]*portExcitationAmplitude;
[CSX port{1}] = AddLumpedPort(CSX, 9900, 1, portR*portUnits, portStart, portStop, portDirection, true);
portNamesAndNumbersList("portPin") = 1;


%% PORT - portPout - portPout
portStart = [ 196.9, -99.9, 1.6 ];
portStop  = [ 198.1, -99.4, 1.6315 ];
portR = 50.0;
portUnits = 1;
portExcitationAmplitude = 0.0;
portDirection = [1 0 0]*portExcitationAmplitude;
[CSX port{2}] = AddLumpedPort(CSX, 10000, 2, portR*portUnits, portStart, portStop, portDirection);
portNamesAndNumbersList("portPout") = 2;


%% postprocessing & do the plots
freq = linspace( max([0,f0-fc]), f0+fc, 501 );

port = calcPort(port, Sim_Path, freq);
s11 = port{1}.uf.ref ./ port{1}.uf.inc;
s11_dB = 20*log10(abs(s11));
Zin = port{1}.uf.tot ./ port{1}.if.tot;

% plot feed point impedance
figure
plotObj1 = plot( freq/1e6, real(Zin), 'k-', 'Linewidth', 2 );
hold on
grid on
plot( freq/1e6, imag(Zin), 'r--', 'Linewidth', 2 );
title( 'feed point impedance' );
xlabel( 'frequency f / MHz' );
ylabel( 'impedance Z_{in} / Ohm' );
legend( 'real', 'imag' );

figure
plotObj2 = plot( freq/1e6, 20*log10(abs(s11)), 'k-', 'Linewidth', 2 );
grid on
title( 'reflection coefficient S_{11}' );
xlabel( 'frequency f / MHz' );
ylabel( 'reflection coefficient |S_{11}|' );

% wait for plot windows to be closed
waitfor(plotObj1);
waitfor(plotObj2);

%
%   Write S11, real and imag Z_in into CSV file separated by ';'
%
filename = 'openEMS_simulation_s11_dB.csv';
fid = fopen(filename, 'w');
fprintf(fid, 'freq (MHz);s11 (dB);Z real (Ohm);Z imag (Ohm);Z abs (Ohm)\n');
fclose(fid)
s11_dB = horzcat((freq/1e6)', s11_dB', real(Zin)', imag(Zin)', abs(Zin)');
dlmwrite(filename, s11_dB, '-append', 'delimiter', ';');
