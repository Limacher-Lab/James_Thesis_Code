clc;
clear;
close all

if ~matlab.engine.isEngineShared
    matlab.engine.shareEngine('MyEngine')
end
% Define global variables to hold the data across function calls
global dispint timeVec dataX dataY dataZ dataCh0 dataCh1 dataCh2 dataCh3 dataCh4 dataCh5 dataCh0Biased dataCh1Biased dataCh2Biased dataCh3Biased dataCh4Biased dataCh5Biased ...
    yLimits biasX biasY biasZ biasX2 biasY2 biasZ2 pressure pressureBiased biasP freq;

yLimits = [-7, 7];  % Default y-axis limits
saveFolder = 'C:\Users\James\Desktop\Calibration\Galoce\Tightly Cable Managed Runs\Static 0012\Check Run (Do Not Use)';

dispint = 30;
timeVec = [];
dataX = [];
dataY = [];
dataZ = [];
dataCh0 = [];
dataCh1 = [];
dataCh2 = [];
dataCh3 = [];
dataCh4 = [];
dataCh5 = [];
pressure = [];
dataCh0Biased = [];
dataCh1Biased = [];
dataCh2Biased = [];
dataCh3Biased = [];
dataCh4Biased = [];
dataCh5Biased = [];
pressureBiased = [];
biasX = 0;
biasY = 0;
biasZ = 0;
biasX2 = 0;
biasY2 = 0;
biasZ2 = 0;
biasP = 0;
driftTime = 60;

% Define the date and file name as variables
% file_name = 'Bias.mat';
% base_path = 'C:\Users\James\Desktop\Calibration\Galoce\Tightly Cable Managed Runs\Static 0012\Check Run (Do Not Use)\Biases';
% 
% dbiasX = load([fullfile(base_path, file_name)],'biasX');
% dbiasY = load([fullfile(base_path, file_name)],'biasY');
% dbiasZ = load([fullfile(base_path, file_name)],'biasZ');
% dbiasX2 = load([fullfile(base_path, file_name)],'biasX2');
% dbiasY2 = load([fullfile(base_path, file_name)],'biasY2');
% dbiasZ2 = load([fullfile(base_path, file_name)],'biasZ2');
% dbiasP = load([fullfile(base_path, file_name)], 'biasP');
% biasX = dbiasX.biasX;
% biasY = dbiasY.biasY;
% biasZ = dbiasZ.biasZ;
% biasX2 = dbiasX2.biasX2;
% biasY2 = dbiasY2.biasY2;
% biasZ2 = dbiasZ2.biasZ2;
% biasP = dbiasP.biasP;



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

due = serialport('COM5',9600);
due.Timeout = 420;
configureTerminator(due,"CR/LF")

startString = readline(due);
while(true)
    ardCommand = input(startString+newline,'s');
    if ardCommand == 'y'
        break
    elseif ardCommand =='n'
        fprintf("Stopping")
        return
    end
end
write(due,ardCommand,'char');

totalLoopOut =   'C:\Users\James\Desktop\Teknic\ClearView\sdk\Flaping Wing\Monitor - Copy\totalLoops.txt';      
fid = fopen(totalLoopOut, 'w' ); %// open file to writing
fprintf( fid, '%s\n', "yn" ); %// print string to file
fclose( fid ); %// don't forget to close the file

contString = "";
while ~strcmpi(contString,'no')
    s3 = startDaq();
    clearData();
    fileName = readline(due);
    freq = readline(due);
    
    fileNameOut =   'C:\Users\James\Desktop\Teknic\ClearView\sdk\Flaping Wing\Monitor - Copy\fileName.txt';      
    fid = fopen(fileNameOut, 'w' ); %// open file to writing
    fprintf( fid, '%s\ny', fileName ); %// print string to file
    fclose( fid ); %// don't forget to close the file
    pause(1)
    fid = fopen(fileNameOut, 'w' ); %// open file to writing
    fprintf( fid, '%s\nn', fileName ); %// print string to file
    fclose( fid ); %// don't forget to close the file
    
    fprintf("Collecting drift data for "+freq+"\n");
    [driftData, driftTimeVec,~] = read(s3,seconds(driftTime),"OutputFormat","Matrix");

    timeVec = driftTimeVec';
    dataCh0 = driftData(:, 1)';  % x data
    dataCh1 = driftData(:, 2)';  % y data
    dataCh2 = driftData(:, 3)';  % z data
    dataCh3 = driftData(:, 4)';  % 
    dataCh4 = driftData(:, 5)';  % 
    dataCh5 = driftData(:, 6)';  %
    pressure = driftData(:,7)';

    dataCh0Biased = driftData(:, 1)' - biasX; 
    dataCh1Biased = driftData(:, 2)' - biasY; 
    dataCh2Biased = driftData(:, 3)' - biasZ; 
    dataCh3Biased = driftData(:, 4)' - biasX2; 
    dataCh4Biased = driftData(:, 5)' - biasY2; 
    dataCh5Biased = driftData(:, 6)' - biasZ2;
    pressureBiased = driftData(:,7)' - biasP;
    dataX = dataCh0Biased+dataCh3Biased;
    dataY = dataCh1Biased+dataCh4Biased;
    dataZ = dataCh2Biased+dataCh5Biased;

    figure()
    hold on
    plot(driftTimeVec,dataX)
    plot(driftTimeVec,dataY)
    plot(driftTimeVec,dataZ)
    plot(driftTimeVec,pressureBiased)
    legend('Thrust', 'Lift', 'Side', 'Pressure')


    saveLoggedData(saveFolder,"Drift"+fileName);
    clear("s3")

    s2 = startDaq();
    clearData();
    write(due,'c','char');

    messString = "";
    while ~strcmpi(messString, "start")
        messString = readline(due);
    end

    % Prepare the figure for live plotting
    figure('Position',[1120, 600, 800, 500]);
    clf;
    %h1 = plot(NaN, NaN, '-b');  % Create a placeholder for x
    hold on;
    h1 = plot(NaN, NaN, '-b');  % Create a placeholder for xb
    h2 = plot(NaN, NaN, '-r');  % Placeholder for yb
    h3 = plot(NaN, NaN, '-g');  % Placeholder for zb
    h4 = plot(NaN, NaN, '-k');  % Placeholder for trigger
    h5 = plot(NaN, NaN, '-m');  % Placeholder for pwmh
    h6 = plot(NaN, NaN, '-c');  % Placeholder for pwmp
    h7 = plot(NaN, NaN, '-or');
    xlabel('Time (s)');
    xlim([0, dispint]);
    ylabel('Voltage (V)');
    ylim(yLimits); % Set y-axis limits
    grid on;
    legend('XBack', 'YBack', 'ZBack','XFront', 'YFront', 'ZFront', 'Pressure');
    % legend('X', 'Y', 'Z');

    % Data acquisition callback function
    s2.ScansAvailableFcn = @(src, evt) plotData(src, evt, h1, h2, h3, h4, h5, h6,h7);

    % Start the session
    start(s2, "continuous");
    mainLoopOut =   'C:\Users\James\Desktop\Teknic\ClearView\sdk\Flaping Wing\Monitor - Copy\mainLoop.txt';      
    fid = fopen(mainLoopOut, 'w' ); %// open file to writing
    fprintf( fid, '%s\n', "y" ); %// print string to file
    fclose( fid ); %// don't forget to close the file
    % Inform Arduino that data collection has started
    write(due,'s','char');
    
    % Display message for user to stop acquisition
    fprintf('Data acquisition started for '+freq+"Hz.\n");
    
    % Wait for user input
    dataStop = "";
    while ~strcmpi(dataStop, "stop")
        dataStop = readline(due);
        % Save Data
        if strcmpi(dataStop, "stop")
            stop(s2);  % Stop the session
            fid = fopen(mainLoopOut, 'w' ); %// open file to writing
            fprintf( fid, '%s\n', "n" ); %// print string to file
            fclose( fid ); %// don't forget to close the file
            fprintf('Data acquisition stopped.\n');
            pause(2)
            if s2.NumScansAvailable > 0
                [dataFin, timeFin, ~] = s2.read("all","OutputFormat",'Matrix');
                % Append new data points
                timeVec = [timeVec, timeFin'];
                dataCh0 = [dataCh0, dataFin(:, 1)'];  % x data
                dataCh1 = [dataCh1, dataFin(:, 2)'];  % y data
                dataCh2 = [dataCh2, dataFin(:, 3)'];  % z data
                dataCh3 = [dataCh3, dataFin(:, 4)'];  % 
                dataCh4 = [dataCh4, dataFin(:, 5)'];  % 
                dataCh5 = [dataCh5, dataFin(:, 6)'];  % 
               
                dataCh0Biased = [dataCh0Biased, dataFin(:, 1)' - biasX]; 
                dataCh1Biased = [dataCh1Biased, dataFin(:, 2)' - biasY]; 
                dataCh2Biased = [dataCh2Biased, dataFin(:, 3)' - biasZ]; 
                dataCh3Biased = [dataCh3Biased, dataFin(:, 4)' - biasX2]; 
                dataCh4Biased = [dataCh4Biased, dataFin(:, 5)' - biasY2]; 
                dataCh5Biased = [dataCh5Biased, dataFin(:, 6)' - biasZ2];
                dataX = dataCh0Biased+dataCh3Biased;
                dataY = dataCh1Biased+dataCh4Biased;
                dataZ = dataCh2Biased+dataCh5Biased;
            end
        % Call the save function after stopping the acquisition
        % saveLoggedData(fileString,base_path);
            saveLoggedData(saveFolder,fileName);
            break
        end
    end
    clear("s2")
    % Inform Due that saving is complete
    write(due,'f','char')
    contString = readline(due);
    if ~strcmpi(contString, 'no')
        fid = fopen(totalLoopOut, 'w' ); %// open file to writing
        fprintf( fid, '%s\n', "yy" ); %// print string to file
        fclose( fid ); %// don't forget to close the file
        pause(1)
        fid = fopen(totalLoopOut, 'w' ); %// open file to writing
        fprintf( fid, '%s\n', "yn" ); %// print string to file
        fclose( fid ); %// don't forget to close the file
    end

end
fid = fopen(totalLoopOut, 'w' ); %// open file to writing
fprintf( fid, '%s\n', "ny" ); %// print string to file
fclose( fid ); %// don't forget to close the file
pause(1)
fid = fopen(totalLoopOut, 'w' ); %// open file to writing
fprintf( fid, '%s\n', "nn" ); %// print string to file
fclose( fid ); %// don't forget to close the file

clear('due')

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%




% Define callback function to update the plot for each data point
function plotData(src, event, h1, h2, h3, h4, h5, h6,h7)
% function plotData(~, event, h1, h2, h3)
global dispint timeVec dataX dataY dataZ dataCh0 dataCh1 dataCh2 dataCh3 dataCh4 dataCh5 ...
    dataCh0Biased dataCh1Biased dataCh2Biased dataCh3Biased dataCh4Biased dataCh5Biased ...
    yLimits biasX biasY biasZ biasX2 biasY2 biasZ2 pressure pressureBiased biasP;

    % Get the current time from the session
    [data, timestamps, ~] = read(src, src.ScansAvailableFcnCount, "OutputFormat", "Matrix");  % Time stamps of the new data

    % Append new data points
    timeVec = [timeVec, timestamps'];
    dataCh0 = [dataCh0, data(:, 1)'];  % x data
    dataCh1 = [dataCh1, data(:, 2)'];  % y data
    dataCh2 = [dataCh2, data(:, 3)'];  % z data
    dataCh3 = [dataCh3, data(:, 4)'];  % 
    dataCh4 = [dataCh4, data(:, 5)'];  % 
    dataCh5 = [dataCh5, data(:, 6)'];  %
    pressure = [pressure,data(:,7)'];
   
    dataCh0Biased = [dataCh0Biased, data(:, 1)' - biasX]; 
    dataCh1Biased = [dataCh1Biased, data(:, 2)' - biasY]; 
    dataCh2Biased = [dataCh2Biased, data(:, 3)' - biasZ]; 
    dataCh3Biased = [dataCh3Biased, data(:, 4)' - biasX2]; 
    dataCh4Biased = [dataCh4Biased, data(:, 5)' - biasY2]; 
    dataCh5Biased = [dataCh5Biased, data(:, 6)' - biasZ2];
    pressureBiased = [pressureBiased, data(:,7)' - biasP];
    dataX = dataCh0Biased+dataCh3Biased;
    dataY = dataCh1Biased+dataCh4Biased;
    dataZ = dataCh2Biased+dataCh5Biased;

    % Keep only the last dispint seconds of data
    currentTime = timeVec(end);  % Get the latest time stamp
    validIndices = timeVec >= (currentTime - dispint);  % Find indices within the last dispint seconds

    % Update the plot with the new data point

    % set(h1, 'XData', timeVec, 'YData', dataX);
    % set(h2, 'XData', timeVec, 'YData', dataY);
    % set(h3, 'XData', timeVec, 'YData', dataZ);
    set(h1, 'XData', timeVec, 'YData', dataCh0Biased);
    set(h2, 'XData', timeVec, 'YData', dataCh1Biased);
    set(h3, 'XData', timeVec, 'YData', dataCh2Biased);
    set(h4, 'XData', timeVec, 'YData', dataCh3Biased);
    set(h5, 'XData', timeVec, 'YData', dataCh4Biased);
    set(h6, 'XData', timeVec, 'YData', dataCh5Biased);
    set(h7, 'XData', timeVec, 'YData', pressureBiased);
    drawnow;
    

    % Set x-axis limits: if currentTime is less than dispint seconds, start at 0; otherwise, start from (currentTime - dispint)
    if currentTime < dispint
        xlim([0, dispint]);  % Show 0 to dispint seconds if less than 60 seconds of data available
        xticks(0:dispint/10:dispint)
    else
        xlim([currentTime - dispint, currentTime]);  % Show the last dispint seconds
        xticks(0:dispint/10:currentTime)
    end
   % Set y-axis limits to user-defined limits
    ylim(yLimits);  % Use user-defined y-axis limits

end


% Function to save logged data to a file with GUI prompt
% function saveLoggedData(fileString, filePath)
function saveLoggedData(filePath,fileName)
global timeVec dataX dataY dataZ dataCh0 dataCh1 dataCh2 dataCh3 dataCh4 dataCh5 ...
    dataCh0Biased dataCh1Biased dataCh2Biased dataCh3Biased dataCh4Biased dataCh5Biased...
    biasX biasY biasZ biasX2 biasY2 biasZ2 pressure pressureBiased biasP freq;
    currentDateTime = datetime('now', 'TimeZone', 'local');
    currentDateTime.Format = ' yy-MM-dd HH-mm';
    dateTimeString = string(currentDateTime);
    fileName = strrep(fileName,".00","");
    % Generate a default filename with a timestamp
    % defaultName = [fileString,'Hz 35.5Stroke 10Pitch 90lag pt2.mat'];
    % Construct the full file path
    fullFileName = fullfile(filePath,fileName+dateTimeString+".mat");
    % Save the data to the selected file
    save(fullFileName, 'timeVec', 'dataX', 'dataY' , 'dataZ', 'dataCh0', 'dataCh1', 'dataCh2','dataCh3','dataCh4','dataCh5',...
        'dataCh0Biased', 'dataCh1Biased', 'dataCh2Biased','dataCh3Biased', 'dataCh4Biased', 'dataCh5Biased',...
        'biasX', 'biasY', 'biasZ','biasX2', 'biasY2', 'biasZ2', 'pressure', 'pressureBiased', 'biasP', 'freq');
end

function clearData()
global timeVec dataX dataY dataZ dataCh0 dataCh1 dataCh2 dataCh3 dataCh4 dataCh5 ...
    dataCh0Biased dataCh1Biased dataCh2Biased dataCh3Biased dataCh4Biased dataCh5Biased pressure pressureBiased;
    timeVec = [];
    dataX = [];
    dataY = [];
    dataZ = [];
    dataCh0 = [];
    dataCh1 = [];
    dataCh2 = [];
    dataCh3 = [];
    dataCh4 = [];
    dataCh5 = [];
    dataCh0Biased = [];
    dataCh1Biased = [];
    dataCh2Biased = [];
    dataCh3Biased = [];
    dataCh4Biased = [];
    dataCh5Biased = [];
    pressure = [];
    pressureBiased = [];
end

function [daqSession] = startDaq()
% Create a DAQ session
    daqSession = daq('ni');
    daqSession.Rate = 2000;  % Sample rate in Hz
    
    % Add analog input channels (replace 'Dev1' with your device ID)
    a0 = addinput(daqSession, 'Dev1', 'ai7', 'Voltage');  % Channel AI0
    a0.TerminalConfig = "Differential";
    a0.Range = [-10 10];
    a1 = addinput(daqSession, 'Dev1', 'ai2', 'Voltage');  % Channel AI1
    a1.TerminalConfig = "Differential";
    a1.Range = [-10 10];
    a2 = addinput(daqSession, 'Dev1', 'ai3', 'Voltage');  % Channel AI2
    a2.TerminalConfig = "Differential";
    a2.Range = [-10 10];
    a3 = addinput(daqSession, 'Dev1', 'ai4', 'Voltage');  % Channel AI3
    a3.TerminalConfig = "Differential";
    a3.Range = [-10 10];
    a4 = addinput(daqSession,'Dev1','ai5','Voltage');
    a4.TerminalConfig = "Differential";
    a4.Range = [-10 10];
    a5 = addinput(daqSession,'Dev1','ai6','Voltage');
    a5.TerminalConfig = "Differential";
    a5.Range = [-10 10];
    a6 = addinput(daqSession,'Dev1', 'ai8', 'Voltage');
    a6.TerminalConfig = 'SingleEnded';
    a6.Range = [-10 10];
    
    a0.Name = 'X Force';
    a1.Name = 'Y Force';
    a2.Name = 'Z Force';
    a3.Name = 'X Force2';
    a4.Name = 'Y Force2';
    a5.Name = 'Z Force2';
    a6.Name = 'Pressure';
    
    % Set the number of samples per event callback (one sample at a time)
    daqSession.ScansAvailableFcnCount = 500;  % Trigger event for every data point
    
end