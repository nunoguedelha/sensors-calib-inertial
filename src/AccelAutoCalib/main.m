%% Comparing the eccentrity of several "grid" dataset measured on the iCub Robot
% This script take dataset in the "grid" format (generated by
% reachRandomJointPositions [1] module) on the iCub robot and compare 
% the eccentrity of the force measurement. In theory the "grid" movement
% is slowly (so the only thing that matters is gravity) moving the legs,
% while the robot is fixed on the pole (so the only external force are 
% on the root_link). In theory then the measured force should be equal 
% to m*g , where g \in R^3 is the gravity expressed in the sensor frame. 
% Hence the measured force should lie on a sphere (eccentrities 0,0) in
% theory. However imperfect sensor can have a different eccentricities (
% but in general they remain linear, so the sphere become an ellipsoid).
% For more on the theory behind this script, check [2].
% [1] : https://github.com/robotology/codyco-modules/tree/master/src/misc/reachRandomJointPositions
% [2] : Traversaro, Silvio, Daniele Pucci, and Francesco Nori. 
%       "In situ calibration of six-axis force-torque sensors using accelerometer measurements."
%       Robotics and Automation (ICRA), 2015 IEEE International Conference on. IEEE, 2015.

%% clear all variables and close all previous figures
clear
close all
clc

%% Main interface parameters ==============================================

run mainInit.m

%%=========================================================================

%% set init parameters 'ModelParams'
%
run sensorsSelections;
ModelParams = jointsNsensorsDefinitions(parts,struct([]),struct([]),mtbSensorAct);

%% build input data for calibration
%

[data,sensorsIdxListFile,sensMeasCell] = buildInputDataSet(...
    loadSource,saveToCache,false,...
    dataPath,dataSetNb,...
    subSamplingSize,timeStart,timeStop,...
    ModelParams);

%% ========================================== CALIBRATION ==========================================
%
%                          ellipsoid fitting and distance to ellipsoid
%

ellipsoid_p = cell(1,length(sensorsIdxListFile)); % implicit parameters
calib = cell(1,length(sensorsIdxListFile)); % explicit parameters
ellipsoid_e = cell(1,length(sensorsIdxListFile)); % least squares error
ellipsoid_d = cell(1,length(sensorsIdxListFile)); % distance to surface

for acc_i = sensorsIdxListFile
    [ellipsoid_p{acc_i},ellipsoid_e{acc_i},ellipsoid_d{acc_i}] = ellipsoidfit( ...
        sensMeasCell{1,acc_i}(:,1), ...
        sensMeasCell{1,acc_i}(:,2), ...
        sensMeasCell{1,acc_i}(:,3));
    [calib{acc_i}.centre,radii,calib{acc_i}.quat,calib{acc_i}.R] = ...
        ellipsoid_im2ex(ellipsoid_p{1,acc_i}); % convert implicit to explicit
    % convert ellipsoid axis lengths to rates
    calib{acc_i}.radii = radii/9.807;
    % compute full calibration matrix combining elongation and rotation
    calib{acc_i}.C = calib{acc_i}.R'*inv(diag(calib{acc_i}.radii))*calib{acc_i}.R;
    % raw fullscale to m/s^2 conversion
    calib{acc_i}.gain = 5.9855e-04;
end

% Save all for further eventual use
if saveToCache
    save './data/logAll.mat';
end

% Load existing calibration or create new empty one
if exist('./data/calibrationMap.mat','file') == 2
    load('./data/calibrationMap.mat','calibrationMap');
end

if ~exist('calibrationMap','var')
    calibrationMap = containers.Map('KeyType','char','ValueType','any');
end

% Create mapping extension with new calibrated frames
calibratedFrames = data.frames(1,sensorsIdxListFile);
calibMapExt = containers.Map(calibratedFrames,calib);
calibrationMap = [calibrationMap;calibMapExt];

% Save updated calibration
if saveCalib
    save('./data/calibrationMap.mat','calibrationMap');
end


%%========================================== CALIBRATION VISUALISATION ===============================
%

%% clear all variables and close all previous figures
clear
close all
clc

load './data/logAll.mat';

acc_i = 3;

fprintf('Observing fitting on a single accelerometer:\n%d\n',acc_i);

%% Notes:
%  'ellipsoid_distance' uses 'ellipsoidfit_residuals'

%% distance to a centered sphere (R=9.807) before calibration
[pVec,dVec,dOrient,d] = ellipsoid_proj_distance_fromExp(...
                                                        sensMeasCell{1,acc_i}(:,1),...
                                                        sensMeasCell{1,acc_i}(:,2),...
                                                        sensMeasCell{1,acc_i}(:,3),...
                                                        [0 0 0]',[9.807 9.807 9.807]',eye(3,3));
%distr of signed distances
figure('Name','distance to a centered sphere (R=9.807) before calibration');
histogram(dOrient,200,'Normalization','probability');
xlabel('Oriented distance to surface','Fontsize',12);
ylabel('Normalized number of occurence','Fontsize',12);

fprintf(['distribution of distances to a centered sphere\n'...
    'mean:%d\n'...
    'standard deviation:%d\n'],mean(dOrient,1),std(dOrient,1,1));

%% distance to offseted sphere & comparison
[pVec,dVec,dOrient,d] = ellipsoid_proj_distance_fromExp(...
                                                        sensMeasCell{1,acc_i}(:,1),...
                                                        sensMeasCell{1,acc_i}(:,2),...
                                                        sensMeasCell{1,acc_i}(:,3),...
                                                        calib{acc_i}.centre,[9.807 9.807 9.807]',eye(3,3));
%distr of signed distances
figure('Name','distance to the offseted sphere');
histogram(dOrient,200,'Normalization','probability');
xlabel('Oriented distance to surface','Fontsize',12);
ylabel('Normalized number of occurence','Fontsize',12);

fprintf(['distribution of distances to a centered sphere\n'...
    'mean:%d\n'...
    'standard deviation:%d\n'],mean(dOrient,1),std(dOrient,1,1));

%% distance to non rotated ellipsoid & comparison
[pVec,dVec,dOrient,d] = ellipsoid_proj_distance_fromExp(...
                                                        sensMeasCell{1,acc_i}(:,1),...
                                                        sensMeasCell{1,acc_i}(:,2),...
                                                        sensMeasCell{1,acc_i}(:,3),...
                                                        calib{acc_i}.centre,9.807*calib{acc_i}.radii,eye(3,3));
%distr of signed distances
figure('Name','distance to offseted, non rotated ellipsoid');
histogram(dOrient,200,'Normalization','probability');
xlabel('Oriented distance to surface','Fontsize',12);
ylabel('Normalized number of occurence','Fontsize',12);

fprintf(['distribution of distances to a centered sphere\n'...
    'mean:%d\n'...
    'standard deviation:%d\n'],mean(dOrient,1),std(dOrient,1,1));

%% distance to rotated final ellipsoid & comparison
[pVec,dVec,dOrient,d] = ellipsoid_proj_distance_fromExp(...
                                                        sensMeasCell{1,acc_i}(:,1),...
                                                        sensMeasCell{1,acc_i}(:,2),...
                                                        sensMeasCell{1,acc_i}(:,3),...
                                                        calib{acc_i}.centre,9.807*calib{acc_i}.radii,calib{acc_i}.R);
%distr of signed distances
figure('Name','distance to offseted, rotated final ellipsoid');
histogram(dOrient,200,'Normalization','probability');
xlabel('Oriented distance to surface','Fontsize',12);
ylabel('Normalized number of occurence','Fontsize',12);

fprintf(['distribution of distances to a centered sphere\n'...
    'mean:%d\n'...
    'standard deviation:%d\n'],mean(dOrient,1),std(dOrient,1,1));

%% plot fitting
[centre,radii,quat,R]=ellipsoid_im2ex(ellipsoid_p{1,acc_i}); % convert implicit to explicit
[xx,yy,zz]=ellipsoid(centre(1),centre(2),centre(3),radii(1),radii(2),radii(3),100); % generate ellipse points without rotation
vec=[xx(:),yy(:),zz(:)]; % xx(i,j),yy(i,j),zz(i,j) is a point on the ellipse. a row of zz is an iso-z
vec=vec-repmat(centre',[size(xx(:)),1]); % remove offset before rotating
% R is the rotation transform from the original frame to the frame aligned
% with the ellipsoid axis.
vecRotated=(R'*vec')'+repmat(centre',[size(xx(:)),1]); % rotate ellipse and add the offset again
% Plot
figure('Name', 'Fitting ellipsoid for MTB sensor');
title(['Fitting ellipsoid for MTB sensor ' acc_i]','Fontsize',16,'FontWeight','bold');
surf(reshape(vecRotated(:,1),101,101),reshape(vecRotated(:,2),101,101),reshape(vecRotated(:,3),101,101)); % plot
axis equal;
grid off;
xlabel('x','Fontsize',12);
ylabel('y','Fontsize',12);
zlabel('z','Fontsize',12);

figure('Name', 'Fitting ellipsoid for MTB sensor (plot from quadfit)');
hold on;
plot_ellipsoid(centre(1),centre(2),centre(3),radii(1),radii(2),radii(3),R,'AxesColor','black');
scatter3(sensMeasCell{1,acc_i}(:,1),sensMeasCell{1,acc_i}(:,2),sensMeasCell{1,acc_i}(:,3));
%title(['Fitting ellipsoid for MTB sensor ' acc_i]','Fontsize',16,'FontWeight','bold');
axis equal;
xlabel('x','Fontsize',12);
ylabel('y','Fontsize',12);
zlabel('z','Fontsize',12);
