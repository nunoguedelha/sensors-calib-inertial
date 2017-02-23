%%
% Init parameters of the accelerometers calibration script
%%

% 'matFile' or 'dumpFile' mode
loadSource = 'dumpFile';
saveToCache = true;
saveCalib = false;

% model and data capture file
modelPath = '../models/iCubGenova05/iCubFull.urdf';
dataPath  = '../../data/calibration/dumper/iCubGenova05_#3/';
dataSetNb = '';

% Start and end point of data samples
timeStart = 1;  % starting time in capture data file (in seconds)
timeStop  = -1; % ending time in capture data file (in seconds). If -1, use 
                % the end time from log
% filtering/subsampling: the main single data bucket of (timeStop-timeStart)/10ms 
% samples is sub-sampled to 'subSamplingSize' samples for running the ellipsoid fitting.
subSamplingSize = 1000;

% define the limb from which we will calibrate all the sensors.
% Activate all the sensors of that limb.
parts = {'left_leg'};