imgLoc = ['C:\Users\James\OneDrive - ' ... % Location to export figures
    'University of Calgary\Thesis\Calibration Images\'];

% Folders containing data sets
regFolderPath = ["Run 1\" "Run 2\" "Run 3\" "Run 4\" "Run 5\"...
                "Run 6\" "Run 7\" "Run 8\" "Run 9\"];

% Data sets from flapping wing for comparison of power
folderPath = ["..\Space 1\" "..\Space 2\" "..\Space 3\" "..\Space 4\"...
    "..\Space 5\" "..\Space 6\" "..\Space 7\" "..\Space 8\" "..\Space 9\"];

subFolderPath = ["0Mean\" "1Mean\" "2Mean\" "3Mean\" "4Mean\" "5Mean\"...
    "6Mean\" "7Mean\" "8Mean\" "9Mean\" "10Mean\"];

% Number of cycles conducted and how many to remove on either end
cycs = 70;
removeStartCyc = 10;
removeFinCyc = 5;
keptCycs = cycs-removeStartCyc-removeFinCyc;

% Max torque of the motors
torMax = 7.4;

% Empty containers for results
powCoeff = zeros(9,11,9);
testCoeff = zeros(21,9);

% Loop to process the flapping wing power data
for spaceNum=1:numel(folderPath)

    % Create list of folders
    path = folderPath(spaceNum)+subFolderPath;

    % Loop to process data in all folders
    for folNum=1:numel(path)

        % List of files in this folder and convert to table
        motorFiles = dir(fullfile(path(folNum),'*.csv'));
        motorFiles = struct2table(motorFiles);

        % Empty containers to hold results for all of the files in this
        % folder
        pitchPos = cell(length(motorFiles.name)/2,1);
        pitchVel = cell(length(motorFiles.name)/2,1);
        pitchTor = cell(length(motorFiles.name)/2,1);
        strokePos = cell(length(motorFiles.name)/2,1);
        strokeVel = cell(length(motorFiles.name)/2,1);
        strokeTor = cell(length(motorFiles.name)/2,1);
        pitchCosPar = zeros(length(motorFiles.name)/2,4);
        strCosPar = zeros(length(motorFiles.name)/2,4);
        meanCP = zeros(1,length(motorFiles.name)/2);
        phasePower = cell(length(motorFiles.name)/2,1);

        % Loop to process each test condition
        for i=1:length(motorFiles.name)/2
            
            % Load the pitch motor data
            tempMotorData1 = ...
                load(fullfile(path(folNum),motorFiles.name(i*2-1)));
            % Load the stroke motor data
            tempMotorData2 = ...
                load(fullfile(path(folNum),motorFiles.name(i*2)));

            % Fit the motor data to a cosine curve and interpolate the data
            % onto a common time vector
            [pitchCosPar(i,:),pitchPos{i},pitchVel{i},pitchTor{i}] = ...
                cosRegressApp(tempMotorData1,"pitch");
            [strCosPar(i,:),strokePos{i},strokeVel{i},strokeTor{i}] = ...
                cosRegressApp(tempMotorData2,"stroke");
            
            % Set the frequency to that from the cosine regression of the
            % pitch motor
            freqs = pitchCosPar(:,2);
            
            % Find the lowest time at which all variables had recorded a
            % value
            strokeTimeMin = ...
                max(min(strokeVel{i}.Time),min(strokeTor{i}.Time));
            pitchTimeMin = ...
                max(min(pitchVel{i}.Time),min(pitchTor{i}.Time));
            timeMin = max(strokeTimeMin,pitchTimeMin);

            % Create temp variables to manipulate and remove data from
            % before all variables had started recording
            tempPitchVel = pitchVel{i};
            tempPitchTor = pitchTor{i};
            pitchVelRemove = tempPitchVel.Time >= timeMin;
            pitchTorRemove = tempPitchTor.Time >= timeMin;
            tempPitchVel(~pitchVelRemove,:) = [];
            tempPitchTor(~pitchTorRemove,:) = [];

            % Find the common stopping point for the pitch motor
            pitchStop = ...
                min(length(tempPitchVel.Vel),length(tempPitchTor.Tor));
            % Calculate power for pitch motor at common timing points
            pitchPow = ...
                tempPitchVel.Vel(1:pitchStop).*...
                tempPitchTor.Tor(1:pitchStop);
            
            % Create temp variables to manipulate and remove data from
            % before all variables had started recording
            tempStrVel = strokeVel{i};
            tempStrTor = strokeTor{i};
            strokeVelRemove = tempPitchVel.Time >= timeMin;
            strokeTorRemove = tempPitchTor.Time >= timeMin;
            tempStrVel(~strokeVelRemove,:) = [];
            tempStrTor(~strokeTorRemove,:) = [];

            % Find the common stopping point for the stroke motor
            strokeStop = ...
                min(length(tempStrVel.Vel),length(tempStrTor.Tor));
            % Calculate power for stroke motor at common timing points
            strokePow = ...
                tempStrVel.Vel(1:strokeStop).*...
                tempStrTor.Tor(1:strokeStop);
            
            % Find the common stopping point of pitch and stroke power
            powStop = min(pitchStop,strokeStop);
            % Store the total power as the sum of both pitch and stroke
            % power
            CP = zeros(powStop,2);
            CP(:,1) = pitchVel{i}.Time(1:powStop);
            CP(:,2) = (strokePow(1:powStop)+pitchPow(1:powStop));
            
            % Remove starting and stopping cycles from total power time
            % series and set first data point as t=0
            startRemoveTime = removeStartCyc/pitchCosPar(i,2);
            finRemoveTime = (cycs-removeFinCyc)/pitchCosPar(i,2);
            toDelete = ...
                CP(:,1) <= startRemoveTime | CP(:,1) >= finRemoveTime;
            CPkept = CP(~toDelete,:);
            CPkept(:,1) = CPkept(:,1)-CPkept(1,1);

            % Phase average the kept power cycles and calc mean power
            phasePower{i} = phaseAvgPow(CPkept,keptCycs,pitchCosPar(i,2));
            meanCP(i) = mean(CPkept(:,2));
            
            % Clear temp variables
            clear temp*
        end     
        % Store the mean power
        powCoeff(:,folNum,spaceNum) = meanCP;
    end

end

% Loop to process the frictional power loss data
for spaceNum=1:numel(regFolderPath)
    
    % Create list of files in the folder
    path = regFolderPath(spaceNum);
    motorFiles = dir(fullfile(path,'*.csv'));
    motorFiles = struct2table(motorFiles);

    % Empty containers to hold results for all of the files in this folder
    pPosTest = cell(length(motorFiles.name)/2,1);
    pVelTest = cell(length(motorFiles.name)/2,1);
    pTorTest = cell(length(motorFiles.name)/2,1);
    stPosTest = cell(length(motorFiles.name)/2,1);
    stVelTest = cell(length(motorFiles.name)/2,1);
    stTorTest = cell(length(motorFiles.name)/2,1);
    pCosParTest = zeros(length(motorFiles.name)/2,4);
    stCosParTest = zeros(length(motorFiles.name)/2,4);
    meanCP = zeros(1,length(motorFiles.name)/2);
    phasePower = cell(length(motorFiles.name)/2,1);

    % Loop to process each frequency
    for i=1:length(motorFiles.name)/2

        % Load the pitch motor data
        tempMotorData1 = load(fullfile(path,motorFiles.name(i*2-1)));
        % Load the stroke motor data
        tempMotorData2 = load(fullfile(path,motorFiles.name(i*2)));

        % Fit the motor data to a cosine curve and interpolate the data
        % onto a common time vector
        [pCosParTest(i,:),pPosTest{i},pVelTest{i},pTorTest{i}] = ...
            cosRegressApp(tempMotorData1,"pitch");
        [stCosParTest(i,:),stPosTest{i},stVelTest{i},stTorTest{i}] = ...
            cosRegressApp(tempMotorData2,"stroke");

        % Set the frequency to that from the cosine regression of the
        % pitch motor
        testFreqs = pCosParTest(:,2);

        % Find the lowest time at which all variables had recorded a value
        strokeTimeMin = max(min(stVelTest{i}.Time),min(stTorTest{i}.Time));
        pitchTimeMin = max(min(pVelTest{i}.Time),min(pTorTest{i}.Time));
        timeMin = max(strokeTimeMin,pitchTimeMin);
        
        % Create temp variables to manipulate and remove data from
        % before all variables had started recording
        tempPitchVel = pVelTest{i};
        tempPitchTor = pTorTest{i};
        pitchVelRemove = tempPitchVel.Time >= timeMin;
        pitchTorRemove = tempPitchTor.Time >= timeMin;
        tempPitchVel(~pitchVelRemove,:) = [];
        tempPitchTor(~pitchTorRemove,:) = [];

        % Find the common stopping point for the pitch motor
        pitchStop = ...
            min(length(tempPitchVel.Vel),length(tempPitchTor.Tor));
        pitchPow = ...
            tempPitchVel.Vel(1:pitchStop).*tempPitchTor.Tor(1:pitchStop);

        % Create temp variables to manipulate and remove data from
        % before all variables had started recording
        tempStrVel = stVelTest{i};
        tempStrTor = stTorTest{i};
        strokeVelRemove = tempPitchVel.Time >= timeMin;
        strokeTorRemove = tempPitchTor.Time >= timeMin;
        tempStrVel(~strokeVelRemove,:) = [];
        tempStrTor(~strokeTorRemove,:) = [];

        % Find the common stopping point for the stroke motor
        strokeStop = ...
            min(length(tempStrVel.Vel),length(tempStrTor.Tor));
        strokePow = ...
            tempStrVel.Vel(1:strokeStop).*tempStrTor.Tor(1:strokeStop);
        
        % Find the common stopping point of pitch and stroke power
        powStop = min(pitchStop,strokeStop);

        % Store the total power as the sum of both pitch and stroke power
        CP = zeros(powStop,2);
        CP(:,1) = pVelTest{i}.Time(1:powStop);
        CP(:,2) = (strokePow(1:powStop)+pitchPow(1:powStop));

        % Remove starting and stopping cycles from total power time
        % series and set first data point as t=0
        startRemoveTime = removeStartCyc/pCosParTest(i,2);
        finRemoveTime = (cycs-removeFinCyc)/pCosParTest(i,2);
        toDelete = CP(:,1) <= startRemoveTime | CP(:,1) >= finRemoveTime;
        CPkept = CP(~toDelete,:);
        CPkept(:,1) = CPkept(:,1)-CPkept(1,1);

        % Phase average the kept power cycles and calc mean power
        phasePower{i} = phaseAvgPow(CPkept,keptCycs,pCosParTest(i,2));
        meanCP(i) = mean(CPkept(:,2));
        
        % Figures for example of phase averaged position
        if i==17 && spaceNum == 6
            
            % Removing starting and stopping cycles from pitch position and
            % setting first data point to t=0
            toDeletePitch = ...
                pPosTest{i}.Time <= startRemoveTime | ...
                pPosTest{i}.Time >= finRemoveTime;
            pos1 = pPosTest{i}.Pos(~toDeletePitch);
            pos1T = pPosTest{i}.Time(~toDeletePitch);
            pos1T = pos1T - pos1T(1);

            % Phase averaging pitch position
            pos = pos1(1:floor(length(pos1)/keptCycs));
            posNonDimT = ...
                pos1T(1:floor(length(pos1T)/keptCycs))*pCosParTest(i,2);
            
            for k=2:keptCycs
                pos2 = pos1((k-1)*length(pos)+1:k*length(pos));
                pos = pos + pos2;
            end
            pos = pos/keptCycs;
            
            % Removing starting and stopping cycles from str position and
            % setting first data point to t=0
            toDeleteStroke = ...
                stPosTest{i}.Time <= startRemoveTime | ...
                stPosTest{i}.Time >= finRemoveTime;
            str1 = stPosTest{i}.Pos(~toDeleteStroke);
            str1T = stPosTest{i}.Time(~toDeleteStroke);
            str1T = str1T-str1T(1);

            % Phase averaging stroke position
            str = str1(1:floor(length(str1)/keptCycs));
            strNonDimT = ...
                str1T(1:floor(length(str1T)/keptCycs))*stCosParTest(i,2);
            
            for k=2:keptCycs
                str2 = str1((k-1)*length(str)+1:k*length(str));
                str = str + str2;
            end
            str = str/keptCycs;
            
            % Figure containing phase avg. stroke and pitch positions
            figure()
            hold on
            plot(posNonDimT,pos,DisplayName='Averaged Pitch Cycle')
            plot(strNonDimT,str,DisplayName='Averaged Stroke Cycle')
            xlim([0 1])
            xlabel('$t/\tau$')
            ylabel('Position ($^\circ$)')
            legend()
            myExportGraphics(gcf,'powAvgPosCyc.eps',imgLoc)
        end
        % Clear temp variables and store mean power
        clear temp*
        testCoeff(:,spaceNum) = meanCP;
    end

end

% Calculate the mean power for a test condition
powCoeffMean = mean(powCoeff,3);
testCoeffMean = mean(testCoeff,2);

%%

% Create figures for thesis
figure()
hold on
p0 = plot(...
    freqs,powCoeffMean(:,1),...
    '-or',...
    'DisplayName',...
    "$\overline{P}$ at $\overline{\theta}=0$",...
    'LineWidth',2 ...
    );
s1 = scatter(...
    testFreqs,...
    testCoeff(:,1),...
    'b',...
    DisplayName='$\overline{P}_{loss}$ of Individual Tests'...
    );
scatter(testFreqs,testCoeff(:,2:end),'b',HandleVisibility='off')
p11 = plot(...
    testFreqs,...
    testCoeffMean,...
    '--ok',...
    'DisplayName',...
    'Average $\overline{P}_{loss}$'...
    );
xlim([0 8])
xlabel('$f$ (Hz)')
ylabel('$\overline{P}$ ($W$)')
legend([p0 s1 p11],'Location','northwest')
myExportGraphics(gcf,'fricLossesExamp.eps',imgLoc)

figure()
hold on
scatter(testFreqs,testCoeff(:,1),'b',DisplayName='Individual Test Mean')
scatter(testFreqs,testCoeff(:,2:end),'b',HandleVisibility='off')
p11 = plot(...
    testFreqs,...
    testCoeffMean,...
    '-ok',...
    'DisplayName',...
    'Average Mean Power'...
    );
xlim([0 8])
xlabel('$f$ (Hz)')
ylabel('$\overline{P}$ ($W$)')
legend('Location','northwest')
myExportGraphics(gcf,'fricLosses.eps',imgLoc)