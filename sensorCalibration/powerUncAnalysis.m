imgLoc = ['C:\Users\James\OneDrive - ' ... % Location to export figures
    'University of Calgary\Thesis\Calibration Images\'];

% Folders containing data sets
mainFolder = "3436\";
subFolder = ...
    ["Inertial 1" "Inertial 2" "Inertial 3" "Inertial 4" "Inertial 5"];
Folder = mainFolder+subFolder;

% Number of cycles in each test
cycles = 20;

% Maximum torque of the motor
maxTor_3436 = 7.4;

% Nominal frequencies
startFreq = 0.25; % Hz
freqStep = 0.25; % Hz
endFreq = 10; % Hz
frequencies = startFreq:freqStep:endFreq;

% Inertias (kg.m2)
rotorInert = 0.00021;
mountInert = 0.00001964;
discInert = [0.00014819 0.00031746 0.00059335 0.00101899 0.00232372];

totalInert = discInert+rotorInert+mountInert;

% Variable names for data tables
varNames = ...
    ["Inertia" "Frequency" "dThetaPeak" "ddThetaPeak" "PeakPow" "RMSE"];

% Setting up empty data tables to hold results
powErr = zeros(length(subFolder)*length(frequencies)-1,length(varNames));
powErr = array2table(powErr);
powErr.Properties.VariableNames = varNames;
posErr = renamevars(powErr,'PeakPow','PeakPos');
posErr = removevars(posErr,"ddThetaPeak");

% Setting up empty data tables to hold cosine regression results
cosPar = zeros(length(frequencies),4,length(totalInert));
Pos = cell(length(frequencies),length(totalInert));
Vel = cell(length(frequencies),length(totalInert));
Tor = cell(length(frequencies),length(totalInert));
Pow = cell(length(frequencies),length(totalInert));

posDiff1 = [];
posDiff2 = posDiff1;
posDiff3 = posDiff1;
posDiff4 = posDiff1;
posDiff5 = posDiff1;

% Loop to process data
for i=1:numel(Folder)
    
    % Pull list of data files for a folder
    motorFiles = dir(fullfile(Folder(i),'*.csv'));
    motorFiles = struct2table(motorFiles);

    % Loop to process each file in the folder
    for j = 1:length(motorFiles.name)
        
        % Extract the nominal frequency from the file name
        fileName = motorFiles.name(j);
        freq = extractAfter(fileName,'freq_');
        freq = extractBefore(freq,'Hz');
        freq = str2double(freq);

        % Store the frequency
        powErr.Frequency((i-1)*40+j) = freq;
        posErr.Frequency((i-1)*40+j) = freq;

        % Load the data
        tempMotorData = load(fullfile(Folder(i),motorFiles.name(j)));
        % Custom function to fit the position data to a cosine curve
        % and interpolate data onto a common time vector
        [cosPar(j,:,i),Pos{j,i},Vel{j,i},Tor{j,i}] = ...
            cosRegressPow(tempMotorData,false);
        
        % Find at what time both angular velocity and torque had available
        % data and setup variables to manipulate
        timeMin = max(min(Vel{j,i}.Time),min(Tor{j,i}.Time));
        tempPos = Pos{j,i};
        tempVel = Vel{j,i};
        tempTor = Tor{j,i};
        
        % Remove data points from before all three had started reporting
        % data
        PosRemove = tempPos.Time >= timeMin;
        VelRemove = tempVel.Time >= timeMin;
        TorRemove = tempTor.Time >= timeMin;
        tempPos(~PosRemove,:) = [];
        tempVel(~VelRemove,:) = [];
        tempTor(~TorRemove,:) = [];

        % Find when data first stopped recording (shortest variable)
        tempStop = ...
            min(...
                [...
                    length(tempVel.Vel),...
                    length(tempTor.Tor),...
                    length(tempPos.Pos)...
                ]...
            );
        tempTime = tempVel.Time(1:tempStop);

        % Calculate power using the shared time stamps of the common time
        % vector
        tempPow = tempVel.Vel(1:tempStop).*tempTor.Tor(1:tempStop);
        
        % Calculate the theoretical position based on the cosine curve fit,
        % and calculate RMSE between the theoretical and measured positions
        tempPosTheo = ...
            -cosPar(j,1,i)*...
            cos(2*pi*tempTime*cosPar(j,2,i)+pi/180*cosPar(j,3,i))+...
            deg2rad(cosPar(j,4,i));
        tempPeakPos = max(tempPosTheo);
        tempPosErr = rmse(tempPosTheo,tempPos.Pos(1:tempStop));
        
        % Store calculated position metrics
        posErr.Inertia((i-1)*40+j) = totalInert(i)*1000; % Stored as kg.cm2
        posErr.PeakPos((i-1)*40+j) = tempPeakPos;
        posErr.RMSE((i-1)*40+j) = tempPosErr;
        
        % Calculate theor. peak angular vel and peak angular acc
        tempdTheta = ...
            max(...
                deg2rad(cosPar(j,1,i))*...
                (2*pi*cosPar(j,2,i))*...
                sin(2*pi*tempTime*cosPar(j,2,i)+pi/180*cosPar(j,3,i))...
            );
        tempddTheta = ...
            max(...
                deg2rad(cosPar(j,1,i))*...
                (2*pi*cosPar(j,2,i))^2*...
                cos(2*pi*tempTime*cosPar(j,2,i)+pi/180*cosPar(j,3,i))...
            );

        % Calculate theor. power and rmse between measured and theor.
        tempPowTheo = ...
            totalInert(i)*...
            deg2rad(cosPar(j,1,i))^2*...
            (2*pi*cosPar(j,2,i))^3*...
            0.5*sin(4*pi*tempTime*cosPar(j,2,i)+2*pi/180*cosPar(j,3,i));
        tempPeakPow = max(tempPow);
        tempPowErr = rmse(tempPowTheo,tempPow);
    
        % Store results
        powErr.Inertia((i-1)*40+j) = totalInert(i)*1000;
        powErr.dThetaPeak((i-1)*40+j) = tempdTheta;
        powErr.ddThetaPeak((i-1)*40+j) = tempddTheta;
        powErr.PeakPow((i-1)*40+j) = tempPeakPow;
        powErr.RMSE((i-1)*40+j) = tempPowErr;

        % Store time curves for power
        tempTab = table(tempTime,tempPow,tempPowTheo);
        tempTab.Properties.VariableNames = {'Time' 'PowAct' 'PowTheo'};
        Pow{j,i} = tempTab;

        % Calculate and store position residuals
        if i == 1
            posDiff1 = [posDiff1; tempPos.Pos-tempPosTheo];
        elseif i == 2
            posDiff2 = [posDiff2; tempPos.Pos-tempPosTheo];
        elseif i == 3
            posDiff3 = [posDiff3; tempPos.Pos-tempPosTheo];
        elseif i == 4
            posDiff4 = [posDiff4; tempPos.Pos-tempPosTheo];
        elseif i == 5
            if j<39
                posDiff5 = [posDiff5; tempPos.Pos-tempPosTheo];
            end
        end

        % Create figures that show example of theoretical and measured
        % cycles for power and position
        if i==4 && j==31
            % Create a figure for 2 cycles of power (1 cycle of position)
            [~,~,~,~] = cosRegressPow(tempMotorData,true);
            myExportGraphics(gcf,'exPosCurve.eps',imgLoc)
            
            % Create a figure for a single cycle of position
            figure()
            hold on
            plot(...
                tempTime,...
                tempPow,...
                '--o',...
                'DisplayName','Interpolated Power Measurements'...
            )
            plot(tempTime,tempPowTheo,'DisplayName','Theoretical Power')
            xlabel('Time (s)')
            ylabel('Power (W)')
            xlim([1.6005 1.734])
            legend()
            myExportGraphics(gcf,'exPowCurve.eps',imgLoc)
        end
    end
end

%%
fig1 = figure();
heatRMSE = heatmap(powErr,"Inertia","Frequency","ColorVariable","RMSE","ColorLimits",[0 20],"Colormap",hot,'Interpreter','latex','FontSize',16,'CellLabelFormat','%.3f');
heatRMSE.Title = '';
heatRMSE.XLabel = "Inertia (kg$\cdot$cm$^2$)";
heatRMSE.YLabel = "Frequency (Hz)";
heatRMSELabels = heatRMSE.YDisplayLabels;
for i=1:2:length(heatRMSELabels)
    heatRMSELabels{i} = '';
end
heatRMSE.YDisplayLabels = heatRMSELabels;
heatRMSE = struct(heatRMSE);
heatRMSE.NodeChildren(3).YDir='normal';
ylabel(heatRMSE.Colorbar, "RMSE (W)",'Interpreter','latex','FontSize',16);
fig1.Position = [50 800 900 2400];
myExportGraphics(gcf,'powRMSE.eps',imgLoc)

%%
figure()
hold on
plot(powErr.PeakPow(1:end),powErr.RMSE(1:end),'o','DisplayName','Power RMSE Values')
xlabel('Peak Power (W)')
ylabel('Power RMSE (W)')
legend()
myExportGraphics(gcf,'powErrScatter.eps',imgLoc)

%%
xs = linspace(min(powErr.PeakPow(1:end-1)),max(powErr.PeakPow(1:end-1)),100);
xVals = 0.138*xs + 1.5;
figure()
hold on
plot(powErr.PeakPow(1:end-1),powErr.RMSE(1:end-1),'o','DisplayName','Power RMSE Values')
plot(xs,xVals,'--','DisplayName','Conservative Error Function')
xlabel('Peak Power (W)')
ylabel('Power RMSE (W)')
legend()
myExportGraphics(gcf,'powErrScatterZoom.eps',imgLoc)

%%
fig2 = figure();
posRMSE = heatmap(posErr,"Inertia","Frequency","ColorVariable","RMSE","ColorLimits",[0 1.3],"Colormap",hot,'Interpreter','latex','FontSize',16,'CellLabelFormat','%.3f');
posRMSE.Title = '';
posRMSE.XLabel = "Inertia (kg$\cdot$cm$^2$)";
posRMSE.YLabel = "Frequency (Hz)";
posRMSELabels = posRMSE.YDisplayLabels;
for i=1:2:length(posRMSELabels)
    posRMSELabels{i} = '';
end
posRMSE.YDisplayLabels = posRMSELabels;
posRMSE = struct(posRMSE);
posRMSE.NodeChildren(3).YDir='normal';
ylabel(posRMSE.Colorbar, "RMSE ($^\circ$)",'Interpreter','latex','FontSize',16);
fig2.Position = [50 800 900 2400];
myExportGraphics(gcf,'posRMSE.eps',imgLoc)

%%
figure()
hold on
histogram(posDiff5,120,'normalization', 'pdf','DisplayName','Normalized Residuals')
pdfPosX5 = linspace(min(posDiff5),max(posDiff5),1000);
meanPos5 = mean(posDiff5);
stdPos5 = std(posDiff5);
pdfPosNorm5 = 1/sqrt(2*pi*stdPos5^2)*exp(-(pdfPosX5-meanPos5).^2/(2*stdPos5^2));
medPos5 = median(posDiff5);
bPos5 = mean(abs(posDiff5-medPos5));
pdfLaplace5 = 1/(2*bPos5)*exp(-abs(pdfPosX5-medPos5)/bPos5);
plot(pdfPosX5,pdfLaplace5,'DisplayName','Estimated Laplace Distribution')
plot(pdfPosX5,pdfPosNorm5,'DisplayName','Estimated Normal Distribution')
xlim([-2 2])
xlabel('Residuals ($^\circ$)')
ylabel('Probability Density')
legend()
myExportGraphics(gcf,'d5PResid.eps',imgLoc)