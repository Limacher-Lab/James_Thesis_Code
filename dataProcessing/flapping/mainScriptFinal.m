% Setting up folder and subfolder locations
% One folder for each full sweep conducted
folderPath = ["Space 1\" "Space 2\" "Space 3\"...
    "Space 4\" "Space 5\" "Space 6\" "Space 7\"...
    "Space 8\" "Space 9\"];

% One subfolder for each mean pitch angle tested
% Each frequency for a given mean pitch angle are
% held within these folders
subFolderPath = ["0Mean\" "1Mean\" "2Mean\" "3Mean\"...
    "4Mean\" "5Mean\" "6Mean\" "7Mean\" "8Mean\"...
    "9Mean\" "10Mean\"];

% Setting up variables and containers
S = 0.08; % Planform area of the wing
c = 0.21; % Characteristic chord length for the wing
uncQ = 1.99072; % Manuf. uncertainty for press. sensor
Uinf = 15.43; % Mean freestream velocity during tests

uncOpacity = 0.25; % Opacity of uncertainty bars

cycs = 70; % Number of cycles in every trial
removeStartCyc = 10; % Cycles to remove from data start
removeFinCyc = 5; % Cycles to remove from data end
% Number of cycles kept
keptCycs = cycs-removeStartCyc-removeFinCyc;

torMax = 7.4; % Maximum value of the motor torque

% Load cell slopes for converting from Volt to Newton
        % Back   Front
        % G-1232 K-7801
slopes = [29.574 31.820; % Thrust (N/V)
          30.296 32.028; % Lift (N/V)
          29.356 30.133];

% Load cell slope intercepts
intercepts = [-0.0116 -0.0968; % Thrust (N)
               0.0886 0.2038]; % Lift (N)

% Uncertainty in the slope of the load cell
slopesUnc = [0.0294 0.0388; % Thrust (N/V)
             0.0208 0.0410]; % Lift (N/V)

% Lift & thrust values of wing at reference position
    %Lift    Thrust
f0 = [0.1234 -0.7195]';
% Lift & thrust values of test stand (wind-tunnel on)
fs = [-0.3009 -0.1013]';

% Uncertainty of lift and thrust for f0 and fs above
uncF0 = [0.0118 0.0086];
uncFS = [0.0052 0.0113];

% Uncertainty of short term drift (N)
uncTDrift = 0.2250;
uncLDrift = 0.1093;

% Maximum possible sensor misalignment in degrees
sensorMisalignDeg = 1.7;
misAlignRad = deg2rad(sensorMisalignDeg);

% Empty containers for the coefficients
thrustCoeff = zeros(9,11,9);
liftCoeff = zeros(9,11,9);
powCoeff = zeros(9,11,9);
sideCoeff = zeros(9,11,9); % Unused, here for future
peakX = zeros(9,11,9);
peakY = zeros(9,11,9);
peakZ = zeros(9,11,9);
peakXSin = zeros(9,11,9);
peakYSin = zeros(9,11,9);
peakZSin = zeros(9,11,9);
phsThr = zeros(9,11,9);
phsL = zeros(9,11,9);

% Empty containers for force and pressure
thrust = zeros(9,11,9);
lift = zeros(9,11,9);
q = zeros(9,11,9); % Dynamic pressure

% Empty containers for the voltages measured for each
% axis of each load cell
VFx = zeros(9,11,9);
VFy = zeros(9,11,9);
VBx = zeros(9,11,9);
VBy = zeros(9,11,9);

% Empty containers for the power of ind. motors
peakStrokePow = zeros(99*9,1);
peakPitchPow = zeros(99*9,1);

% Mean power lost to friction in the apparatus
powLoss = [1.0462 1.4875 1.962 2.296 2.810 3.268...
    3.598 4.647 5.312];
powLossUnc = 1.5;

% Loop to process data
for spaceNum=1:numel(folderPath)
    % Creating strings for the filepaths to analyze
    path = folderPath(spaceNum)+subFolderPath;

    % Looping through the mean pitch angles
    for folNum=1:numel(path)
        % Creating lists of data files in folder
        motorFiles =... % Motor pos, vel, tor data
            dir(fullfile(path(folNum),'*.csv'));
        forceFiles =... % Force and pressure data
            dir(fullfile(path(folNum),'*.mat'));
        driftFiles =... % Force & press. at reference
            dir(fullfile(path(folNum),'*.mat'));
        
        % Which file names should be kept
        forceFilesKeep =...
        ~contains({forceFiles.name}, ["Bias","Drift"]);
        driftFilesKeep =...
        contains({driftFiles.name}, "Drift");
        
        % Removing files that don't belong in the
        % individual containers
        forceFiles = forceFiles(forceFilesKeep);
        driftFiles = driftFiles(driftFilesKeep);
        
        % Converting data to tables for ease
        motorFiles = struct2table(motorFiles);
        forceFiles = struct2table(forceFiles);
        driftFiles = struct2table(driftFiles);
        
        % Creating empty containers for the analysis
        pitchPos = cell(length(motorFiles.name)/2,1);
        pitchVel = cell(length(motorFiles.name)/2,1);
        pitchTor = cell(length(motorFiles.name)/2,1);
        strokePos = cell(length(motorFiles.name)/2,1);
        strokeVel = cell(length(motorFiles.name)/2,1);
        strokeTor = cell(length(motorFiles.name)/2,1);
        forces = cell(length(forceFiles.name),1);
        driftCorr = zeros(length(forceFiles.name),3);
        pitchCosPar =...
            zeros(length(motorFiles.name)/2,4);
        strokeCosPar =...
            zeros(length(motorFiles.name)/2,4);        
        meanThrustC = zeros(1,length(forceFiles.name));
        meanLiftC = zeros(1,length(forceFiles.name));
        meanSideC = zeros(1,length(forceFiles.name));
        meanCP = zeros(1,length(forceFiles.name));
        meanThrust = zeros(1,length(forceFiles.name));
        meanLift = zeros(1,length(forceFiles.name));
        meanQ = zeros(1,length(forceFiles.name));
        meanVFx = zeros(1,length(forceFiles.name));
        meanVFy = zeros(1,length(forceFiles.name));
        meanVBx = zeros(1,length(forceFiles.name));
        meanVBy = zeros(1,length(forceFiles.name));    
        phaseForce = cell(length(forceFiles.name),1);
        phasePower = cell(length(forceFiles.name),1);        
        tempForceData = [];

        % Looping through the frequencies tested
        for i=1:length(motorFiles.name)/2
            % Loading the file
            tempForceData =...
                load(...
                    fullfile( ...
                        path(folNum),...
                        forceFiles.name(i)...
                    )...
                ); 
            tempDriftData =...
                load(...
                    fullfile(...
                        path(folNum),...
                        driftFiles.name(i)...
                    ) ...
                );

            % Using custom function to convert voltage
            % to Force for the reference
            % position measurement
            tempDrift =...
                convertForce( ...
                    tempDriftData,...
                    slopes,...
                    intercepts,...
                    []...
                );


            % Calculataing the drift correction as the
            % mean of the 30s of data collected at the
            % reference position directly before the
            % flapping trial
            driftCorr(i,1) = mean(tempDrift.Lift);
            driftCorr(i,2) = mean(tempDrift.Thrust);
            driftCorr(i,3) = mean(tempDrift.Side);

            % Using custom function
            % Converts Voltage to Force for the
            % flapping trial (in relative frame, the
            % function removes the calculated drift
            % corrections given)
            forces{i} = convertForce(...
                            tempForceData,...
                            slopes,...
                            intercepts,...
                            driftCorr(i,:)...
                        );
            % Converting voltage to dynamic pressure
            % For the flapping trial
            dynPres = mean(...
                tempForceData.pressureBiased)*49.768;
        
            % Loading motor data for the pitch motor
            tempMotorData1 =...
                load(...
                    fullfile(...
                        path(folNum),...
                        motorFiles.name(i*2-1)...
                    ) ...
                );

            % Custom fuction to fit motor position data
            % to a cosine function and return pos, vel,
            % tor data, and the minimum number of data
            % points collected
            [pitchCosPar(i,:),pitchPos{i},...
                pitchVel{i},pitchTor{i},...
                pitchMinData] =...
                    cosRegressApp(...
                        tempMotorData1,...
                        "pitch"...
                    );
             
            % Loading data for stroke motor
            tempMotorData2 =...
                load(...
                    fullfile(path(folNum),...
                        motorFiles.name(i*2)...
                    )...
                );
            % Custom fuction to fit motor position data
            % to a cosine function and return pos, vel,
            % tor data, and the minimum number of data
            % points collected
            [strokeCosPar(i,:),strokePos{i},...
                strokeVel{i},strokeTor{i},...
                strokeMinData] =...
                    cosRegressApp(...
                        tempMotorData2,...
                        "stroke"...
                    );
            
            % Find smallest number of power data points
            % collected in testing
            if spaceNum + folNum + i == 3 % First iter.
                minInstPowPoints = ...
                    min([pitchMinData, strokeMinData]);
            else
                minInstPowPoints = ...
                    min(...
                        [minInstPowPoints,...
                        pitchMinData,...
                        strokeMinData]...
                    );
            end
            
            % Pulling the frequency from the fitted
            % function to use in calculattions instead
            % of using the nominal frequency
            freqs = pitchCosPar(:,2);

            % Finding the highest recorded time for the
            % first data point from the motors
            strokeTimeMin = ...
                max(...
                    min(strokeVel{i}.Time),...
                    min(strokeTor{i}.Time)...
                );
            pitchTimeMin = ...
                max(...
                    min(pitchVel{i}.Time),...
                    min(pitchTor{i}.Time)...
                );
            timeMin = max(strokeTimeMin,pitchTimeMin);
            
            % Creating variables containing the pitch
            % velocity and torque for the ith trial
            tempPitchVel = pitchVel{i};
            tempPitchTor = pitchTor{i};
            
            % Removing data that came before the
            % highest recorded start time
            pitchVelRemove = ...
                tempPitchVel.Time >= timeMin;
            pitchTorRemove = ...
                tempPitchTor.Time >= timeMin;
            tempPitchVel(~pitchVelRemove,:) = [];
            tempPitchTor(~pitchTorRemove,:) = [];
            
            % Of the remaining data, find the smallest
            % amount of recorded data
            pitchStop = ...
                min(...
                    length(tempPitchVel.Vel),...
                    length(tempPitchTor.Tor)...
                );
            % Multiply the shared data points between
            % vel and stroke to get power data
            pitchPow = ...
                tempPitchVel.Vel(1:pitchStop).*...
                tempPitchTor.Tor(1:pitchStop);

            % Calculate index to place peak pitch power
            powIdx = ...
                (spaceNum-1)*length(folderPath)+...
                (folNum-1)*length(path)+i;
            % Store peak pitching power
            peakPitchPow(powIdx) = max(pitchPow);
            
            % Do the same thing for stroke power
            tempStrokeVel = strokeVel{i};
            tempStrokeTor = strokeTor{i};
            strokeVelRemove = ...
                tempPitchVel.Time >= timeMin;
            strokeTorRemove = ...
                tempPitchTor.Time >= timeMin;
            tempStrokeVel(~strokeVelRemove,:) = [];
            tempStrokeTor(~strokeTorRemove,:) = [];
            strokeStop = ...
                min(...
                    length(tempStrokeVel.Vel),...
                    length(tempStrokeTor.Tor)...
                );
            strokePow = ...
                tempStrokeVel.Vel(1:strokeStop).*...
                tempStrokeTor.Tor(1:strokeStop);            
            peakStrokePow(powIdx) = max(strokePow);
            
            % Find least amount of data collected 
            % between pitch and stroke motors
            powStop = min(pitchStop,strokeStop);
            
            % Create a container for coefficient of
            % power
            CP = zeros(powStop,2);
            % Crop the time vector to the length of the
            % smallest amount of data collected
            % All motor data was cropped to start at
            % the same time above so any of the four
            % time vectors is fine
            CP(:,1) = pitchVel{i}.Time(1:powStop);
            % Calculate the power for only the shared
            % times
            CP(:,2) = ...
                (...
                    strokePow(1:powStop)+...
                    pitchPow(1:powStop)...
                )/(dynPres*S*Uinf);
    
            % Calculate times for removing startup and
            % ending cycles (set in opening of script)
            startRemoveTime = ...
                removeStartCyc/pitchCosPar(i,2);
            finRemoveTime = ...
                (cycs-removeFinCyc)/pitchCosPar(i,2);
            % Set what indexes to delete based on
            % times calculated and keep all the other
            % indexes
            toDelete = ...
                CP(:,1) <= startRemoveTime |...
                CP(:,1) >= finRemoveTime;
            CPkept = CP(~toDelete,:);

            % Set this new initial time to 0 to match
            % with the cropped forces later
            CPkept(:,1) = CPkept(:,1)-CPkept(1,1);

            % Use custom function to calculate phase
            % average power
            phasePower{i} = ...
                phaseAvgPow(...
                    CPkept,...
                    keptCycs,...
                    pitchCosPar(i,2)...
                );
            % Calculate the mean power coefficient with
            % previously found apparatus losses removed
            meanCP(i) = ...
                mean(CPkept(:,2))-powLoss(i)/...
                (dynPres*S*Uinf);
    
            % Find the indexes to remove based on times
            % calculated in power calculations and keep
            % the data not at these indexes and set new
            % first data points as time 0
            toDelete = ...
                forces{i}.Time <= startRemoveTime |...
                forces{i}.Time >= finRemoveTime;
            forces{i}.Time = forces{i}.Time(~toDelete);
            forces{i}.Time = ...
                forces{i}.Time-forces{i}.Time(1);
            % Return forces from relative frame to
            % absolute frame using data collected about
            % reference position forces (f0), and stand
            % forces (fs)
            forces{i}.Thrust = ...
               forces{i}.Thrust(~toDelete)+f0(2)-fs(2);
            forces{i}.Lift = ...
                forces{i}.Lift(~toDelete)+f0(1)-fs(1);
            % Not used
            forces{i}.Side = forces{i}.Side(~toDelete);
            
            % Calculate the coefficients (inst.)
            coeffs = forces{i};
            coeffs.Lift = coeffs.Lift/(dynPres*S);
            coeffs.Thrust = coeffs.Thrust/(dynPres*S);
            % Custom function to calculate phase
            % average forces
            phaseForce{i} = ...
                phaseAvgForces(...
                    coeffs,...
                    keptCycs,...
                    pitchCosPar(i,2),...
                    true...
                );
            phsThr(i,folNum,spaceNum) = mean(phaseForce{i}.Thrust);
            phsL(i,folNum,spaceNum) = mean(phaseForce{i}.Lift);
            if folNum==1 && i==8 && spaceNum ==1
                check = forces{i};
                figure()
                hold on
                plot(check.Time,check.Thrust,'DisplayName','Filtered Instantaneous $C_T$','LineWidth',2)
                plot(check.Time,check.Lift,'DisplayName','Filtered Instantaneous $C_L$','LineWidth',2)

                check2 = ...
                phaseAvgForces(...
                    coeffs,...
                    keptCycs,...
                    pitchCosPar(i,2),...
                    false...
                );
                figure()
                hold on
                plot(check2.nonT,check2.Thrust,'DisplayName','Filtered Instantaneous $C_T$','LineWidth',2)
                plot(check2.nonT,check2.Lift,'DisplayName','Filtered Instantaneous $C_L$','LineWidth',2)

                figure()
                hold on
                plot(phaseForce{i}.nonT,phaseForce{i}.Thrust,'DisplayName','Filtered Instantaneous $C_T$','LineWidth',2)
                plot(phaseForce{i}.nonT,phaseForce{i}.Lift,'DisplayName','Filtered Instantaneous $C_L$','LineWidth',2)
                ylabel('$C_n$')
                plot(phasePower{i}.nonT,phasePower{i}.CP,'k','DisplayName','Instantaneous $C_P$','LineWidth',2)
                legend('location','southeast')
                xlabel('$t/\tau$')
                myExportGraphics(gcf,'phaseAvg.eps','C:\Users\James\OneDrive - University of Calgary\Thesis\Ch5\')
                
            end
            % Calculate mean coefficients
            meanThrustC(i) = ...
                mean(forces{i}.Thrust)/(dynPres*S);
            meanLiftC(i) = ...
                mean(forces{i}.Lift)/(dynPres*S);
            meanSideC(i) = ...
                mean(forces{i}.Side)/(dynPres*S);
            % Calculate mean forces and store the 
            % dynamic press
            meanThrust(i) = mean(forces{i}.Thrust);
            meanLift(i) = mean(forces{i}.Lift);
            meanQ(i) = dynPres;

            peakX(i,folNum,spaceNum) = max(abs(tempForceData.dataCh3*slopes(1,1)+tempForceData.dataCh0*slopes(1,2)));
            peakY(i,folNum,spaceNum) = max(abs(tempForceData.dataCh4*slopes(2,1)+tempForceData.dataCh1*slopes(2,2)));
            peakZ(i,folNum,spaceNum) = max(abs(tempForceData.dataCh5*29.3562+tempForceData.dataCh2*30.1330));

            peakXSin(i,folNum,spaceNum) = max(max(abs(tempForceData.dataCh3*slopes(1,1))),max(abs(tempForceData.dataCh0*slopes(1,2))));
            peakYSin(i,folNum,spaceNum) = max(max(abs(tempForceData.dataCh4*slopes(2,1))),max(abs(tempForceData.dataCh1*slopes(2,2))));
            peakZSin(i,folNum,spaceNum) = max(max(abs(tempForceData.dataCh5*29.3562)),max(abs(tempForceData.dataCh2*30.1330)));
            
            % Voltages for use in uncertainty calcs.
            % (Needed for unc. of the force conversion
            % slopes, calculations here are to make the
            % unc calculation easier to read)
            meanVFx(i) = ...
                sqrt(...
                mean(tempForceData.dataCh3Biased)^2+...
                mean(tempDriftData.dataCh3Biased)^2 ...
                );
            meanVFy(i) = ...
                sqrt( ...
                mean(tempForceData.dataCh4Biased)^2+...
                mean(tempDriftData.dataCh4Biased)^2 ...
                );
            meanVBx(i) = ...
                sqrt( ...
                mean(tempForceData.dataCh0Biased)^2+ ...
                mean(tempDriftData.dataCh0Biased)^2 ...
                );
            meanVBy(i) = ...
            sqrt( ...
            mean(tempForceData.dataCh1Biased)^2+ ...
            mean(tempDriftData.dataCh1Biased)^2 ...
            );
            
            % Clear all variables that start with temp
            % to ensure different loop iterations don't
            % interact
            clear temp*
        end     
        
        % Store coefficients, forces, pressure and
        % voltages for this pitch angle (folNum) &
        % run number (spaceNum)
        thrustCoeff(:,folNum,spaceNum) = meanThrustC;    
        liftCoeff(:,folNum,spaceNum) = meanLiftC;
        sideCoeff(:,folNum,spaceNum) = meanSideC; 
        powCoeff(:,folNum,spaceNum) = meanCP;

        thrust(:,folNum,spaceNum) = meanThrust;    
        lift(:,folNum,spaceNum) = meanLift;
        q(:,folNum,spaceNum) = meanQ;

        VFx(:,folNum,spaceNum) = meanVFx;
        VFy(:,folNum,spaceNum) = meanVFy;
        VBx(:,folNum,spaceNum) = meanVBx;
        VBy(:,folNum,spaceNum) = meanVBy;
    end

end
% 
% max(peakX,[],'all')
% max(peakY,[],'all')
% max(peakZ,[],'all')
% 
% max(peakXSin,[],'all')
% max(peakYSin,[],'all')
% max(peakZSin,[],'all')

check3 = thrustCoeff-phsThr;
max(abs(check3),[],'all')
check4 = liftCoeff-phsL;
max(abs(check4),[],'all')
%%

% Calculate the mean of a condition across all runs
% conducted at that condition (ex. mean of all 9 runs
% conducted for k=0.11 and mean pitch = 5)
thrustCoeffMean = mean(thrustCoeff,3);
liftCoeffMean = mean(liftCoeff,3);
sideCoeffMean = mean(sideCoeff,3);
powCoeffMean = mean(powCoeff,3);
thrustMean = mean(thrust,3);
liftMean = mean(lift,3);
qMean = mean(q,3);
VFxMean = mean(VFx,3);
VFyMean = mean(VFy,3);
VBxMean = mean(VBx,3);
VByMean = mean(VBy,3);

% Calculate uncertainty of lift and thrust based on max
% possible misalignment of the test stand (dF/dPsi)
thrustMisalign = ...
    liftMean*cosd(sensorMisalignDeg)-...
    thrustMean*sind(sensorMisalignDeg);
liftMisalign = ...
    -liftMean*sind(sensorMisalignDeg)-...
    thrustMean*cosd(sensorMisalignDeg);

% Calculate uncertainty that can't be reduced by
% repeated flapping trials
% (force conversion, misalign, manuf. unc. of press.)
thrustBR = ...
    sqrt(...
        (...
            VFxMean.^2*slopesUnc(1,1)^2 + ...
            VBxMean.^2*slopesUnc(1,2)^2 +  ...
            thrustMisalign.^2*misAlignRad^2 + ...
            uncF0(2)^2 + ...
            uncFS(2)^2 ...
        )./(qMean*S).^2 + ...% Force unc. so div by qS
        (thrustMean./(qMean.^2*S)).^2*uncQ^2); % q unc.

liftBR = ...
    sqrt(...
        (...
            VFyMean.^2*slopesUnc(2,1)^2 + ...
            VByMean.^2*slopesUnc(2,2)^2 + ...
            liftMisalign.^2*misAlignRad^2 + ...
            uncF0(1)^2 + ...
            uncFS(1)^2 ...
        )./(qMean*S).^2 + ...% Force unc. so div by qS
        (liftMean./(qMean.^2*S)).^2*uncQ^2); % q unc.

% Sqrt of num. of runs for Standand Error of Mean
sqrtN = sqrt(length(folderPath));

% Calculate uncertainty that can be reduced by
% repeated flapping trials (short term drift)
thrustSR = sqrt((2*uncTDrift)^2)./(sqrtN*qMean*S);
liftSR = sqrt((2*uncLDrift)^2)./(sqrtN*qMean*S);

% Calculate total uncertainty
thrustUnc = sqrt(thrustBR.^2 + thrustSR.^2);
liftUnc = sqrt(liftBR.^2 + liftSR.^2);

% Calculate RMSE of motors based on peak power observed
peakPitch = max(peakPitchPow);
uncPitch = 0.138*peakPitch + 1.5;

peakStroke = max(peakStrokePow);
uncStroke = 0.138*peakStroke + 1.5;

% Calculate unc. power coeff. that can be reduced by
% repeated trials
% RMSE is an inst. unc. that applies to every pow data
% point collected. By Standard Error of Mean it should
% be divided by num of points in the trial. Use the
% least amount of data points collected in a trial as a
% conservative estimate for every trial
powErrMain = sqrt(...
    (...
        (2*uncPitch)^2 + ...
        (2*uncStroke)^2 ...
    )/minInstPowPoints ...
    )./...
    (sqrtN*qMean*S*Uinf);

% Add uncertainty that can't be reduced from repeated
% trials
powErrMain = sqrt(...
  powErrMain.^2 + ...
  (2.306*powLossUnc./(qMean*S*Uinf)).^2+...%unc.fric.loss
  (powCoeffMean./(qMean.^2*S*Uinf)).^2*uncQ^2); % q Unc

% Uncertainty bounds for plotting coeffs vs mean theta
thrustBound = [thrustCoeffMean+thrustUnc; ...
    flipud(thrustCoeffMean-thrustUnc)];

liftBound = [liftCoeffMean+liftUnc; ...
    flipud(liftCoeffMean-liftUnc)];

% Only calculating one because all on top of each other
powBoundup = max(powCoeffMean+powErrMain,[],2);

powBoundlow = ...
    min(flipud(powCoeffMean-powErrMain),[],2);

powBound = [powBoundup; powBoundlow];

% Uncertainty bounds for plotting coeffs vs k
thrustBound2 = ...
    [thrustCoeffMean+thrustUnc ...
    fliplr(thrustCoeffMean-thrustUnc)]';
liftBound2 = ...
    [liftCoeffMean+liftUnc ...
    fliplr(liftCoeffMean-liftUnc)]';
powBound2 = ...
    [powCoeffMean+powErrMain ...
    fliplr(powCoeffMean-powErrMain)]';

% Calculataing k
redFreq = pi*freqs*c/Uinf;
xBounds = [redFreq;flipud(redFreq)];

% Setting mean thetas
meanPitch = 0:10;

% Mesh grid for 3D plotting of data points
[pitch3d,freq3d] = meshgrid(meanPitch,redFreq);

% Empty containers for surface fitting
CT_forFit = zeros(length(redFreq)*length(meanPitch),5);
CL_forFit = zeros(length(redFreq)*length(meanPitch),5);
CP_forFit = zeros(length(redFreq)*length(meanPitch),5);

% Finer k and theta for plotting fit surface
kSpace = linspace(redFreq(1),redFreq(end),1000);
thetSpace = linspace(meanPitch(1),meanPitch(end),1000);
[kMesh, thetMesh] = meshgrid(kSpace,thetSpace);

% Creating data tables to perform fitting on
for i=1:size(thrustCoeffMean,2)
    % Setting k for all the containers
    CT_forFit((i*9)-8:i*9,1) = redFreq;
    CL_forFit((i*9)-8:i*9,1) = redFreq;
    CP_forFit((i*9)-8:i*9,1) = redFreq;
    % Setting theta bar for all containers
    CT_forFit((i*9)-8:i*9,2) = meanPitch(i);
    CL_forFit((i*9)-8:i*9,2) = meanPitch(i);
    CP_forFit((i*9)-8:i*9,2) = meanPitch(i);
    % Setting nominal coefficients
    CT_forFit((i*9)-8:i*9,3) = thrustCoeffMean(:,i);
    CL_forFit((i*9)-8:i*9,3) = liftCoeffMean(:,i);
    CP_forFit((i*9)-8:i*9,3) = powCoeffMean(:,i);
    % Setting upper bound of coefficients
    CT_forFit((i*9)-8:i*9,4) = ...
        thrustCoeffMean(:,i)+thrustUnc(:,i);
    CL_forFit((i*9)-8:i*9,4) = ...
        liftCoeffMean(:,i)+liftUnc(:,i);
    CP_forFit((i*9)-8:i*9,4) = ...
        powCoeffMean(:,i)+powErrMain(:,i);
    % Setting lower bound of coefficients
    CT_forFit((i*9)-8:i*9,5) = ...
        thrustCoeffMean(:,i)-thrustUnc(:,i);
    CL_forFit((i*9)-8:i*9,5) = ...
        liftCoeffMean(:,i)-liftUnc(:,i);
    CP_forFit((i*9)-8:i*9,5) = ...
        powCoeffMean(:,i)-powErrMain(:,i);
end

% Fitting nominal coefficient values
[CT3D,CTGood] = ...
    fit(...
        [CT_forFit(:,1) CT_forFit(:,2)],...
        CT_forFit(:,3),...
        'poly32'...
        );
[CL3D,CLGood] = ...
    fit(...
        [CL_forFit(:,1) CL_forFit(:,2)],...
        CL_forFit(:,3),...
        'poly22'...
        );
[CP3D,CPGood] = ...
    fit(...
        [CP_forFit(:,1) CP_forFit(:,2)],...
        CP_forFit(:,3),...
        'poly21'...
        );

% Fitting upper bound surface
[CTup,CTupGood] = ...
    fit(...
        [CT_forFit(:,1) CT_forFit(:,2)],...
        CT_forFit(:,4),...
        'poly32'...
        );
[CLup,CLupGood] = ...
    fit(...
        [CL_forFit(:,1) CL_forFit(:,2)],...
        CL_forFit(:,4),...
        'poly22'...
        );
[CPup,CPupGood] = ...
    fit(...
        [CP_forFit(:,1) CP_forFit(:,2)],...
        CP_forFit(:,4),...
        'poly21'...
        );

% Fitting lower bounds
[CTlo,CTloGood] = ...
    fit(...
        [CT_forFit(:,1) CT_forFit(:,2)],...
        CT_forFit(:,5),...
        'poly32'...
        );
[CLlo,CLloGood] = ...
    fit(...
        [CL_forFit(:,1) CL_forFit(:,2)],...
        CL_forFit(:,5),...
        'poly22'...
        );
[CPlo,CPloGood] = ...
    fit(...
        [CP_forFit(:,1) CP_forFit(:,2)],...
        CP_forFit(:,5),...
        'poly21'...
        );

% Evaluate fitted surfaces on the plotting mesh
CTMesh = CT3D(kMesh,thetMesh);
CLMesh = CL3D(kMesh,thetMesh);
CPMesh = CP3D(kMesh,thetMesh);

CTMeshUp = CTup(kMesh,thetMesh);
CLMeshUp = CLup(kMesh,thetMesh);
CPMeshUp = CPup(kMesh,thetMesh);

CTMeshLo = CTlo(kMesh,thetMesh);
CLMeshLo = CLlo(kMesh,thetMesh);
CPMeshLo = CPlo(kMesh,thetMesh);

%%

autMap = colormap('autumn');
autMap(:,2) = linspace(0,0.75,size(autMap,1));

wintMap =  colormap('winter');
wintMap(:,3) = linspace(1,0,size(wintMap,1));

sprMap = colormap('spring');
sprMap(:,2) = linspace(0,0.75,size(sprMap,1));
sprMap(:,3) = linspace(1,0.25,size(sprMap,1));


figure()
hold on
fill(xBounds,liftBound(:,1),'r','FaceAlpha',uncOpacity,'EdgeColor','none');
fill(xBounds,liftBound(:,4),'g','FaceAlpha',uncOpacity,'EdgeColor','none');
fill(xBounds,liftBound(:,7),'b','FaceAlpha',uncOpacity,'EdgeColor','none');
fill(xBounds,liftBound(:,10),'k','FaceAlpha',uncOpacity,'EdgeColor','none');
fill(xBounds,liftBound(:,11),'m','FaceAlpha',uncOpacity,'EdgeColor','none');
l0 = plot(redFreq,liftCoeffMean(:,1),'-or', 'DisplayName',"$\overline{\theta}=$ 0",'LineWidth',2);
l3 = plot(redFreq,liftCoeffMean(:,4),'-.xg', 'DisplayName',"$\overline{\theta}=$ 3",'LineWidth',2);
l6 = plot(redFreq,liftCoeffMean(:,7),':^b', 'DisplayName',"$\overline{\theta}=$ 6",'LineWidth',2);
l9 = plot(redFreq,liftCoeffMean(:,10),'--pentagramk', 'DisplayName',"$\overline{\theta}=$ 9",'LineWidth',2);
l10 = plot(redFreq,liftCoeffMean(:,11),'-.hexagramm', 'DisplayName',"$\overline{\theta}=$ 10",'LineWidth',2);
xlim([0.08 0.26])
xlabel('$k$')
ylabel('$\overline{C_L}$')
legend([l0 l3 l6 l9 l10],'Location','southeast')
myExportGraphics(gcf,'LvsK.eps','C:\Users\James\OneDrive - University of Calgary\Thesis\Ch5\')

%%

xBounds2 = [meanPitch fliplr(meanPitch)];
figure()
hold on
fill(xBounds2,liftBound2(:,2),'r','FaceAlpha', uncOpacity,'EdgeColor','none');
fill(xBounds2,liftBound2(:,4),'g','FaceAlpha', uncOpacity,'EdgeColor','none');
fill(xBounds2,liftBound2(:,7),'b','FaceAlpha', uncOpacity,'EdgeColor','none');
fill(xBounds2,liftBound2(:,8),'k','FaceAlpha', uncOpacity,'EdgeColor','none');
fill(xBounds2,liftBound2(:,9),'m','FaceAlpha', uncOpacity,'EdgeColor','none');
lP0 = plot(meanPitch,liftCoeffMean(2,:),'-or', 'DisplayName',"$k$ 0.11",'LineWidth',2);
lP3 = plot(meanPitch,liftCoeffMean(4,:),'-.xg', 'DisplayName',"$k$ 0.15",'LineWidth',2);
lP6 = plot(meanPitch,liftCoeffMean(7,:),':^b', 'DisplayName',"$k$ 0.21",'LineWidth',2);
lP7 = plot(meanPitch,liftCoeffMean(8,:),'-.<k', 'DisplayName',"$k$ 0.24",'LineWidth',2);
lP8 = plot(meanPitch,liftCoeffMean(9,:),'->m', 'DisplayName',"$k$ 0.26",'LineWidth',2);
xlabel('$\overline{\theta}$ ($^\circ$)')
ylabel('$\overline{C_L}$')
legend([lP0 lP3 lP6 lP7 lP8],'Location','northwest')
myExportGraphics(gcf,'LvsTh.eps','C:\Users\James\OneDrive - University of Calgary\Thesis\Ch5\')

%%

figure()
hold on
fill(xBounds,thrustBound(:,1),'r','FaceAlpha',uncOpacity,'EdgeColor','none');
fill(xBounds,thrustBound(:,4),'g','FaceAlpha',uncOpacity,'EdgeColor','none');
fill(xBounds,thrustBound(:,7),'b','FaceAlpha',uncOpacity,'EdgeColor','none');
fill(xBounds,thrustBound(:,10),'k','FaceAlpha',uncOpacity,'EdgeColor','none');
fill(xBounds,thrustBound(:,11),'m','FaceAlpha',uncOpacity,'EdgeColor','none');
t0 = plot(redFreq,thrustCoeffMean(:,1),'-or', 'DisplayName',"$\overline{\theta}=$ 0",'LineWidth',2);
t3 = plot(redFreq,thrustCoeffMean(:,4),'-.xg', 'DisplayName',"$\overline{\theta}=$ 3",'LineWidth',2);
t6 = plot(redFreq,thrustCoeffMean(:,7),':^b', 'DisplayName',"$\overline{\theta}=$ 6",'LineWidth',2);
t9 = plot(redFreq,thrustCoeffMean(:,10),'--pentagramk', 'DisplayName',"$\overline{\theta}=$ 9",'LineWidth',2);
t10 = plot(redFreq,thrustCoeffMean(:,11),'-.hexagramm', 'DisplayName',"$\overline{\theta}=$ 10",'LineWidth',2);
xlim([0.08 0.26])
xlabel('$k$')
ylabel('$\overline{C_T}$')
legend([t0 t3 t6 t9 t10],'Location','southeast')
myExportGraphics(gcf,'TvsK.eps','C:\Users\James\OneDrive - University of Calgary\Thesis\Ch5\')

%%

figure()
hold on
fill(xBounds,powBound,'g','FaceAlpha',uncOpacity,'EdgeColor','none');
p0 = plot(redFreq,powCoeffMean(:,1),'-or', 'DisplayName',"$\overline{\theta}=$ 0",'LineWidth',2);
p3 = plot(redFreq,powCoeffMean(:,4),'-.xg', 'DisplayName',"$\overline{\theta}=$ 3",'LineWidth',2);
p6 = plot(redFreq,powCoeffMean(:,7),':^b', 'DisplayName',"$\overline{\theta}=$ 6",'LineWidth',2);
p9 = plot(redFreq,powCoeffMean(:,10),'--pentagramk', 'DisplayName',"$\overline{\theta}=$ 9",'LineWidth',2);
p10 = plot(redFreq,powCoeffMean(:,11),'-.hexagramm', 'DisplayName',"$\overline{\theta}=$ 10",'LineWidth',2);
xlim([0.08 0.26])
xlabel('$k$')
ylabel('$\overline{C_P}$')
legend([p0 p3 p6 p9 p10],'Location','northwest')
myExportGraphics(gcf,'PvsK.eps','C:\Users\James\OneDrive - University of Calgary\Thesis\Ch5\')

%%

figure()
hold on
fill(xBounds,powBound,'g','FaceAlpha',uncOpacity,'EdgeColor','none');
p3 = plot(redFreq,powCoeffMean(:,4),'-.xg', 'DisplayName',"$\overline{\theta}=$ 3",'LineWidth',2);
lowMark = scatter(redFreq(4),0.0144,'b','filled','DisplayName','Low Bound');
highMark = scatter(redFreq(5),0.0839,'r','filled','DisplayName','High Bound');
legend([lowMark highMark])
xlim([0.08 0.26])
xlabel('$k$')
ylabel('$\overline{C_P}$')
myExportGraphics(gcf,'2DExamp.eps','C:\Users\James\OneDrive - University of Calgary\Thesis\Ch5\')

%%

figure()
hold on
fill(xBounds2,thrustBound2(:,2),'r','FaceAlpha',uncOpacity,'EdgeColor','none');
fill(xBounds2,thrustBound2(:,4),'g','FaceAlpha',uncOpacity,'EdgeColor','none');
fill(xBounds2,thrustBound2(:,7),'b','FaceAlpha',uncOpacity,'EdgeColor','none');
fill(xBounds2,thrustBound2(:,8),'k','FaceAlpha',uncOpacity,'EdgeColor','none');
fill(xBounds2,thrustBound2(:,9),'m','FaceAlpha',uncOpacity,'EdgeColor','none');
tP0 = plot(meanPitch,thrustCoeffMean(2,:),'-or', 'DisplayName',"$k$ 0.11",'LineWidth',2);
tP3 = plot(meanPitch,thrustCoeffMean(4,:),'-.xg', 'DisplayName',"$k$ 0.15",'LineWidth',2);
tP6 = plot(meanPitch,thrustCoeffMean(7,:),':^b', 'DisplayName',"$k$ 0.21",'LineWidth',2);
tP7 = plot(meanPitch,thrustCoeffMean(8,:),'-.<k', 'DisplayName',"$k$ 0.24",'LineWidth',2);
tP8 = plot(meanPitch,thrustCoeffMean(9,:),'->m', 'DisplayName',"$k$ 0.26",'LineWidth',2);
xlabel('$\overline{\theta}$ ($^\circ$)')
ylabel('$\overline{C_T}$')
legend([tP0 tP3 tP6 tP7 tP8],'Location','northeast')
myExportGraphics(gcf,'TvsTh.eps','C:\Users\James\OneDrive - University of Calgary\Thesis\Ch5\')


%%

figure()
hold on
fill(xBounds2,powBound2(:,2),'r','FaceAlpha',uncOpacity,'EdgeColor','none');
fill(xBounds2,powBound2(:,4),'g','FaceAlpha',uncOpacity,'EdgeColor','none');
fill(xBounds2,powBound2(:,7),'b','FaceAlpha',uncOpacity,'EdgeColor','none');
fill(xBounds2,powBound2(:,8),'k','FaceAlpha',uncOpacity,'EdgeColor','none');
fill(xBounds2,powBound2(:,9),'m','FaceAlpha',uncOpacity,'EdgeColor','none');
pP0 = plot(meanPitch,powCoeffMean(2,:),'-or', 'DisplayName',"$k$ 0.11",'LineWidth',2);
pP3 = plot(meanPitch,powCoeffMean(4,:),'-.xg', 'DisplayName',"$k$ 0.15",'LineWidth',2);
pP6 = plot(meanPitch,powCoeffMean(7,:),':^b', 'DisplayName',"$k$ 0.21",'LineWidth',2);
pP7 = plot(meanPitch,powCoeffMean(8,:),'-.<k', 'DisplayName',"$k$ 0.24",'LineWidth',2);
pP8 = plot(meanPitch,powCoeffMean(9,:),'->m', 'DisplayName',"$k$ 0.26",'LineWidth',2);
xlabel('$\overline{\theta}$ ($^\circ$)')
ylabel('$\overline{C_P}$')
legend([pP0 pP3 pP6 pP7 pP8],'Location','northeast')
myExportGraphics(gcf,'PvsTh.eps','C:\Users\James\OneDrive - University of Calgary\Thesis\Ch5\')

%% 

figure()
hold on
h = plot(CLup,[CL_forFit(:,1) CL_forFit(:,2)],CL_forFit(:,3));
view(-37.5, 30)
xlabel('$k$')
ylabel('$\overline{\theta}$ ($^\circ$)')
zlabel('$\overline{C_L}$')
zlim([-0.02 0.4])
clim([-0.02 0.4])
colormap(autMap)
colorbar
theme('light')
fitDataPoints = findobj(gca, 'Type', 'Line');
delete(fitDataPoints); 
s = scatter3(CL_forFit(:,1), CL_forFit(:,2),CL_forFit(:,3), 10, 'filled','MarkerFaceColor','k'); 
s.MarkerEdgeColor = 'none';
s.MarkerFaceAlpha = 0.3;
fitSurface = findobj(gca, 'Type', 'Surface');
set(fitSurface, 'EdgeColor', 'none', 'FaceAlpha', 1);
set(fitSurface, 'FaceAlpha', 1.0); 
set(gcf, 'Alphamap', 1.0);
myExportGraphics(gcf,'clUp.eps','C:\Users\James\OneDrive - University of Calgary\Thesis\Ch5\Surfaces\',10)

%%

figure()
hold on
plot(CLlo,[CL_forFit(:,1) CL_forFit(:,2)],CL_forFit(:,3));
view(-37.5, 30)
xlabel('$k$')
ylabel('$\overline{\theta}$ ($^\circ$)')
zlabel('$\overline{C_L}$')
zlim([-0.02 0.4])
clim([-0.02 0.4])
colormap(autMap)
colorbar
theme('light')
fitDataPoints = findobj(gca, 'Type', 'Line');
delete(fitDataPoints); 
s = scatter3(CL_forFit(:,1), CL_forFit(:,2),CL_forFit(:,3), 10, 'filled','MarkerFaceColor','k'); 
s.MarkerEdgeColor = 'none';
s.MarkerFaceAlpha = 0.3;
fitSurface = findobj(gca, 'Type', 'Surface');
set(fitSurface, 'EdgeColor', 'none', 'FaceAlpha', 1);
set(fitSurface, 'FaceAlpha', 1.0); 
set(gcf, 'Alphamap', 1.0);
myExportGraphics(gcf,'clLo.eps','C:\Users\James\OneDrive - University of Calgary\Thesis\Ch5\Surfaces\',10)

%%

figure()
hold on
plot(CL3D,[CL_forFit(:,1) CL_forFit(:,2)],CL_forFit(:,3));
view(-37.5, 30)
xlabel('$k$')
ylabel('$\overline{\theta}$ ($^\circ$)')
zlabel('$\overline{C_L}$')
zlim([-0.02 0.4])
clim([-0.02 0.4])
colormap(autMap)
colorbar
theme('light')
fitDataPoints = findobj(gca, 'Type', 'Line');
delete(fitDataPoints); 
s = scatter3(CL_forFit(:,1), CL_forFit(:,2),CL_forFit(:,3), 10, 'filled','MarkerFaceColor','k'); 
s.MarkerEdgeColor = 'none';
s.MarkerFaceAlpha = 0.3;
fitSurface = findobj(gca, 'Type', 'Surface');
set(fitSurface, 'EdgeColor', 'none', 'FaceAlpha', 1);
set(fitSurface, 'FaceAlpha', 1.0); 
set(gcf, 'Alphamap', 1.0);
myExportGraphics(gcf,'clReg.eps','C:\Users\James\OneDrive - University of Calgary\Thesis\Ch5\Surfaces\',10)

%%

figure()
hold on
plot(CTup,[CT_forFit(:,1) CT_forFit(:,2)],CT_forFit(:,3))
view(145.2338,31.3629)
xlabel('$k$')
ylabel('$\overline{\theta}$ ($^\circ$)')
zlabel('$\overline{C_T}$')
zlim([-0.25 0.25])
colormap(wintMap)
clim([-0.25 0.25])
colorbar
theme('light')
fitDataPoints = findobj(gca, 'Type', 'Line');
delete(fitDataPoints); 
s = scatter3(CT_forFit(:,1), CT_forFit(:,2),CT_forFit(:,3), 10, 'filled','MarkerFaceColor','k'); 
s.MarkerEdgeColor = 'none';
s.MarkerFaceAlpha = 0.3;
fitSurface = findobj(gca, 'Type', 'Surface');
set(fitSurface, 'EdgeColor', 'none', 'FaceAlpha', 1);
set(fitSurface, 'FaceAlpha', 1.0); 
set(gcf, 'Alphamap', 1.0);
myExportGraphics(gcf,'ctUp.eps','C:\Users\James\OneDrive - University of Calgary\Thesis\Ch5\Surfaces\',10)

%%

figure()
hold on
plot(CTlo,[CT_forFit(:,1) CT_forFit(:,2)],CT_forFit(:,3))
view(145.2338,31.3629)
xlabel('$k$')
ylabel('$\overline{\theta}$ ($^\circ$)')
zlabel('$\overline{C_T}$')
zlim([-0.25 0.25])
colormap(wintMap)
clim([-0.25 0.25])
colorbar
theme('light')
fitDataPoints = findobj(gca, 'Type', 'Line');
delete(fitDataPoints); 
s = scatter3(CT_forFit(:,1), CT_forFit(:,2),CT_forFit(:,3), 10, 'filled','MarkerFaceColor','k'); 
s.MarkerEdgeColor = 'none';
s.MarkerFaceAlpha = 0.3;
fitSurface = findobj(gca, 'Type', 'Surface');
set(fitSurface, 'EdgeColor', 'none', 'FaceAlpha', 1);
set(fitSurface, 'FaceAlpha', 1.0); 
set(gcf, 'Alphamap', 1.0);
myExportGraphics(gcf,'ctLo.eps','C:\Users\James\OneDrive - University of Calgary\Thesis\Ch5\Surfaces\',10)

%%

figure()
hold on
plot(CT3D,[CT_forFit(:,1) CT_forFit(:,2)],CT_forFit(:,3))
view(145.2338,31.3629)
xlabel('$k$')
ylabel('$\overline{\theta}$ ($^\circ$)')
zlabel('$\overline{C_T}$')
zlim([-0.25 0.25])
colormap(wintMap)
clim([-0.25 0.25])
colorbar
theme('light')
fitDataPoints = findobj(gca, 'Type', 'Line');
delete(fitDataPoints); 
s = scatter3(CT_forFit(:,1), CT_forFit(:,2),CT_forFit(:,3), 10, 'filled','MarkerFaceColor','k'); 
s.MarkerEdgeColor = 'none';
s.MarkerFaceAlpha = 0.3;
fitSurface = findobj(gca, 'Type', 'Surface');
set(fitSurface, 'EdgeColor', 'none', 'FaceAlpha', 1);
set(fitSurface, 'FaceAlpha', 1.0); 
set(gcf, 'Alphamap', 1.0);
myExportGraphics(gcf,'ctReg.eps','C:\Users\James\OneDrive - University of Calgary\Thesis\Ch5\Surfaces\',10)

%%

figure()
hold on
plot(CPup,[CP_forFit(:,1) CP_forFit(:,2)],CP_forFit(:,3))
view(-37.5, 30)
xlabel('$k$')
ylabel('$\overline{\theta}$ ($^\circ$)')
zlabel('$C_P$  Upper Surface')
zlim([-0.05 0.25])
clim([-0.05 0.25])
colormap(sprMap)
colorbar;
theme('light')
fitDataPoints = findobj(gca, 'Type', 'Line');
delete(fitDataPoints); 
s = scatter3(CP_forFit(:,1), CP_forFit(:,2),CP_forFit(:,3), 10, 'filled','MarkerFaceColor','k'); 
s.MarkerEdgeColor = 'none';
s.MarkerFaceAlpha = 0.3;
fitSurface = findobj(gca, 'Type', 'Surface');
set(fitSurface, 'EdgeColor', 'none', 'FaceAlpha', 1);
set(fitSurface, 'FaceAlpha', 1.0); 
set(gcf, 'Alphamap', 1.0);
myExportGraphics(gcf,'cpUp.eps','C:\Users\James\OneDrive - University of Calgary\Thesis\Ch5\Surfaces\',10)

%%

figure()
hold on
plot(CPlo,[CP_forFit(:,1) CP_forFit(:,2)],CP_forFit(:,3))
view(-37.5, 30)
xlabel('$k$')
ylabel('$\overline{\theta}$ ($^\circ$)')
zlabel('$C_P$  Lower Surface')
zlim([-0.05 0.25])
clim([-0.05 0.25])
colormap(sprMap)
colorbar;
theme('light')
fitDataPoints = findobj(gca, 'Type', 'Line');
delete(fitDataPoints); 
s = scatter3(CP_forFit(:,1), CP_forFit(:,2),CP_forFit(:,3), 10, 'filled','MarkerFaceColor','k'); 
s.MarkerEdgeColor = 'none';
s.MarkerFaceAlpha = 0.3;
fitSurface = findobj(gca, 'Type', 'Surface');
set(fitSurface, 'EdgeColor', 'none', 'FaceAlpha', 1);
set(fitSurface, 'FaceAlpha', 1.0); 
set(gcf, 'Alphamap', 1.0);
myExportGraphics(gcf,'cpLo.eps','C:\Users\James\OneDrive - University of Calgary\Thesis\Ch5\Surfaces\',10)

%%

figure()
hold on
plot(CP3D,[CP_forFit(:,1) CP_forFit(:,2)],CP_forFit(:,3))
view(-37.5, 30)
xlabel('$k$')
ylabel('$\overline{\theta}$ ($^\circ$)')
zlabel('$C_P$ Mean Surface')
zlim([-0.05 0.25])
clim([-0.05 0.25])
colormap(sprMap)
colorbar;
theme('light')
fitDataPoints = findobj(gca, 'Type', 'Line');
delete(fitDataPoints); 
s = scatter3(CP_forFit(:,1), CP_forFit(:,2),CP_forFit(:,3), 10, 'filled','MarkerFaceColor','k'); 
s.MarkerEdgeColor = 'none';
s.MarkerFaceAlpha = 0.3;
fitSurface = findobj(gca, 'Type', 'Surface');
set(fitSurface, 'EdgeColor', 'none', 'FaceAlpha', 1);
set(fitSurface, 'FaceAlpha', 1.0); 
set(gcf, 'Alphamap', 1.0);
myExportGraphics(gcf,'cpReg.eps','C:\Users\James\OneDrive - University of Calgary\Thesis\Ch5\Surfaces\',10)

%%

cpLevels = [ 0 0.01 0.03 0.055 0.085 0.12 0.15 0.18 0.21 0.24 0.27];
Pup = figure();
cpAx = axes(Pup);
[PC1, PH1] = contour(cpAx,kMesh,thetMesh,CPMeshUp,cpLevels,'-.','linewidth',2,'labelspacing',200);
colormap(sprMap)
xlabel('$k$')
ylabel('$\overline{\theta}$ ($^\circ$)')
cpcb = colorbar(cpAx);
xlabel(cpcb,'$\overline{C_P}$', Interpreter='latex')
set(Pup, 'DefaultTextBackgroundColor', [1,1,1])
clabel(PC1,PH1,'manual','FontSize', 16)
theme('light')
grid on;
cpcb.Label.Rotation = 0;
cpcb.Label.Units = 'normalized';
cpcb.Label.Position = [0.8, -0.025];
myExportGraphics(gcf,'cpMapHigh.eps','C:\Users\James\OneDrive - University of Calgary\Thesis\Ch5\levelMaps\')

%%

Plo = figure();
cpAx = axes(Plo);
[PC1, PH1] = contour(cpAx,kMesh,thetMesh,CPMeshLo,cpLevels,'-.','linewidth',2,'labelspacing',200);
colormap(sprMap)
xlabel('$k$')
ylabel('$\overline{\theta}$ ($^\circ$)')
cpcb = colorbar(cpAx);
xlabel(cpcb,'$\overline{C_P}$', Interpreter='latex')
set(Plo, 'DefaultTextBackgroundColor', [1,1,1])
clabel(PC1,PH1,'manual','FontSize', 16)
theme('light')
grid on;
cpcb.Label.Rotation = 0;
cpcb.Label.Units = 'normalized';
cpcb.Label.Position = [0.8, -0.025];
myExportGraphics(gcf,'cpMapLow.eps','C:\Users\James\OneDrive - University of Calgary\Thesis\Ch5\levelMaps\')

%%

PCont = figure();
cpAx = axes(PCont);
[PC1, PH1] = contour(cpAx,kMesh,thetMesh,CPMesh,cpLevels,'-.','linewidth',2,'labelspacing',200);
colormap(sprMap)
xlabel('$k$')
ylabel('$\overline{\theta}$ ($^\circ$)')
cpcb = colorbar(cpAx);
xlabel(cpcb,'$\overline{C_P}$', Interpreter='latex')
set(PCont, 'DefaultTextBackgroundColor', [1,1,1])
clabel(PC1,PH1,'manual','FontSize', 16)
theme('light')
grid on;
cpcb.Label.Rotation = 0;
cpcb.Label.Units = 'normalized';
cpcb.Label.Position = [0.8, -0.025];
myExportGraphics(gcf,'cpMapReg.eps','C:\Users\James\OneDrive - University of Calgary\Thesis\Ch5\levelMaps\')

%%

clLevels = [0.05 0.1 0.15 0.20 0.25];
ctLevels = [-0.16 -0.12 -0.08 -0.04 0 0.01];
fig = figure();
ax1 = axes(fig);
ax2 = copyobj(ax1,fig);
hold on
[C1,h1] = contour(ax1,kMesh,thetMesh,CTMeshUp,ctLevels,'labelspacing',300,'linewidth',2);
[C2, h2] = contour(ax2,kMesh,thetMesh,CLMeshUp,clLevels,'--','labelspacing',300,'linewidth',2);
h1.LevelList = round(h1.LevelList,3);
h2.LevelList = round(h2.LevelList,3);
colormap(ax1,wintMap)
colormap(ax2,autMap)
set([ax1,ax2],'Position',[.17 .11 .685 .815]);
cb1 = colorbar(ax1,'Position',[.1 .11 .0275 .815]);
cb2 = colorbar(ax2,'Position',[.86 .11 .0275 .815]);
clim(ax1,[min(ctLevels) max(ctLevels)])
clim(ax2,[min(clLevels) max(clLevels)])
xlabel(cb1,'$\overline{C_T}$', Interpreter='latex')
xlabel(cb2,'$\overline{C_L}$', Interpreter='latex')
ax2.Color = 'none';
ax2.Visible = 'off';
theme("light")
xlabel('$k$')
ylab = ylabel('$\overline{\theta}$ ($^\circ$)');
ylab.Position(1) = 0.08;
set(fig, 'DefaultTextBackgroundColor', [1,1,1])

cb1.Label.Rotation = 0;
cb1.Label.Units = 'normalized';
cb1.Label.Position = [0.5, -0.07];

cb2.Label.Rotation = 0;
cb2.Label.Units = 'normalized';
cb2.Label.Position = [0.5, -0.025];

clabel(C1,h1,'manual','FontSize',16)
clabel(C2,h2,'manual','FontSize',16)
myExportGraphics(gcf,'ctMapHigh.eps','C:\Users\James\OneDrive - University of Calgary\Thesis\Ch5\levelMaps\',11.6)

%%

fig = figure();
ax1 = axes(fig);
ax2 = copyobj(ax1,fig);
hold on
[C1,h1] = contour(ax1,kMesh,thetMesh,CTMeshLo,ctLevels,'labelspacing',300,'linewidth',2);
[C2, h2] = contour(ax2,kMesh,thetMesh,CLMeshLo,clLevels,'--','labelspacing',300,'linewidth',2);
h1.LevelList = round(h1.LevelList,3);
h2.LevelList = round(h2.LevelList,3);
colormap(ax1,wintMap)
colormap(ax2,autMap)
set([ax1,ax2],'Position',[.17 .11 .685 .815]);
cb1 = colorbar(ax1,'Position',[.1 .11 .0275 .815]);
cb2 = colorbar(ax2,'Position',[.86 .11 .0275 .815]);
clim(ax1,[min(ctLevels) max(ctLevels)])
clim(ax2,[min(clLevels) max(clLevels)])
xlabel(cb1,'$\overline{C_T}$', Interpreter='latex')
xlabel(cb2,'$\overline{C_L}$', Interpreter='latex')
ax2.Color = 'none';
ax2.Visible = 'off';
theme("light")
xlabel('$k$')
ylab = ylabel('$\overline{\theta}$ ($^\circ$)');
ylab.Position(1) = 0.08;
set(fig, 'DefaultTextBackgroundColor', [1,1,1])

cb1.Label.Rotation = 0;
cb1.Label.Units = 'normalized';
cb1.Label.Position = [0.5, -0.07];

cb2.Label.Rotation = 0;
cb2.Label.Units = 'normalized';
cb2.Label.Position = [0.5, -0.025];

clabel(C1,h1,'manual','FontSize',16)
clabel(C2,h2,'manual','FontSize',16)
myExportGraphics(gcf,'ctMapLow.eps','C:\Users\James\OneDrive - University of Calgary\Thesis\Ch5\levelMaps\',11.6)

%%

fig = figure();
ax1 = axes(fig);
ax2 = copyobj(ax1,fig);
hold on
[C1,h1] = contour(ax1,kMesh,thetMesh,CTMesh,ctLevels,'labelspacing',300,'linewidth',2);
[C2, h2] = contour(ax2,kMesh,thetMesh,CLMesh,clLevels,'--','labelspacing',300,'linewidth',2);
h1.LevelList = round(h1.LevelList,3);
h2.LevelList = round(h2.LevelList,3);
colormap(ax1,wintMap)
colormap(ax2,autMap)
set([ax1,ax2],'Position',[.17 .11 .685 .815]);
cb1 = colorbar(ax1,'Position',[.1 .11 .0275 .815]);
cb2 = colorbar(ax2,'Position',[.86 .11 .0275 .815]);
clim(ax1,[min(ctLevels) max(ctLevels)])
clim(ax2,[min(clLevels) max(clLevels)])
xlabel(cb1,'$\overline{C_T}$', Interpreter='latex')
xlabel(cb2,'$\overline{C_L}$', Interpreter='latex')
ax2.Color = 'none';
ax2.Visible = 'off';
theme("light")
xlabel('$k$')
ylab = ylabel('$\overline{\theta}$ ($^\circ$)');
ylab.Position(1) = 0.08;
set(fig, 'DefaultTextBackgroundColor', [1,1,1])

cb1.Label.Rotation = 0;
cb1.Label.Units = 'normalized';
cb1.Label.Position = [0.5, -0.07];

cb2.Label.Rotation = 0;
cb2.Label.Units = 'normalized';
cb2.Label.Position = [0.5, -0.025];

clabel(C1,h1,'manual','FontSize',16)
clabel(C2,h2,'manual','FontSize',16)
myExportGraphics(gcf,'ctMapReg.eps','C:\Users\James\OneDrive - University of Calgary\Thesis\Ch5\levelMaps\',11.6)

%%

lineTypeSamp = ["-" "--" ":" "-." "-" "--" ":" "-." "-" "--" "-."];
markType = ["o" "+" "*" "x" "square" "diamond" "^" "<" ">" "pentagram" "hexagram"];
colorType = ["r" "g" "b" "k" "m" "r" "g" "b" "k" "m" "r"];

thrustBoundFull = [thrustCoeffMean+thrustUnc*3; flipud(thrustCoeffMean-thrustUnc*3)];
liftBoundFull = [liftCoeffMean+liftUnc*3; flipud(liftCoeffMean-liftUnc*3)];

thrustBound2Full = [thrustCoeffMean+thrustUnc*3 fliplr(thrustCoeffMean-thrustUnc*3)]';
liftBound2Full = [liftCoeffMean+liftUnc*3 fliplr(liftCoeffMean-liftUnc*3)]';

for i = [1 6]
    figure()
    hold on
    fill(xBounds,thrustBoundFull(:,i),colorType(i),'FaceAlpha',uncOpacity,'EdgeColor','none');
    plot(redFreq,thrustCoeffMean(:,i),'LineStyle',lineTypeSamp(i),'Marker',markType(i),'LineWidth',2)
    for j = 1:9
        scatter(redFreq,thrustCoeff(:,i,j),'MarkerFaceColor','k')
    end
    xlabel('$k$')
    ylabel('$C_T$')

    figure()
    hold on
    fill(xBounds,liftBoundFull(:,i),colorType(i),'FaceAlpha',uncOpacity,'EdgeColor','none');
    plot(redFreq,liftCoeffMean(:,i),'LineWidth',2)
    for j = 1:9
        scatter(redFreq,liftCoeff(:,i,j),'MarkerFaceColor','k')
    end
    xlabel('$k$')
    ylabel('$C_L$')
    if i == 1
        myExportGraphics(gcf,'theta0driftBounds.eps','C:\Users\James\OneDrive - University of Calgary\Thesis\Ch5\')
    elseif i==6
        myExportGraphics(gcf,'theta5driftBounds.eps','C:\Users\James\OneDrive - University of Calgary\Thesis\Ch5\')
    end
end

%% figures with all of the measured coefficients, not just a small selection

% figure()
% hold on
% t0 = plot(redFreq,thrustCoeffMean(:,1),'-or', 'DisplayName',"Mean Pitch 0",'LineWidth',2);
% t1 = plot(redFreq,thrustCoeffMean(:,2),'--+g', 'DisplayName',"Mean Pitch 1",'LineWidth',2);
% t2 = plot(redFreq,thrustCoeffMean(:,3),':*b', 'DisplayName',"Mean Pitch 2",'LineWidth',2);
% t3 = plot(redFreq,thrustCoeffMean(:,4),'-.xk', 'DisplayName',"Mean Pitch 3",'LineWidth',2);
% t4 = plot(redFreq,thrustCoeffMean(:,5),'-squarem', 'DisplayName',"Mean Pitch 4",'LineWidth',2);
% t5 = plot(redFreq,thrustCoeffMean(:,6),'--diamondr', 'DisplayName',"Mean Pitch 5",'LineWidth',2);
% t6 = plot(redFreq,thrustCoeffMean(:,7),':^g', 'DisplayName',"Mean Pitch 6",'LineWidth',2);
% t7 = plot(redFreq,thrustCoeffMean(:,8),'-.<b', 'DisplayName',"Mean Pitch 7",'LineWidth',2);
% t8 = plot(redFreq,thrustCoeffMean(:,9),'->k', 'DisplayName',"Mean Pitch 8",'LineWidth',2);
% t9 = plot(redFreq,thrustCoeffMean(:,10),'--pentagramm', 'DisplayName',"Mean Pitch 9",'LineWidth',2);
% t10 = plot(redFreq,thrustCoeffMean(:,11),'-.hexagramr', 'DisplayName',"Mean Pitch 10",'LineWidth',2);
% fill(xBounds,thrustBound(:,1),'r','FaceAlpha',errorOpacity,'EdgeColor','none');
% fill(xBounds,thrustBound(:,2),'g','FaceAlpha',errorOpacity,'EdgeColor','none');
% fill(xBounds,thrustBound(:,3),'b','FaceAlpha',errorOpacity,'EdgeColor','none');
% fill(xBounds,thrustBound(:,4),'k','FaceAlpha',errorOpacity,'EdgeColor','none');
% fill(xBounds,thrustBound(:,5),'m','FaceAlpha',errorOpacity,'EdgeColor','none');
% fill(xBounds,thrustBound(:,6),'r','FaceAlpha',errorOpacity,'EdgeColor','none');
% fill(xBounds,thrustBound(:,7),'g','FaceAlpha',errorOpacity,'EdgeColor','none');
% fill(xBounds,thrustBound(:,8),'b','FaceAlpha',errorOpacity,'EdgeColor','none');
% fill(xBounds,thrustBound(:,9),'k','FaceAlpha',errorOpacity,'EdgeColor','none');
% fill(xBounds,thrustBound(:,10),'m','FaceAlpha',errorOpacity,'EdgeColor','none');
% fill(xBounds,thrustBound(:,11),'r','FaceAlpha',errorOpacity,'EdgeColor','none');
% xlim([0.88 2.7])
% xlabel('$k$')
% ylabel('$C_T$')
% legend([t0 t1 t2 t3 t4 t5 t6 t7 t8 t9 t10],'Location','northwest')
% % title('All Thust Coefficients vs Reduced Frequency')
% 
% 
% figure()
% hold on
% l0 = plot(redFreq,liftCoeffMean(:,1),'-or', 'DisplayName',"Mean Pitch 0",'LineWidth',2);
% l1 = plot(redFreq,liftCoeffMean(:,2),'--+g', 'DisplayName',"Mean Pitch 1",'LineWidth',2);
% l2 = plot(redFreq,liftCoeffMean(:,3),':*b', 'DisplayName',"Mean Pitch 2",'LineWidth',2);
% l3 = plot(redFreq,liftCoeffMean(:,4),'-.xk', 'DisplayName',"Mean Pitch 3",'LineWidth',2);
% l4 = plot(redFreq,liftCoeffMean(:,5),'-squarem', 'DisplayName',"Mean Pitch 4",'LineWidth',2);
% l5 = plot(redFreq,liftCoeffMean(:,6),'--diamondr', 'DisplayName',"Mean Pitch 5",'LineWidth',2);
% l6 = plot(redFreq,liftCoeffMean(:,7),':^g', 'DisplayName',"Mean Pitch 6",'LineWidth',2);
% l7 = plot(redFreq,liftCoeffMean(:,8),'-.<b', 'DisplayName',"Mean Pitch 7",'LineWidth',2);
% l8 = plot(redFreq,liftCoeffMean(:,9),'->k', 'DisplayName',"Mean Pitch 8",'LineWidth',2);
% l9 = plot(redFreq,liftCoeffMean(:,10),'--pentagramm', 'DisplayName',"Mean Pitch 9",'LineWidth',2);
% l10 = plot(redFreq,liftCoeffMean(:,11),'-.hexagramr', 'DisplayName',"Mean Pitch 10",'LineWidth',2);
% fill(xBounds,liftBound(:,1),'r','FaceAlpha',errorOpacity,'EdgeColor','none');
% fill(xBounds,liftBound(:,2),'g','FaceAlpha',errorOpacity,'EdgeColor','none');
% fill(xBounds,liftBound(:,3),'b','FaceAlpha',errorOpacity,'EdgeColor','none');
% fill(xBounds,liftBound(:,4),'k','FaceAlpha',errorOpacity,'EdgeColor','none');
% fill(xBounds,liftBound(:,5),'m','FaceAlpha',errorOpacity,'EdgeColor','none');
% fill(xBounds,liftBound(:,6),'r','FaceAlpha',errorOpacity,'EdgeColor','none');
% fill(xBounds,liftBound(:,7),'g','FaceAlpha',errorOpacity,'EdgeColor','none');
% fill(xBounds,liftBound(:,8),'b','FaceAlpha',errorOpacity,'EdgeColor','none');
% fill(xBounds,liftBound(:,9),'k','FaceAlpha',errorOpacity,'EdgeColor','none');
% fill(xBounds,liftBound(:,10),'m','FaceAlpha',errorOpacity,'EdgeColor','none');
% fill(xBounds,liftBound(:,11),'r','FaceAlpha',errorOpacity,'EdgeColor','none');
% xlim([0.88 2.7])
% xlabel('$k$')
% ylabel('$C_L$')
% legend([l0 l1 l2 l3 l4 l5 l6 l7 l8 l9 l10],'Location','northwest')
% % title('All Lift Coefficients vs Reduced Frequency')
% 
% 
% figure()
% hold on
% p0 = plot(redFreq,powCoeffMean(:,1),'-or', 'DisplayName',"Mean Pitch 0",'LineWidth',2);
% p1 = plot(redFreq,powCoeffMean(:,2),'--+g', 'DisplayName',"Mean Pitch 1",'LineWidth',2);
% p2 = plot(redFreq,powCoeffMean(:,3),':*b', 'DisplayName',"Mean Pitch 2",'LineWidth',2);
% p3 = plot(redFreq,powCoeffMean(:,4),'-.xk', 'DisplayName',"Mean Pitch 3",'LineWidth',2);
% p4 = plot(redFreq,powCoeffMean(:,5),'-squarem', 'DisplayName',"Mean Pitch 4",'LineWidth',2);
% p5 = plot(redFreq,powCoeffMean(:,6),'--diamondr', 'DisplayName',"Mean Pitch 5",'LineWidth',2);
% p6 = plot(redFreq,powCoeffMean(:,7),':^g', 'DisplayName',"Mean Pitch 6",'LineWidth',2);
% p7 = plot(redFreq,powCoeffMean(:,8),'-.<b', 'DisplayName',"Mean Pitch 7",'LineWidth',2);
% p8 = plot(redFreq,powCoeffMean(:,9),'->k', 'DisplayName',"Mean Pitch 8",'LineWidth',2);
% p9 = plot(redFreq,powCoeffMean(:,10),'--pentagramm', 'DisplayName',"Mean Pitch 9",'LineWidth',2);
% p10 = plot(redFreq,powCoeffMean(:,11),'-.hexagramr', 'DisplayName',"Mean Pitch 10",'LineWidth',2);
% % fill(xBounds,powBound(:,1),'r','FaceAlpha',errorOpacity,'EdgeColor','none');
% % fill(xBounds,powBound(:,2),[0.1 0.1 0.1],'FaceAlpha',errorOpacity,'EdgeColor','none');
% % fill(xBounds,powBound(:,3),[0.1 0.1 0.1],'FaceAlpha',errorOpacity,'EdgeColor','none');
% % fill(xBounds,powBound(:,4),'g','FaceAlpha',errorOpacity,'EdgeColor','none');
% % fill(xBounds,powBound(:,5),[0.1 0.1 0.1],'FaceAlpha',errorOpacity,'EdgeColor','none');
% % fill(xBounds,powBound(:,6),[0.1 0.1 0.1],'FaceAlpha',errorOpacity,'EdgeColor','none');
% % fill(xBounds,powBound(:,7),'b','FaceAlpha',errorOpacity,'EdgeColor','none');
% % fill(xBounds,powBound(:,8),[0.1 0.1 0.1],'FaceAlpha',errorOpacity,'EdgeColor','none');
% % fill(xBounds,powBound(:,9),[0.1 0.1 0.1],'FaceAlpha',errorOpacity,'EdgeColor','none');
% % fill(xBounds,powBound(:,10),'k','FaceAlpha',errorOpacity,'EdgeColor','none');
% % fill(xBounds,powBound(:,11),'m','FaceAlpha',errorOpacity,'EdgeColor','none');
% xlim([0.88 2.7])
% xlabel('$k$')
% ylabel('$C_P$')
% legend([p0 p1 p2 p3 p4 p5 p6 p7 p8 p9 p10],'Location','northwest')
% % title('All Power Coefficients vs Reduced Frequency')
% 

% figure()
% hold on
% tP0 = plot(meanPitch,thrustCoeffMean(1,:),'-or', 'DisplayName',"$k$ 0.89",'LineWidth',2);
% tP1 = plot(meanPitch,thrustCoeffMean(2,:),'--+g', 'DisplayName',"$k$ 1.11",'LineWidth',2);
% tP2 = plot(meanPitch,thrustCoeffMean(3,:),':*b', 'DisplayName',"$k$ 1.34",'LineWidth',2);
% tP3 = plot(meanPitch,thrustCoeffMean(4,:),'-.xk', 'DisplayName',"$k$ 1.56",'LineWidth',2);
% tP4 = plot(meanPitch,thrustCoeffMean(5,:),'-squarem', 'DisplayName',"$k$ 1.78",'LineWidth',2);
% tP5 = plot(meanPitch,thrustCoeffMean(6,:),'--diamondr', 'DisplayName',"$k$ 2.00",'LineWidth',2);
% tP6 = plot(meanPitch,thrustCoeffMean(7,:),':^g', 'DisplayName',"$k$ 2.23",'LineWidth',2);
% tP7 = plot(meanPitch,thrustCoeffMean(8,:),'-.<b', 'DisplayName',"$k$ 2.45",'LineWidth',2);
% tP8 = plot(meanPitch,thrustCoeffMean(9,:),'->k', 'DisplayName',"$k$ 2.67",'LineWidth',2);
% fill(xBounds2,thrustBound2(:,1),'r','FaceAlpha',errorOpacity,'EdgeColor','none');
% fill(xBounds2,thrustBound2(:,2),'g','FaceAlpha',errorOpacity,'EdgeColor','none');
% fill(xBounds2,thrustBound2(:,3),'b','FaceAlpha',errorOpacity,'EdgeColor','none');
% fill(xBounds2,thrustBound2(:,4),'k','FaceAlpha',errorOpacity,'EdgeColor','none');
% fill(xBounds2,thrustBound2(:,5),'m','FaceAlpha',errorOpacity,'EdgeColor','none');
% fill(xBounds2,thrustBound2(:,6),'r','FaceAlpha',errorOpacity,'EdgeColor','none');
% fill(xBounds2,thrustBound2(:,7),'g','FaceAlpha',errorOpacity,'EdgeColor','none');
% fill(xBounds2,thrustBound2(:,8),'b','FaceAlpha',errorOpacity,'EdgeColor','none');
% fill(xBounds2,thrustBound2(:,9),'k','FaceAlpha',errorOpacity,'EdgeColor','none');
% xlabel('$\overline{\theta}$ ($^\circ$)')
% ylabel('$C_T$')
% legend([tP0 tP1 tP2 tP3 tP4 tP5 tP6 tP7 tP8],'Location','northeast')
% % title('All Thust Coefficients vs $\overline{\theta}$')
% 
% 
% figure()
% hold on
% lP0 = plot(meanPitch,liftCoeffMean(1,:),'-or', 'DisplayName',"$k$ 0.89",'LineWidth',2);
% lP1 = plot(meanPitch,liftCoeffMean(2,:),'--+g', 'DisplayName',"$k$ 1.11",'LineWidth',2);
% lP2 = plot(meanPitch,liftCoeffMean(3,:),':*b', 'DisplayName',"$k$ 1.34",'LineWidth',2);
% lP3 = plot(meanPitch,liftCoeffMean(4,:),'-.xk', 'DisplayName',"$k$ 1.56",'LineWidth',2);
% lP4 = plot(meanPitch,liftCoeffMean(5,:),'-squarem', 'DisplayName',"$k$ 1.78",'LineWidth',2);
% lP5 = plot(meanPitch,liftCoeffMean(6,:),'--diamondr', 'DisplayName',"$k$ 2.00",'LineWidth',2);
% lP6 = plot(meanPitch,liftCoeffMean(7,:),':^g', 'DisplayName',"$k$ 2.23",'LineWidth',2);
% lP7 = plot(meanPitch,liftCoeffMean(8,:),'-.<b', 'DisplayName',"$k$ 2.45",'LineWidth',2);
% lP8 = plot(meanPitch,liftCoeffMean(9,:),'->k', 'DisplayName',"$k$ 2.67",'LineWidth',2);
% fill(xBounds2,liftBound2(:,1),'r','FaceAlpha',errorOpacity,'EdgeColor','none');
% fill(xBounds2,liftBound2(:,2),'g','FaceAlpha',errorOpacity,'EdgeColor','none');
% fill(xBounds2,liftBound2(:,3),'b','FaceAlpha',errorOpacity,'EdgeColor','none');
% fill(xBounds2,liftBound2(:,4),'k','FaceAlpha',errorOpacity,'EdgeColor','none');
% fill(xBounds2,liftBound2(:,5),'m','FaceAlpha',errorOpacity,'EdgeColor','none');
% fill(xBounds2,liftBound2(:,6),'r','FaceAlpha',errorOpacity,'EdgeColor','none');
% fill(xBounds2,liftBound2(:,7),'g','FaceAlpha',errorOpacity,'EdgeColor','none');
% fill(xBounds2,liftBound2(:,8),'b','FaceAlpha',errorOpacity,'EdgeColor','none');
% fill(xBounds2,liftBound2(:,9),'k','FaceAlpha',errorOpacity,'EdgeColor','none');
% xlabel('$\overline{\theta}$ ($^\circ$)')
% ylabel('$C_L$')
% legend([lP0 lP1 lP2 lP3 lP4 lP5 lP6 lP7 lP8],'Location','northwest')
% % title('All Lift Coefficients vs $\overline{\theta}$')
% 
% 
% figure()
% hold on
% pP0 = plot(meanPitch,powCoeffMean(1,:),'-or', 'DisplayName',"$k$ 0.89",'LineWidth',2);
% pP1 = plot(meanPitch,powCoeffMean(2,:),'--+g', 'DisplayName',"$k$ 1.11",'LineWidth',2);
% pP2 = plot(meanPitch,powCoeffMean(3,:),':*b', 'DisplayName',"$k$ 1.34",'LineWidth',2);
% pP3 = plot(meanPitch,powCoeffMean(4,:),'-.xk', 'DisplayName',"$k$ 1.56",'LineWidth',2);
% pP4 = plot(meanPitch,powCoeffMean(5,:),'-squarem', 'DisplayName',"$k$ 1.78",'LineWidth',2);
% pP5 = plot(meanPitch,powCoeffMean(6,:),'--diamondr', 'DisplayName',"$k$ 2.00",'LineWidth',2);
% pP6 = plot(meanPitch,powCoeffMean(7,:),':^g', 'DisplayName',"$k$ 2.23",'LineWidth',2);
% pP7 = plot(meanPitch,powCoeffMean(8,:),'-.<b', 'DisplayName',"$k$ 2.45",'LineWidth',2);
% pP8 = plot(meanPitch,powCoeffMean(9,:),'->k', 'DisplayName',"$k$ 2.67",'LineWidth',2);
% % fill(xBounds2,powBound2(:,1),'r','FaceAlpha',errorOpacity,'EdgeColor','none');
% % fill(xBounds2,powBound2(:,2),[0.1 0.1 0.1],'FaceAlpha',errorOpacity,'EdgeColor','none');
% % fill(xBounds2,powBound2(:,3),[0.1 0.1 0.1],'FaceAlpha',errorOpacity,'EdgeColor','none');
% % fill(xBounds2,powBound2(:,4),'g','FaceAlpha',errorOpacity,'EdgeColor','none');
% % fill(xBounds2,powBound2(:,5),[0.1 0.1 0.1],'FaceAlpha',errorOpacity,'EdgeColor','none');
% % fill(xBounds2,powBound2(:,6),[0.1 0.1 0.1],'FaceAlpha',errorOpacity,'EdgeColor','none');
% % fill(xBounds2,powBound2(:,7),'b','FaceAlpha',errorOpacity,'EdgeColor','none');
% % fill(xBounds2,powBound2(:,8),'k','FaceAlpha',errorOpacity,'EdgeColor','none');
% % fill(xBounds2,powBound2(:,9),'m','FaceAlpha',errorOpacity,'EdgeColor','none');
% xlabel('$\overline{\theta}$ ($^\circ$)')
% ylabel('$C_P$')
% legend([pP0 pP1 pP2 pP3 pP4 pP5 pP6 pP7 pP8],'Location','northeast')
% % title('All Power Coefficients vs $\overline{\theta}$')