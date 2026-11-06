clc
clear

setupType = ["../Static Redo/6mm Gap" "../Static Redo/Taped Fairing"...
    "../Static Redo/Reference Wing" "../Post Teardown Spot Check"...
    "../Static Redo/Normal Gap" "../Static Redo/Norm Gap Ref"...
    "../Static Redo/Corrected Profile" "../Static Redo/No Gap"...
    "../Static Redo/Plane and Fairing" ""];
biasFolder = setupType+"\Biases";
numFolders = length(setupType);
g = 9.81;
S = 0.08;
c = 0.21;

slopes = [29.574 31.820;...
          30.296 32.028];

intercepts = [-0.0116 -0.0968;...
               0.0886 0.2038];

slopesErr = [0.2147 0.0381;...
             0.0204 0.0402];

interceptsErr = [0.0741 0.0931;...
                 0.0887 0.1179];

sensorMisalignDeg = 1.7;

f0 = [0.1234 -0.7195]';
fs = [-0.3009 -0.1013]';

uncF0 = [0.0118 0.0086];
uncFS = [0.0052 0.0113];

f = f0-fs;


dataSets = cell(1,numFolders);

biasSets = cell(1,numFolders);

dataLength = 0;
biasDataLength = 0;

for folNum=1:numFolders
    tempData = dir(fullfile(setupType(folNum),'*.mat'));
    tempData = struct2table(tempData);
    removeIdx = strcmpi(tempData.name,'FT14846.mat');
    tempData(removeIdx,:) = [];
    dataSets{folNum} = tempData;

    tempLength = length(tempData.name)/2;
    dataLength = dataLength+tempLength;

    tempBias = dir(fullfile(biasFolder(folNum),'*.mat'));
    tempBias = struct2table(tempBias);
    biasSets{folNum} = tempData;

    tempBiasLength = length(tempBias.name);
    biasDataLength = biasDataLength + tempBiasLength;
end


dataTable = zeros(dataLength,14);
dataTable = array2table(dataTable);
dataTable.Properties.VariableNames = {'Type' 'Run' 'AoA' 'q' 'CL' 'CD' 'rawCL' 'rawCD' 'srCL' 'srCD' 'VFx' 'VFy' 'VBx' 'VBy'};
dataTable = convertvars(dataTable,"Type",'string');

driftTable = zeros(dataLength,9);
driftTable = array2table(driftTable);
driftTable.Properties.VariableNames = {'Type' 'Run' 'q' 'L' 'D' 'M' 'CL' 'CD' 'CM'};
driftTable = convertvars(dataTable,"Type",'string');

biasTable = zeros(biasDataLength,8);
biasTable = array2table(biasTable);
biasTable.Properties.VariableNames = {'Type' 'Run' 'PreThrust' 'PreLift' 'PostThrust' 'PostLift' 'DriftThrust' 'DriftLift'};
biasTable = convertvars(biasTable,"Type",'string');

tracker = 0;

%% Galoce Processing

for setupNum = 1:numFolders-1
    tempDataSet = dataSets{setupNum};
    tempBiasSet = biasSets{setupNum};
    driftIdx = contains(tempDataSet.name,'Drift');
    tempDriftSet = tempDataSet(driftIdx,:);
    tempDataSet = tempDataSet(~driftIdx,:);

    for setNum = 1:length(tempDataSet.name)
        tempData = load(fullfile(setupType(setupNum),tempDataSet.name{setNum}));
        fileName = tempDataSet.name(setNum);
        
        type = extractBefore(fileName,',');
        fileName = extractAfter(fileName,',');
        runNum = extractBefore(fileName,',');
        fileName = extractAfter(fileName,',');
        posStr = extractBefore(fileName,'.');
        pos = str2double(posStr);

        exactDriftIdx = contains(tempDriftSet.name,runNum) & contains(tempDriftSet.name,posStr);
        exactDrift = tempDriftSet(exactDriftIdx,:);
        tempDrift = load(fullfile(setupType(setupNum),exactDrift.name{1}));

        n = length(tempData.timeVec);

        thDriftFront = mean(tempDrift.dataCh3Biased)*slopes(1,1)+intercepts(1,1);
        thDriftBack = mean(tempDrift.dataCh0Biased)*slopes(1,2)+intercepts(1,2);
        liDriftFront = mean(tempDrift.dataCh4Biased)*slopes(2,1)+intercepts(2,1);
        liDriftBack = mean(tempDrift.dataCh1Biased)*slopes(2,2)+intercepts(2,2);

        tDrift = thDriftFront+thDriftBack;
        lDrift = -(liDriftFront+liDriftBack);
        qVoltDrift = tempDrift.pressureBiased;
        qDrift = qVoltDrift*497.68/10;
        qDriftMean = mean(qDrift);

        thrustFront = tempData.dataCh3Biased*slopes(1,1)+intercepts(1,1)-thDriftFront;
        thrustBack = tempData.dataCh0Biased*slopes(1,2)+intercepts(1,2)-thDriftBack;
        liftFront = tempData.dataCh4Biased*slopes(2,1)+intercepts(2,1)-liDriftFront;
        liftBack = tempData.dataCh1Biased*slopes(2,2)+intercepts(2,2)-liDriftBack;

        rawTF = thrustFront+thDriftFront;
        rawTB = thrustBack+thDriftBack;
        rawLF = liftFront+liDriftFront;
        rawLB = liftBack+liDriftBack;

        thrust = thrustBack+thrustFront;
        lift = -(liftBack+liftFront);
        qVolt = tempData.pressureBiased;
        q = qVolt*497.68/10;
        meanQ = mean(q);
 
        VFy = sqrt(mean(tempData.dataCh4Biased)^2 + mean(tempDrift.dataCh4Biased)^2);
        stdVFy = std(tempData.dataCh4Biased);
        drstdVFy = std(tempDrift.dataCh4Biased);
        
        VBy = sqrt(mean(tempData.dataCh1Biased)^2 + mean(tempDrift.dataCh1Biased)^2);
        stdVBy = std(tempData.dataCh1Biased);
        drstdVBy = std(tempDrift.dataCh1Biased);
        
        VFx = sqrt(mean(tempData.dataCh3Biased)^2 + mean(tempDrift.dataCh3Biased)^2);
        stdVFx = std(tempData.dataCh3Biased);
        drstdVFx = std(tempDrift.dataCh3Biased);
        
        VBx = sqrt(mean(tempData.dataCh0Biased)^2 + mean(tempDrift.dataCh0Biased)^2);
        stdVBx = std(tempData.dataCh0Biased);
        drstdVBx = std(tempDrift.dataCh0Biased);
        

        thrustSR = 2*sqrt((((slopes(1,1))^2*stdVFx^2 + (slopes(1,2))^2*stdVBx^2 + ...
            (slopes(1,1))^2*drstdVFx^2 + (slopes(1,2))^2*drstdVBx^2)/(meanQ*S)^2 + ...
            (mean(lift)/(mean(q)^2*S))^2*std(q)^2)/n^2);
        liftSR = 2*sqrt((((slopes(2,1))^2*stdVFy^2 + (slopes(2,2))^2*stdVBy^2 + ...
            (slopes(2,1))^2*drstdVFy^2 + (slopes(2,2))^2*drstdVBy^2)/(meanQ*S)^2 + ...
            (mean(thrust)/(mean(q)^2*S))^2*std(q)^2)/n^2);
        


        rawT = rawTB+rawTF;
        rawL = -(rawLB+rawLF);

        AoA = pos*360/6400;
        CLDrift = lDrift;
        CDDrift = tDrift;
        CL = mean(lift);
        CD = mean(thrust);

        rawCL = mean(rawL)/(meanQ*S);
        rawCD = mean(rawT)/(meanQ*S);
        
    
        dataTable.Run(setNum+tracker) = str2double(extractAfter(runNum,'R'));
        dataTable.Type(setNum+tracker) = type;
        dataTable.AoA(setNum+tracker) = AoA;
        dataTable.CL(setNum+tracker) = CL;
        dataTable.CD(setNum+tracker) = CD;
        dataTable.rawCL(setNum+tracker) = rawCL;
        dataTable.rawCD(setNum+tracker) = rawCD;
        dataTable.srCL(setNum+tracker) = liftSR;
        dataTable.srCD(setNum+tracker) = thrustSR;
        dataTable.VBx(setNum+tracker) = VBx;
        dataTable.VBy(setNum+tracker) = VBy;
        dataTable.VFx(setNum+tracker) = VFx;
        dataTable.VFy(setNum+tracker) = VFy;
        dataTable.q(setNum+tracker) = meanQ;

        driftTable.Run(setNum+tracker) = str2double(extractAfter(runNum,'R'));
        driftTable.AoA(setNum+tracker) = AoA;
        driftTable.Type(setNum+tracker) = type;
        driftTable.L(setNum+tracker) = CLDrift;
        driftTable.D(setNum+tracker) = CDDrift;
        driftTable.CL(setNum+tracker) = CLDrift/(qDriftMean*S);
        driftTable.CD(setNum+tracker) = CDDrift/(qDriftMean*S);
        driftTable.q(setNum+tracker) = qDriftMean;
    end
    tracker = tracker+setNum;
end

%% Gamma Processing

for setupNum = numFolders

    tempDataSet = dataSets{setupNum};
    tempBiasSet = biasSets{setupNum};
    driftIdx = contains(tempDataSet.name,'Drift');
    tempDriftSet = tempDataSet(driftIdx,:);
    tempDataSet = tempDataSet(~driftIdx,:);

    for setNum = 1:length(tempDataSet.name)
        tempData = load(fullfile(setupType(setupNum),tempDataSet.name{setNum}));
        fileName = tempDataSet.name(setNum);
        
        type = extractBefore(fileName,',');
        fileName = extractAfter(fileName,',');
        runNum = extractBefore(fileName,',');
        fileName = extractAfter(fileName,',');
        posStr = extractBefore(fileName,'.');
        pos = str2double(posStr);

        exactDriftIdx = contains(tempDriftSet.name,runNum) & contains(tempDriftSet.name,posStr);
        exactDrift = tempDriftSet(exactDriftIdx,:);
        tempDrift = load(fullfile(setupType(setupNum),exactDrift.name));

        n = length(tempData.timeVec);

        thDriftFront = -mean(tempDrift.dataCh0Biased);
        liDriftFront = -mean(tempDrift.dataCh1Biased);

        thrustFront = -tempData.dataCh0Biased -thDriftFront;
        liftFront = -tempData.dataCh1Biased-liDriftFront;

        rawTF = thrustFront+thDriftFront;
        rawLF = liftFront+liDriftFront;

        tDrift = thDriftFront;
        lDrift = liDriftFront;
        qVoltDrift = tempDrift.pressureBiased;
        qDrift = qVoltDrift*497.68/10;
        qDriftMean = mean(qDrift);

        thrust = mean(thrustFront);
        lift = mean(liftFront);
        qVolt = tempData.pressureBiased;
        q = qVolt*497.68/10;
        meanQ = mean(q);
        

        stdVBy = std(tempData.dataCh1Biased);
        drstdVBy = std(tempDrift.dataCh1Biased);

        stdVBx = std(tempData.dataCh0Biased);
        drstdVBx = std(tempDrift.dataCh0Biased);

        thrustSR = 2*sqrt(((stdVBx^2 + drstdVBx^2)/(meanQ*S)^2 + ...
            (mean(lift)/(mean(q)^2*S))^2*std(q)^2)/n^2);
        liftSR = 2*sqrt(((stdVBy^2 + drstdVBy^2)/(meanQ*S)^2 + ...
            (mean(thrust)/(mean(q)^2*S))^2*std(q)^2)/n^2);
        

        
        rawT = rawTF;
        rawL = -rawLF;

        AoA = pos*360/6400;
        CLDrift = lDrift;
        CDDrift = tDrift;
        CL = mean(lift);
        CD = mean(thrust);

        rawCL = mean(rawL)/(meanQ*S);
        rawCD = mean(rawT)/(meanQ*S);
        
    
        dataTable.Run(setNum+tracker) = str2double(extractAfter(runNum,'R'));
        dataTable.Type(setNum+tracker) = type;
        dataTable.AoA(setNum+tracker) = AoA;
        dataTable.CL(setNum+tracker) = CL;
        dataTable.CD(setNum+tracker) = CD;
        dataTable.rawCL(setNum+tracker) = rawCL;
        dataTable.rawCD(setNum+tracker) = rawCD;
        dataTable.srCL(setNum+tracker) = liftSR;
        dataTable.srCD(setNum+tracker) = thrustSR;
        dataTable.VBx(setNum+tracker) = 0;
        dataTable.VBy(setNum+tracker) = 0;
        dataTable.VFx(setNum+tracker) = 0;
        dataTable.VFy(setNum+tracker) = 0;
        dataTable.q(setNum+tracker) = meanQ;

        driftTable.Run(setNum+tracker) = str2double(extractAfter(runNum,'R'));
        driftTable.AoA(setNum+tracker) = AoA;
        driftTable.Type(setNum+tracker) = type;
        driftTable.L(setNum+tracker) = CLDrift;
        driftTable.D(setNum+tracker) = CDDrift;
        driftTable.CL(setNum+tracker) = CLDrift/(qDriftMean*S);
        driftTable.CD(setNum+tracker) = CDDrift/(qDriftMean*S);
        driftTable.q(setNum+tracker) = qDriftMean;
    end
    tracker = tracker+setNum;
end

%% Twente

twenteL = readtable("Twente,L,Re1_05e5.csv");
twenteD = readtable("Twente,D,Re1_05e5.csv");

twenteL = sortrows(twenteL,"x");
twenteD = sortrows(twenteD,"x");

%% Post Processing

[sixMM,sixMMDriftStats] = driftProcess(driftTable,dataTable,'6mm',S,f);
[taped,tapedDriftStats] = driftProcess(driftTable,dataTable,'TapedFair',S,f);
[gamma,gammaDriftStats] = driftProcess(driftTable,dataTable,'GammaStatic',S,f);
[refWing,refDriftStats] = driftProcess(driftTable,dataTable,'Ref',S,f);
[normGap,normGapDriftStats] = driftProcess(driftTable,dataTable,'NormGap',S,f);
[normGapRef,normGapRefDriftStats] = driftProcess(driftTable,dataTable,'NormGapRef',S,f);
[corrWing,corrWingRefDriftStats] = driftProcess(driftTable,dataTable,'Corr',S,f);
[noGap, noGapDriftStats] = driftProcess(driftTable,dataTable,'NoGap',S,f);
[fairing, fairingDriftStats] = driftProcess(driftTable,dataTable,'WithPlane',S,f);
[post,postDriftStats] = driftProcess(driftTable,dataTable,'PostTeardown',S,f);

mean6mm = meanStats(sixMM,sensorMisalignDeg,slopesErr,S,f,uncF0,uncFS);
meanTaped = meanStats(taped,sensorMisalignDeg,slopesErr,S,f,uncF0,uncFS);
meanGamma = meanStats(gamma,sensorMisalignDeg,slopesErr,S,f,uncF0,uncFS);
meanRef = meanStats(refWing,sensorMisalignDeg,slopesErr,S,f,uncF0,uncFS);
meanNorm = meanStats(normGap,sensorMisalignDeg,slopesErr,S,f,uncF0,uncFS);
meanNormRef = meanStats(normGapRef,sensorMisalignDeg,slopesErr,S,f,uncF0,uncFS);
meanCorr = meanStats(corrWing,sensorMisalignDeg,slopesErr,S,f,uncF0,uncFS);
meanNoGap = meanStats(noGap,sensorMisalignDeg,slopesErr,S,f,uncF0,uncFS);
meanFair = meanStats(fairing,sensorMisalignDeg,slopesErr,S,f,uncF0,uncFS);
meanPost = meanStats(post,sensorMisalignDeg,slopesErr,S,f,uncF0,uncFS);

%% CL Graph

figure()
hold on

tapedFillAoACL = [meanTaped.AoA; flipud(meanTaped.AoA)];
conf95CL = [meanTaped.CL+ meanTaped.ErrCL; flipud(meanTaped.CL - meanTaped.ErrCL)];
fill(tapedFillAoACL,conf95CL,'r','FaceAlpha',0.35,'EdgeColor','none','HandleVisibility','off');

noFillAoACL = [meanFair.AoA; flipud(meanFair.AoA)];
conf95CL = [meanFair.CL+ meanFair.ErrCL; flipud(meanFair.CL - meanFair.ErrCL)];
fill(noFillAoACL,conf95CL,'k','FaceAlpha',0.35,'EdgeColor','none','HandleVisibility','off');

% sixFillAoACL = [mean6mm.AoA; flipud(mean6mm.AoA)];
% conf95CL = [mean6mm.CL+ mean6mm.ErrCL; flipud(mean6mm.CL - mean6mm.ErrCL)];
% fill(sixFillAoACL,conf95CL,'g','FaceAlpha',0.35,'EdgeColor','none','HandleVisibility','off');

plot(meanGamma.AoA,meanGamma.CL,'xb',DisplayName='Gamma Check')

plot(meanTaped.AoA,meanTaped.CL,'or',DisplayName='Taped Fairing Gap')

plot(meanFair.AoA,meanFair.CL,'^k',DisplayName='Untaped Fairing Gap')

plot(meanPost.AoA,meanPost.CL,'<m',DisplayName='Teardown Check')

plot(twenteL.x,twenteL.y,'--sq',DisplayName='Twente Wing, Re 105k')

% plot(mean6mm.AoA,mean6mm.CL,'<g',DisplayName='Reduced Root Gap')

legend('Location','southeast')
xlabel('AoA')
ylabel('$C_L$')
theme('light')
% myExportGraphics(gcf,'staticFlexibleLift.eps','C:\Users\James\OneDrive - University of Calgary\Thesis\Ch4\')
%% CD Graph

figure()
hold on

tapedFillAoACD = [meanTaped.AoA; flipud(meanTaped.AoA)];
conf95CD = [-meanTaped.CD+ -meanTaped.ErrCD; flipud(-meanTaped.CD - -meanTaped.ErrCD)];
fill(tapedFillAoACD,conf95CD,'r','FaceAlpha',0.35,'EdgeColor','none','HandleVisibility','off');

sixFillAoACD = [mean6mm.AoA; flipud(mean6mm.AoA)];
conf95CD = [-mean6mm.CD+ -mean6mm.ErrCD; flipud(-mean6mm.CD - -mean6mm.ErrCD)];
fill(sixFillAoACD,conf95CD,'g','FaceAlpha',0.35,'EdgeColor','none','HandleVisibility','off');

plot(meanGamma.AoA,-meanGamma.CD,'xb',DisplayName='Gamma Check')

plot(meanTaped.AoA,-meanTaped.CD,'or',DisplayName='Taped Fairing Gap')

plot(meanFair.AoA,-meanFair.CD,'^k',DisplayName='Untaped Fairing Gap')

plot(meanPost.AoA,-meanPost.CD,'<m',DisplayName='Teardown Check')

plot(twenteD.x,twenteD.y,'--sq',DisplayName='Twente Wing, Re 105k')

plot(mean6mm.AoA,-mean6mm.CD,'<g',DisplayName='Reduced Root Gap')

legend()
xlabel('AoA')
ylabel('$C_D$')
theme('light')
% myExportGraphics(gcf,'staticFlexibleDrag.eps','C:\Users\James\OneDrive - University of Calgary\Thesis\Ch4\')
%%

figure()
hold on

plot(meanTaped.AoA(5:20),1.73*meanTaped.CL(5:20),'-or',DisplayName='Taped Fairing Gap')

plot(twenteL.x,twenteL.y,'--sqb',DisplayName='Twente Wing, Re 105k')

legend('Location','southeast')
xlabel('AoA')
ylabel('$C_L$')
theme('light')
myExportGraphics(gcf,'AdjustedFlexible.eps','C:\Users\James\OneDrive - University of Calgary\Thesis\Ch4\')


adjFlex = 1.73*(meanTaped.CL(20)-meanTaped.CL(10))/deg2rad(meanTaped.AoA(20))
twente = (twenteL.y(9)-twenteL.y(3))/deg2rad(twenteL.x(9))

adjFlex/twente*100

%% Functions --------------------------------------------------------------

function [returnTable,driftStats] = driftProcess(driftTable,dataTable,type,S,f)
    driftIdx = driftTable.Type == type;
    driftData = driftTable(driftIdx,:);
    driftData = sortrows(driftData,["Run" "AoA"]);
    runs = length(unique(driftData.Run));
    driftCLDel = [];
    driftCDDel = [];
    for i =1:runs
        driftCLDel =  [driftCLDel; driftData(driftData.Run==i,:).L(2:end)-driftData(driftData.Run==i,:).L(1:end-1)];
        driftCDDel = [driftCDDel; driftData(driftData.Run==i,:).D(2:end)-driftData(driftData.Run==i,:).D(1:end-1)];
    end

    meanDrCL = mean(driftData.CL);
    meanDrCD = mean(driftData.CD);

    stdDrCL = std(driftData.CL);
    stdDrCD = std(driftData.CD);
    
    stdDrCLDel = std(driftCLDel);
    stdDrCDDel = std(driftCDDel);


    stdDrLDel = std(driftCLDel);
    stdDrDDel = std(driftCDDel);
    
    driftStats = [meanDrCL meanDrCD stdDrCLDel stdDrCDDel stdDrCL stdDrCD];
    driftStats = array2table(driftStats);
    driftStats.Properties.VariableNames = {'MeanCL' 'MeanCD' 'stdCLDel' 'stdCDDel' 'stdCL' 'stdCD'};

    dataIdx = dataTable.Type == type;
    returnTable = dataTable(dataIdx,:);
    returnTable = sortrows(returnTable,["Run" "AoA"]);

    qS = mean(driftTable.q)*S;
    
    srDrCL = ones(height(returnTable),1);
    srDrCL = srDrCL * 2 * sqrt((1/qS)^2*(stdDrLDel^2));
    
    srDrCD = ones(height(returnTable),1);
    srDrCD = srDrCD * 2 * sqrt((1/qS)^2*(stdDrDDel^2));

    returnTable.indCL = (returnTable.CL+f(1))./qS;
    returnTable.indCD = (returnTable.CD+f(2))./qS;
    returnTable.srDrCL = srDrCL;
    returnTable.srDrCD = srDrCD;
end


function [meanTable] = meanStats(table,sensorMisalignDeg,slopesErr,S,f,uncF0,uncFS)
    AoA = unique(table.AoA);
    meanTable = zeros(length(AoA),8);
    meanTable = array2table(meanTable);
    meanTable.Properties.VariableNames = {'AoA' 'q' 'CL' 'CD' 'CM' 'ErrCL' 'ErrCD' 'ErrCM'};
    runs = length(unique(table.Run));

    for alpha = 1:length(AoA)
        lift = mean(table(table.AoA==AoA(alpha),:).CL);
        thrust = mean(table(table.AoA==AoA(alpha),:).CD);
        tempSRCL = sqrt(sum(table(table.AoA==AoA(alpha),:).srCL.^2));
        tempSRCD = sqrt(sum(table(table.AoA==AoA(alpha),:).srCD.^2));
        tempMeanQ = mean(table(table.AoA==AoA(alpha),:).q);
        tempCL = (mean(table(table.AoA==AoA(alpha),:).CL)+f(1))/(tempMeanQ*S);
        tempCD = (mean(table(table.AoA==AoA(alpha),:).CD)+f(2))/(tempMeanQ*S);
        VFx = mean(table(table.AoA==AoA(alpha),:).VFx);
        VFy = mean(table(table.AoA==AoA(alpha),:).VFy);
        VBx = mean(table(table.AoA==AoA(alpha),:).VBx);
        VBy = mean(table(table.AoA==AoA(alpha),:).VBy);

        thrustMisalign = lift*cosd(sensorMisalignDeg)-thrust*sind(sensorMisalignDeg);
        liftMisalign = -lift*sind(sensorMisalignDeg)+thrust*cosd(sensorMisalignDeg);

        thrustBR = sqrt((VFx^2*slopesErr(1,1)^2 + VBx^2*slopesErr(1,2)^2 +  ...
            thrustMisalign^2*deg2rad(sensorMisalignDeg)^2 + uncF0(2)^2 + ...
            uncFS(2)^2)/(tempMeanQ*S)^2 + (thrust/(tempMeanQ^2*S))^2*1.99072^2);

        liftBR = sqrt((VFy^2*slopesErr(2,1)^2 + VBy^2*slopesErr(2,2)^2 + ...
            liftMisalign^2*deg2rad(sensorMisalignDeg)^2 + uncF0(1)^2 + ...
            uncFS(1)^2)/(tempMeanQ*S)^2 + (lift/(tempMeanQ^2*S))^2*1.99072^2);

        tempSRCLTot = sqrt((sum(table(table.AoA==AoA(alpha),:).srDrCL)^2 + tempSRCL^2)/runs^2);
        tempSRCDTot = sqrt((sum(table(table.AoA==AoA(alpha),:).srDrCD)^2 + tempSRCD^2)/runs^2);

        uncCL = sqrt(liftBR.^2 + (4.271*tempSRCLTot).^2);
        uncCD = sqrt(thrustBR.^2 + (4.271*tempSRCDTot).^2);
        
        


        meanTable.AoA(alpha) = AoA(alpha);
        meanTable.CL(alpha) = tempCL;
        meanTable.CD(alpha) = tempCD;
        
        meanTable.q(alpha) = tempMeanQ;
        meanTable.ErrCL(alpha) = uncCL;
        meanTable.ErrCD(alpha) = uncCD;
        
    end
end