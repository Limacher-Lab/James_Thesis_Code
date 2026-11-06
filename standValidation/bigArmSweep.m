imgLoc = ['C:\Users\James\OneDrive - ' ... % Location to export figures
    'University of Calgary\Thesis\Calibration Images\'];

% Scales provide force in units of mass
% Assuming kitchen scale would use 9.81 to go from force to mass so this
% code uses 9.81 to go from mass back to force
grav = 9.81;

% Load cell slopes for converting from Volt to Newton
        % Back   Front
        % G-1232 K-7801
slopes = [29.574 31.820; % Thrust (N/V)
          30.296 32.028;...
          29.3562 30.1330]; % Lift (N/V)

% Load cell slope intercepts
intercepts = [-0.0116 -0.0968; % Thrust (N)
               0.0886 0.2038]; % Lift (N)

% Total measurement capacity of the combined load cells (N)
fullRange = 300;

% Distance from bottom of load cell to top of aluminum plate (mm)
baseArm = 44.9;

% Pulley efficiency used to correct the applied force
% Setting to 1 makes everything based on the applied force
eta = 1;

% Create list of data sets
dataSets = dir(fullfile('*.mat'));
dataSets = struct2table(dataSets);

% Which file names should be kept
biasIdx = contains(dataSets.name,'Bias');
postIdx = contains(dataSets.name,'Post');
dataIdx = ~biasIdx & ~postIdx;
data = dataSets(dataIdx,:);

% Empty containers to hold results
dataLength = length(data.name);
dataTable = zeros(dataLength,5);
dataTable = array2table(dataTable);
dataTable.Properties.VariableNames = ...
    {'Run' 'Mass' 'Force' 'Pulley Corrected' 'LC Reading'};

% Loop to process results
for testNum = 1:length(data.name)
    % Load file
    tempData = load(fullfile(data.name{testNum}));
    % Extract the file name
    fileName = data.name(testNum);
    % Extract information from file name
    mass = extractBefore(fileName,',');
    mass = str2double(mass);
    mass = mass/1000;
    force = mass*9.81;
    pulley = force*eta;
    fileName = extractAfter(fileName,',');
    
    % Basket slipped during unloading so no hyst data but naming
    % convention requires it
    hyst = extractBefore(fileName,',');
    if strcmp(hyst,'lo')
        hyst = "Load";
    elseif strcmp(hyst,'un')
        hyst = "Unload";
    end
    fileName = extractAfter(fileName,',');
    
    run = extractBefore(fileName,'.');
    if strcmp(run,'r1')
        run = 1;
    elseif strcmp(run,'r2')
        run = 2;
    end
    
    % Calculate the axis forces
    xFront = mean(tempData.dataCh3Biased)*slopes(1,1)+intercepts(1,1);
    xBack = mean(tempData.dataCh0Biased)*slopes(1,2)+intercepts(1,2);
    
    yFront = mean(tempData.dataCh4Biased)*slopes(2,1)+intercepts(2,1);
    yBack = mean(tempData.dataCh1Biased)*slopes(2,2)+intercepts(2,2);

    zFront = mean(tempData.dataCh5Biased)*slopes(3,1);
    zBack = mean(tempData.dataCh2Biased)*slopes(3,2);

    % Calculate the total force
    tempLC = sqrt((yFront+yBack)^2+(xFront+xBack)^2+(zFront+zBack)^2);
    
    % Store processed data
    dataTable.('Run')(testNum) = run;
    dataTable.('Un/Load')(testNum) = hyst;
    dataTable.('Mass')(testNum) = mass;
    dataTable.('Force')(testNum) = force;
    dataTable.('Pulley Corrected')(testNum) = pulley;
    dataTable.('LC Reading')(testNum) = tempLC;
    
end

% Sort data table
dataTable = sortrows(dataTable,["Run" "Mass"]);

% Determine indices for the runs and create data set for each
run1Idx = dataTable.Run == 1;
run1 = dataTable(run1Idx,:);

run2Idx = dataTable.Run == 2;
run2 = dataTable(run2Idx,:);

% Tension force predicted by simple pulley losses
modelForce = 0:1:max(run1.Force);

% Calculate the difference between the pulley loss estimate and the actual
% reading as a percent of the applied load
run1.("Percent Diff") = ...
    (run1.("LC Reading")-run1.("Pulley Corrected"))./...
    run1.("Pulley Corrected")*100;
run2.("Percent Diff") ...
    = (run2.("LC Reading")-run2.("Pulley Corrected"))./...
    run2.("Pulley Corrected")*100;

% Calculate moment applied
run1.Moment = run1.("Pulley Corrected")*0.616;
run2.Moment = run2.("Pulley Corrected")*0.616;

% Plot figures
figure()
hold on
a1 = plot(modelForce, modelForce,'k',DisplayName='Force Applied');
a2 = ...
    plot(...
        run1.("Pulley Corrected"),...
        run1.("LC Reading"),...
        'ob',...
        DisplayName='Run 1'...
    );
a3 = ...
    plot(...
        run2.("Pulley Corrected"),...
        run2.("LC Reading"),...
        'or',...
        DisplayName='Run 2'...
    );
ylabel('Load Cell Reading (N)');
xlabel('Force Applied (N)');
grid on;
legend([a1,a2,a3],Location='northwest')
myExportGraphics(gcf,'BigArmSweep.eps',imgLoc)

figure()
hold on
b1 = plot(run1.Moment, run1.("Percent Diff"),'ob',DisplayName='Run 1');
b2 = plot(run2.Moment, run2.("Percent Diff"),'or',DisplayName='Run 2');
ylabel('Percent Difference (\% Force Applied)');
xlabel('Moment (Nm)');
grid on;
legend(Location='southwest')
theme('light')
myExportGraphics(gcf,'BigArmScatter.eps',imgLoc)