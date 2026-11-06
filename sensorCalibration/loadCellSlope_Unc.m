sensor = ["G1232" "K7801"]; % Folder Names
imgLoc = ['C:\Users\James\OneDrive - ' ... % Location to export figures
    'University of Calgary\Thesis\Calibration Images\'];


% Scales provide force in units of mass
% Assuming kitchen scale would use 9.81 to go from force to mass so this
% code uses 9.81 to go from mass back to force
grav = 9.81;

uncOpacity = 0.25; % Transparency of the uncertainty region

dUnc = 0.378; % Uncertainty in mounting angle (degrees)
dRad = deg2rad(dUnc);

% Creating list of all of the .mat data files in the two directories
dataSets1 = dir(fullfile(sensor(1),'*.mat'));
dataSets1 = struct2table(dataSets1);

dataSets2 = dir(fullfile(sensor(2),'*.mat'));
dataSets2 = struct2table(dataSets2);

% Creating empty container to hold the processing results
dataLength = length(dataSets1.name)+length(dataSets2.name);
dataTable = zeros(dataLength,13);
dataTable = array2table(dataTable);
dataTable.Properties.VariableNames = ...
    {'Sensor' 'Run' 'Axis' 'Direction' 'Un/Load' 'Mass' 'Force'...
    'XVoltage' 'xStd' 'YVoltage' 'yStd' 'ZVoltage' 'zStd'};
dataTable = ...
    convertvars(...
        dataTable,...
        ["Sensor" "Axis" "Direction" "Un/Load"],...
        'string'...
    );

tracker = 0; % Track number of loops for indexing purposes

% Looping through all the data files and processing them
for sensorNum = 1:length(sensor)
    % Load list of .mat data files in folder number sensorNum
    tempDataSet = dir(fullfile(sensor(sensorNum),'*.mat'));
    % Converting to table for ease of use
    tempDataSet = struct2table(tempDataSet);
    % Looping through the files in the folder and processing
    for setNum = 1:length(tempDataSet.name)
        % Load file setNum from list
        tempData = ...
            load(fullfile(sensor(sensorNum),tempDataSet.name(setNum)));
        % Creating variable containing the file name because the file names
        % contain information about the test and change what data channels
        % to use
        fileName = tempDataSet.name(setNum);
        if sensor(sensorNum) == "G1232"
            dataTable.Sensor(setNum+tracker) = "G1232";
            X = tempData.dataCh0;
            Y = tempData.dataCh1;
            Z = tempData.dataCh2;
        elseif sensor(sensorNum) == "K7801"
            dataTable.Sensor(setNum+tracker) = "K7801";
            X = tempData.dataCh3;
            Y = tempData.dataCh4;
            Z = tempData.dataCh5;
        end
        % Data was collected for a minimum of 7s at 2000Hz, mean of these
        % trials is used for slope calculation
        meanX = mean(X);
        meanY = mean(Y);
        meanZ = mean(Z);

        % Extract information from the file name
        direction = extractBefore(fileName,',');
        fileName = extractAfter(fileName,',');
        axis = extractBefore(fileName,',');
        fileName = extractAfter(fileName,',');
        runNum = extractBefore(fileName,',');
        fileName = extractAfter(fileName,',');
        un_Load = extractBefore(fileName,',');
        fileName = extractAfter(fileName,',');
        mass = str2double(extractBefore(fileName,'.'))/1000;
        
        % Setting the voltage measurement when nothing was attached to the
        % load cell as the zero point. Ie. the voltage differences from the
        % bias are used to calculate the linear function to convert from
        % volts to newtons
        if mass == 0 && un_Load == "Lo"
            biasX = meanX;
            biasY = meanY;
            biasZ = meanZ;
        end
        
        % Storing the run number and axis that was loaded
        dataTable.Run(setNum+tracker) = ...
            str2double(extractAfter(runNum,'R'));
        dataTable.Axis(setNum+tracker) = axis;
        
        % Storing if the test was in the positive or negative direction of
        % the load cell and if the test was adding (loading) or removing
        % (unloading) mass from the load cell
        if direction == "Pos"
            dataTable.Direction(setNum+tracker) = "Positive";
        elseif direction == "Neg"
            dataTable.Direction(setNum+tracker) = "Negative";
            mass = mass*-1;
        end
        if un_Load == "Lo"
            dataTable.("Un/Load")(setNum+tracker) = 'Load';
        elseif un_Load == "Un"
            dataTable.("Un/Load")(setNum+tracker) = 'Unload';
        end

        % Storing the mass, "true" force, and the voltages measured
        dataTable.Mass(setNum+tracker) = mass;
        dataTable.Force(setNum+tracker) = mass*grav;
        dataTable.XVoltage(setNum+tracker) = meanX-biasX;
        dataTable.xStd(setNum+tracker) = std(X);
        dataTable.YVoltage(setNum+tracker) = meanY-biasY;
        dataTable.yStd(setNum+tracker) = std(Y);
        dataTable.ZVoltage(setNum+tracker) = meanZ-biasZ;
        dataTable.zStd(setNum+tracker) = std(Z);
    end
    % Updating where in the data table the results should continue being
    % stored
    tracker = tracker+setNum;
end

% Loading data from a calibration that did not have the pull down circuit
% attached for comparison
KPreCal = load("K7801PreCal.mat");
GPreCal = load("G1232PreCal.mat");

% Fitting linear line to the X and Y axes based on all data for that axis
% and creating lines for plotting (__Vals)
KXIndices = dataTable.Sensor=="K7801" & dataTable.Axis=="X";
KXSlope = ...
    polyfit(dataTable.XVoltage(KXIndices),dataTable.Force(KXIndices),1);
KXVals = polyval(KXSlope,dataTable.XVoltage(KXIndices));
KXPreVals = polyval(KPreCal.fitX,KPreCal.XData(:,1));

KYIndices = dataTable.Sensor=="K7801" & dataTable.Axis=="Y";
KYSlope = ...
    polyfit(dataTable.YVoltage(KYIndices),dataTable.Force(KYIndices),1);
KYVals = polyval(KYSlope,dataTable.YVoltage(KYIndices));
KYPreVals = polyval(KPreCal.fitY,KPreCal.YData(:,2));

GXIndices = dataTable.Sensor=="G1232" & dataTable.Axis=="X";
GXSlope = ...
    polyfit(dataTable.XVoltage(GXIndices),dataTable.Force(GXIndices),1);
GXVals = polyval(GXSlope,dataTable.XVoltage(GXIndices));
GXPreVals = polyval(GPreCal.fitX,GPreCal.XData(:,1));

GYIndices = dataTable.Sensor=="G1232" & dataTable.Axis=="Y";
GYSlope = ...
    polyfit(dataTable.YVoltage(GYIndices),dataTable.Force(GYIndices),1);
GYVals = polyval(GYSlope,dataTable.YVoltage(GYIndices));
GYPreVals = polyval(GPreCal.fitY,GPreCal.YData(:,2));

% Calculating percent change in slope from adding pull down circuit 
KXDif = (KXSlope(1)-KPreCal.fitX(1))*100/KPreCal.fitX(1);
KYDif = (KYSlope(1)-KPreCal.fitY(1))*100/KPreCal.fitY(1);
GXDif = (GXSlope(1)-GPreCal.fitX(1))*100/GPreCal.fitX(1);
GYDif = (GYSlope(1)-GPreCal.fitY(1))*100/GPreCal.fitY(1);

% Creating list of runs conducted
runs = unique(dataTable.Run);

% Empty containers to hold individual results of each run and overall
% Overall will be contained in the final index
% Slopes
GX_Fits = cell(length(runs)+1,3);
GY_Fits = cell(length(runs)+1,3);
KX_Fits = cell(length(runs)+1,3);
KY_Fits = cell(length(runs)+1,3);

% Hysteresis
GX_Hyst = cell(length(runs)+1,3);
GY_Hyst = cell(length(runs)+1,3);
KX_Hyst = cell(length(runs)+1,3);
KY_Hyst = cell(length(runs)+1,3);

% Creating figures to fill in the upcoming loop
volts = -10:0.1:10;
fig1 = figure(name='GX');
axGX = axes;
legend('Location','southeast');
xlim([-10 10])
ylim([-310 310])
xlabel('Measured Voltage (V)')
ylabel('Force Applied (N)')

fig2 = figure(Name='GY');
axGY = axes;
legend('Location','southeast');
xlim([-10 10])
ylim([-310 310])
xlabel('Measured Voltage (V)')
ylabel('Force Applied (N)')

fig3 = figure(Name='KX');
axKX = axes;
legend('Location','southeast');
xlim([-10 10])
ylim([-310 310])
xlabel('Measured Voltage (V)')
ylabel('Force Applied (N)')

fig4 = figure(Name='KY');
axKY = axes;
legend('Location','southeast');
xlim([-10 10])
ylim([-310 310])
xlabel('Measured Voltage (V)')
ylabel('Force Applied (N)')

% Style lists for markers
markType = ["o" "+" "*" "x" "square" "diamond" "^" "<" ">"...
    "pentagram" "hexagram"];
colorType = ["r" "g" "b" "k" "m" "r" "g" "b" "k" "m" "r"];

% Loop to create the plots and create fit functions for the individual runs
for i=1:length(runs)+1

    if i==length(runs)+1 % Plotting the overall results
        % Custom function for plotting and finding the fit parameters
        [GX_Fits(i,1), GX_Fits(i,2), GX_Fits(i,3)] = ...
            plotLC(dataTable,"G1232",'all',"X","Load");
        [GY_Fits(i,1), GY_Fits(i,2), GY_Fits(i,3)] = ...
            plotLC(dataTable,"G1232",'all',"Y","Load");
        [KX_Fits(i,1), KX_Fits(i,2), KX_Fits(i,3)] = ...
            plotLC(dataTable,"K7801",'all',"X","Load");
        [KY_Fits(i,1), KY_Fits(i,2), KY_Fits(i,3)] = ...
            plotLC(dataTable,"K7801",'all',"Y","Load");

        % Data points to plot the conversion function based on all of the
        % runs (except GX where there was an outlier, outlier is skipped in
        % the plotLC function)
        GXPredict = polyval(GX_Fits{i,1}, volts);
        GYPredict = polyval(GY_Fits{i,1}, volts);
        KXPredict = polyval(KX_Fits{i,1}, volts);
        KYPredict = polyval(KY_Fits{i,1}, volts);
        
        % tVals for 7(GX) and 8(rest) degrees of freedom (dof = #tests - 1)
        tVGX = 2.365; % tval for 7dof 95% confidence of two tail test
        tV = 2.306; % tval for 8dof 95% confidence of two tail test

        % Collect the slopes from the seperate runs
        gxSlopes = cellfun(@(x) x(1), GX_Fits(:, 1));
        gySlopes = cellfun(@(x) x(1), GY_Fits(:, 1));
        kxSlopes = cellfun(@(x) x(1), KX_Fits(:, 1));
        kySlopes = cellfun(@(x) x(1), KY_Fits(:, 1));

        % Collect the intercepts from the seperate runs
        gxInter = cellfun(@(x) x(2), GX_Fits(:, 1));
        gyInter = cellfun(@(x) x(2), GY_Fits(:, 1));
        kxInter = cellfun(@(x) x(2), KX_Fits(:, 1));
        kyInter = cellfun(@(x) x(2), KY_Fits(:, 1));

        % Uncertainty in the slopes and intercepts
        bGX = tVGX*std(gxSlopes(2:9))/sqrt(length(gxSlopes(2:9)));
        bGY = tV*std(gySlopes(1:9))/sqrt(length(gySlopes(1:9)));
        bKX = tV*std(kxSlopes(1:9))/sqrt(length(kxSlopes(1:9)));
        bKY = tV*std(kySlopes(1:9))/sqrt(length(kySlopes(1:9)));

        aGX = tVGX*std(gxInter(2:9))/sqrt(length(gxInter(2:9)));
        aGY = tV*std(gyInter(1:9))/sqrt(length(gyInter(1:9)));
        aKX = tV*std(kxInter(1:9))/sqrt(length(kxInter(1:9)));
        aKY = tV*std(kyInter(1:9))/sqrt(length(kyInter(1:9)));

        % Uncertainty bounds for the overall slope
        voltBounds = [volts';flipud(volts')];
        gxUnc = ...
            sqrt(...
                (10/cos(dRad)).^2*bGX^2+ ... % Unc in slope
                (1/cos(dRad))^2*aGX^2+ ... % Unc in intercept
                (max(GXPredict)*sin(dRad)/cos(dRad)^2).^2*dRad^2);
                % ^ Unc in mounting angle
        gyUnc = ...
            sqrt(...
                (10/cos(dRad)).^2*bGY^2+ ...cosd
                (1/cos(dRad))^2*aGY^2+ ...
                (max(GYPredict)*sin(dRad)/cos(dRad)^2).^2*dRad^2);
        kxUnc = ...
            sqrt(...
                (10/cos(dRad)).^2*bKX^2+ ...
                (1/cos(dRad))^2*aKY^2+ ...
                (max(KXPredict)*sin(dRad)/cos(dRad)^2).^2*dRad^2);
        kyUnc = ...
            sqrt(...
                (10/cos(dRad)).^2*bKY^2+ ...
                (1/cos(dRad))^2*aKY^2+ ...
                (max(KYPredict)*sin(dRad)/cos(dRad)^2).^2*dRad^2);
        
        captured = 0; % To track the number of data points captured by unc
        capSum = 0; % Total data points captured across all
        
        % Indices in the data table for the different axes during loading
        GXIdx = ...
            dataTable.Sensor=='G1232' & ...
            dataTable.Axis=='X' & ...
            dataTable.("Un/Load")=='Load' & ...
            dataTable.Run~=1;
        GYIdx = ...
            dataTable.Sensor=='G1232' & ...
            dataTable.Axis=='Y' & ...
            dataTable.("Un/Load")=='Load';
        KXIdx = ...
            dataTable.Sensor=='K7801' & ...
            dataTable.Axis=='X' & ...
            dataTable.("Un/Load")=='Load';
        KYIdx = ...
            dataTable.Sensor=='K7801' & ...
            dataTable.Axis=='Y' & ...
            dataTable.("Un/Load")=='Load';

        % Tables containing the seperated data to check if they lay within
        % the uncertainty bounds
        gxUncCheck = dataTable(GXIdx,:);
        gyUncCheck = dataTable(GYIdx,:);
        kxUncCheck = dataTable(KXIdx,:);
        kyUncCheck = dataTable(KYIdx,:);
        
        % All the fits, unc bounds, and seperated data in single cell
        % arrays for looping
        allSlopes = {GX_Fits GY_Fits KX_Fits KY_Fits};
        allUnc = [gxUnc gyUnc kxUnc kyUnc];
        % allUnc = [0.5 0.54 kxUnc kyUnc];
        uncCheck = {gxUncCheck gyUncCheck kxUncCheck kyUncCheck};

        n = ... % Number of loops to conduct
            [length(gxUncCheck.Force) length(gyUncCheck.Force) ...
            length(kxUncCheck.Force) length(kyUncCheck.Force)];
        % To calculate percent of data captured by uncertainty
        perCaptured = zeros(1,length(n));
        % Loop through all 4 numbers in n
        for nIdx = 1:length(n)
            % Resest to calculate for each axis (GX KX GY KY)
            captured = 0;
            % Loop the number of times at n(nIdx)
            for j=1:n(nIdx)
                % Calculate force predicted by the overall conversion fncs
                % If nIdx is odd then xVolt to calculate else yVolt
                if mod(nIdx,2) == 1
                    predicted = ...
                        polyval(...
                            allSlopes{nIdx}{i,1},...
                            uncCheck{nIdx}.XVoltage(j)...
                        );
                    predictedUp = ...
                        polyval(...
                            allSlopes{nIdx}{i,1},...
                            uncCheck{nIdx}.XVoltage(j)+...
                            2*uncCheck{nIdx}.xStd(j)...
                        );
                    predictedDown = ...
                        polyval(...
                            allSlopes{nIdx}{i,1},...
                            uncCheck{nIdx}.XVoltage(j)- ...
                            2*uncCheck{nIdx}.xStd(j)...
                        );
                else
                    predicted = ...
                        polyval(...
                            allSlopes{nIdx}{i,1},...
                            uncCheck{nIdx}.YVoltage(j)...
                        );
                    predictedUp = ...
                        polyval(...
                            allSlopes{nIdx}{i,1},...
                            uncCheck{nIdx}.YVoltage(j)+ ...
                            2*uncCheck{nIdx}.yStd(j)...
                        );
                    predictedDown = ...
                        polyval(...
                            allSlopes{nIdx}{i,1},...
                            uncCheck{nIdx}.YVoltage(j)- ...
                            2*uncCheck{nIdx}.yStd(j)...
                        );
                end
                % If the actual measurement fits within the uncertainty
                % bounds then add 1 to the captured data points
                if uncCheck{nIdx}.Force(j) <= predicted+allUnc(nIdx) &&...
                        uncCheck{nIdx}.Force(j) >= predicted-allUnc(nIdx)
                    captured = captured+1;
                elseif uncCheck{nIdx}.Force(j)<=predictedUp+allUnc(nIdx)...
                        && uncCheck{nIdx}.Force(j) >=...
                        predictedUp-allUnc(nIdx)
                    captured = captured+1;
                elseif uncCheck{nIdx}.Force(j) <= ...
                        predictedDown+allUnc(nIdx) &&...
                        uncCheck{nIdx}.Force(j) >= ...
                        predictedDown-allUnc(nIdx)
                    captured = captured+1;
                end
            end
            % Add the number of points captured for this axis to the
            % overall total
            capSum = capSum+captured;
            % Calculate the percent captured for this axis
            perCaptured(nIdx) = captured/n(nIdx);
        end

        % Calculate the total percent of points captured
        totPerCaptur = capSum/sum(n);
        
        % Bounds for the uncertainty area
        gxBounds = [GXPredict'+gxUnc';flipud(GXPredict'-gxUnc')];
        gyBounds = [GYPredict'+gyUnc';flipud(GYPredict'-gyUnc')];
        kxBounds = [KXPredict'+kxUnc';flipud(KXPredict'-kxUnc')];
        kyBounds = [KYPredict'+kyUnc';flipud(KYPredict'-kyUnc')];

        % Calculating slopes for the unloading data points for hysteresis
        % calculation
        [GX_Hyst(i,1), GX_Hyst(i,2), GX_Hyst(i,3)] = ...
            plotLC(dataTable,"G1232",'all',"X","Unload");
        [GY_Hyst(i,1), GY_Hyst(i,2), GY_Hyst(i,3)] = ...
            plotLC(dataTable,"G1232",'all',"Y","Unload");
        [KX_Hyst(i,1), KX_Hyst(i,2), KX_Hyst(i,3)] = ...
            plotLC(dataTable,"K7801",'all',"X","Unload");
        [KY_Hyst(i,1), KY_Hyst(i,2), KY_Hyst(i,3)] = ....
            plotLC(dataTable,"K7801",'all',"Y","Unload");
        
        % No pull down resistor slope as evidence outlier for GX was likely
        % due to pull down resistor being disconnected
        plot(axGX,GPreCal.XData(:,1),GXPreVals,'r','DisplayName',...
            'Slope w/o pull down resistors',LineWidth=2)
        % Plotting overall slope lines and uncertainty bounds
        plot(axGX,volts,GXPredict,'b','DisplayName',...
            'Slope w/ pull down resistors',LineWidth=2)
        fill(axGX,voltBounds,gxBounds,'b','FaceAlpha',uncOpacity,...
            'EdgeColor','none','HandleVisibility','off');

        plot(axGY,volts,GYPredict,'b','DisplayName',...
            'Slope w/ pull down resistors',LineWidth=2)
        fill(axGY,voltBounds,gyBounds,'b','FaceAlpha',uncOpacity,...
            'EdgeColor','none','HandleVisibility','off');
        
        plot(axKX,volts,KXPredict,'b','DisplayName',...
            'Slope w/ pull down resistors',LineWidth=2)
        fill(axKX,voltBounds,kxBounds,'b','FaceAlpha',uncOpacity,...
            'EdgeColor','none','HandleVisibility','off');

        plot(axKY,volts,KYPredict,'b','DisplayName',...
            'Slope w/ pull down resistors',LineWidth=2)
        fill(axKY,voltBounds,kyBounds,'b','FaceAlpha',uncOpacity,...
            'EdgeColor','none','HandleVisibility','off');
   
    else
        % Plotting all the individual data points
        figure(fig1);
        hold on
        [GX_Fits(i,1), GX_Fits(i,2), GX_Fits(i,3)] = ...
           plotLC(dataTable,"G1232",i,"X","Load",markType(i)+colorType(i));
        
        figure(fig2);
        hold on
        [GY_Fits(i,1), GY_Fits(i,2), GY_Fits(i,3)] = ...
           plotLC(dataTable,"G1232",i,"Y","Load",markType(i)+colorType(i));
        
        figure(fig3);
        hold on
        [KX_Fits(i,1), KX_Fits(i,2), KX_Fits(i,3)] = ...
           plotLC(dataTable,"K7801",i,"X","Load",markType(i)+colorType(i));
        
        figure(fig4);
        hold on
        [KY_Fits(i,1), KY_Fits(i,2), KY_Fits(i,3)] = ...
           plotLC(dataTable,"K7801",i,"Y","Load",markType(i)+colorType(i));
        
        % Calculating slopes for the unloading data points for hysteresis
        % calculation
        [GX_Hyst(i,1), GX_Hyst(i,2), GX_Hyst(i,3)] = ...
            plotLC(dataTable,"G1232",i,"X","Unload");
        [GY_Hyst(i,1), GY_Hyst(i,2), GY_Hyst(i,3)] = ...
            plotLC(dataTable,"G1232",i,"Y","Unload");
        [KX_Hyst(i,1), KX_Hyst(i,2), KX_Hyst(i,3)] = ...
            plotLC(dataTable,"K7801",i,"X","Unload");
        [KY_Hyst(i,1), KY_Hyst(i,2), KY_Hyst(i,3)] = ...
            plotLC(dataTable,"K7801",i,"Y","Unload");
    end
end

% Export plots
myExportGraphics(fig1,'GX_Full.eps',imgLoc)
myExportGraphics(fig2,'GY_Full.eps',imgLoc)
myExportGraphics(fig3,'KX_Full.eps',imgLoc)
myExportGraphics(fig4,'KY_Full.eps',imgLoc)

% Calculating hysteresis
gxHyst = ...
    (cell2mat(GX_Fits(:,1))-cell2mat(GX_Hyst(:,1)))./...
    cell2mat(GX_Fits(:,1))*100;
gyHyst = ...
    (cell2mat(GY_Fits(:,1))-cell2mat(GY_Hyst(:,1)))./...
    cell2mat(GY_Fits(:,1))*100;
kxHyst = ...
    (cell2mat(KX_Fits(:,1))-cell2mat(KX_Hyst(:,1)))./...
    cell2mat(KX_Fits(:,1))*100;
kyHyst = ...
    (cell2mat(KY_Fits(:,1))-cell2mat(KY_Hyst(:,1)))./...
    cell2mat(KY_Fits(:,1))*100;

% Function for plotting, uses context from arguments
function [slope,slopeRMSE,fit]=plotLC(dataTable,sensor, run, axis,...
                                        hysterersis, mark)
    arguments
        dataTable table
        sensor string
        run string
        axis string
        hysterersis string
        mark string = 'o'
    end
    % Function uses all data points for fitting if run == all
    % except for the outlier run for G1232 X axis
    if strcmpi(run,'all')
        if sensor=="G1232" && axis =="X"
            indices = ...
                dataTable.Sensor==sensor & ...
                dataTable.Axis==axis & ...
                dataTable.("Un/Load")==hysterersis & ...
                dataTable.Run~=1;
        else
            indices = ...
                dataTable.Sensor==sensor & ...
                dataTable.Axis==axis & ...
                dataTable.("Un/Load")==hysterersis;
        end
    % If run ~= all then find the indices for the desired run & other
    % conditions
    else
        indices = ...
            dataTable.Sensor==sensor & ...
            dataTable.Axis==axis & ...
            dataTable.Run==str2double(run) & ...
            dataTable.("Un/Load")==hysterersis;
    end
    % If the axis is Y use the voltages for the y-axis
    if strcmpi(axis,'Y')
        % Create a linear fit function
        slope = ...
            polyfit(...
                dataTable.YVoltage(indices),...
                dataTable.Force(indices),1 ...
            );
        % Create predictions for all the voltages in the dataTable
        predicts = polyval(slope, dataTable.YVoltage(indices));
        % RMSE between actual points and predicted points
        slopeRMSE = rmse(predicts,dataTable.Force(indices));
        % R2 calculation
        fit = 1 - sum((dataTable.Force(indices)-predicts).^2)/...
            sum((dataTable.Force(indices)-...
                    mean(dataTable.Force(indices))).^2);
        % Plot the data points and the uncertainty in the voltage mean
        if ~strcmpi(run,'all') && ~strcmpi(hysterersis,'Unload')
            plot(dataTable.YVoltage(indices),dataTable.Force(indices),...
                mark,DisplayName=sprintf('Run %i', str2double(run)),...
                LineWidth=2)
            errorbar(dataTable.YVoltage(indices),...
                dataTable.Force(indices), 2*dataTable.yStd(indices),...
                'horizontal','LineStyle','none','Marker','none',...
                'Color','k','HandleVisibility','off');
        end
    % If the axis is X use the voltages for the x-axis
    elseif strcmpi(axis,'X')
        slope = ...
            polyfit(...
                dataTable.XVoltage(indices),...
                dataTable.Force(indices),1 ...
            );
        predicts = polyval(slope, dataTable.XVoltage(indices));
        slopeRMSE = rmse(predicts,dataTable.Force(indices));
        fit = 1 - sum((dataTable.Force(indices)-predicts).^2)/...
            sum((dataTable.Force(indices)-...
                    mean(dataTable.Force(indices))).^2);
        if ~strcmpi(run,'all') && ~strcmpi(hysterersis,'Unload')
            plot(dataTable.XVoltage(indices),dataTable.Force(indices),...
                mark,DisplayName=sprintf('Run %i', str2double(run)),...
                LineWidth=2)
            errorbar(dataTable.XVoltage(indices),...
                dataTable.Force(indices), 2*dataTable.xStd(indices), ...
                'horizontal','LineStyle','none','Marker','none',...
                'Color','k','HandleVisibility','off');
        end
    end
    % Return the desired variables
    slope = {slope};
    fit = {fit};
    slopeRMSE = {slopeRMSE};
end