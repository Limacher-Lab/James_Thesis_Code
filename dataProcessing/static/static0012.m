clc
clear

setupType = ["Old Gear" "Gear Check" "StaticFinal"];
biasFolder = setupType+"\Biases";
numFolders = length(setupType);
g = 9.81;
S = 0.049;
c = 0.13;

slopes = [29.574 31.820;...
          30.296 32.028];

intercepts = [-0.0116 -0.0968;...
               0.0886 0.2038];

slopesErr = [0.2147 0.0381;...
             0.0204 0.0402];

interceptsErr = [0.0741 0.0931;...
                 0.0887 0.1179];

sensorMisalignDeg = 1.70;

dataSets = cell(1);

biasSets = cell(1);

dataLength = 0;
biasDataLength = 0;

for folNum=1:numFolders
    tempData = dir(fullfile(setupType(folNum),'*.mat'));
    tempData = struct2table(tempData);
    dataSets{folNum} = tempData;

    tempLength = length(tempData.name)/2;
    dataLength = dataLength+tempLength;

    tempBias = dir(fullfile(biasFolder(folNum),'*.mat'));
    tempBias = struct2table(tempBias);
    biasSets{folNum} = tempData;

    tempBiasLength = length(tempBias.name);
    biasDataLength = biasDataLength + tempBiasLength;
end


dataTable = zeros(dataLength,16);
dataTable = array2table(dataTable);
dataTable.Properties.VariableNames = {'Type' 'Run' 'AoA' 'q' 'CL' 'CD' 'rawCL' 'rawCD' 'srCL' 'srCD' 'VFx' 'VFy' 'VBx' 'VBy' 'Lift' 'Drag'};
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


for setupNum = 1:numFolders

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

        thrustFront = tempData.dataCh3Biased*slopes(1,1)+intercepts(1,1)-thDriftFront;
        thrustBack = tempData.dataCh0Biased*slopes(1,2)+intercepts(1,2)-thDriftBack;
        liftFront = tempData.dataCh4Biased*slopes(2,1)+intercepts(2,1)-liDriftFront;
        liftBack = tempData.dataCh1Biased*slopes(2,2)+intercepts(2,2)-liDriftBack;

        rawTF = thrustFront+thDriftFront;
        rawTB = thrustBack+thDriftBack;
        rawLF = liftFront+liDriftFront;
        rawLB = liftBack+liDriftBack;

        tDrift = thDriftFront+thDriftBack;
        lDrift = -(liDriftFront+liDriftBack);
        qVoltDrift = tempDrift.pressureBiased;
        qDrift = qVoltDrift*497.68/10;
        qDriftMean = mean(qDrift);

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
        CL = mean(lift)/(meanQ*S);
        CD = mean(thrust)/(meanQ*S);

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
        dataTable.Lift(setNum+tracker) = mean(lift);
        dataTable.Drag(setNum+tracker) = mean(thrust);

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


[oldGear,oldGearDriftStats] = driftProcess(driftTable,dataTable,'Taped0012',S,c);
[newGear,newGearDriftStats] = driftProcess(driftTable,dataTable,'GearCheck',S,c);
[final,finalDriftStats] = driftProcess(driftTable,dataTable,'StaticFinal',S,c);

meanOld = meanStats(oldGear,sensorMisalignDeg,slopesErr,S);
meanNew = meanStats(newGear,sensorMisalignDeg,slopesErr,S);
meanFinal = meanStats(final,sensorMisalignDeg,slopesErr,S);

maxIdx = meanFinal.CL == max(meanFinal.CL);
maxCL = meanFinal(maxIdx,:).CL;
maxAoA = deg2rad(meanFinal(maxIdx,:).AoA);

%%

OhtakeL = readtable("StaticFinal\Ohtake Lift Data.csv");
OhtakeD = readtable("StaticFinal\Ohtake Drag Data.csv");
FloresCL = readtable("StaticFinal\Flores CL.csv");
FloresCD = readtable("StaticFinal\Flores CD.csv");
OhtakeL = sortrows(OhtakeL,"x");
OhtakeD = sortrows(OhtakeD,"x");

fullGeom = 'ellWing.csv';
halfGeom = 'ellHalfWing.csv';
ohtCL = "Ohtake LLT Data.csv";
lltAoA = -11:0.5:13;

[OhtakeFull, ~, ~, ~, ~] = liftingline( ...
    fullGeom, ohtCL, lltAoA);

[OhtakeHalf, ~, ~, ~, ~] = liftingline( ...
    halfGeom, ohtCL, lltAoA);

% OhtakeMod = (OhtakeL.y)/(1+(2/6.9));
slopeOh = OhtakeL.y(42)/deg2rad(OhtakeL.x(42));
slopeOhAdjusted = (slopeOh/(1+2/(6.9)));
slopeWing = maxCL/maxAoA;
percentSlope = slopeWing/slopeOhAdjusted*100;


%%%%%%%%%%%%%%%%%%%%
%% Drift Corrected Coefficients
figure()
hold on
% title('Drift Corrected')
for i = 1:length(final.Run)
    plot(final(final.Run==i,:).AoA,final(final.Run==i,:).CL,'-x',DisplayName=sprintf('Run %i',i))
end
legend()
xlabel('Angle of Attack ($^\circ$)');
ylabel('Coefficients');
ylim([-1 1])
yticks(-1:0.2:1)
xlim([-25 25])
xticks(-25:5:25)
ax = gca;
ax.ColorOrderIndex = 1;
for i = 1:length(final.Run)
    plot(final(final.Run==i,:).AoA,-final(final.Run==i,:).CD,'-o','HandleVisibility','off')
end
theme("light")
myExportGraphics(gcf,'driftCorr0012.eps','C:\Users\James\OneDrive - University of Calgary\Thesis\Ch4\')

%% No Drift Correction Coefficients

figure()
hold on
% title('Not Drift Corrected')
for i = 1:length(final.Run)
    plot(final(final.Run==i,:).AoA,final(final.Run==i,:).rawCL,'-x',DisplayName=sprintf('Run %i',i))
end
legend()
xlabel('Angle of Attack ($^\circ$)');
ylabel('Coefficients');
ax = gca;
ax.ColorOrderIndex = 1;
for i = 1:length(final.Run)
    plot(final(final.Run==i,:).AoA,-final(final.Run==i,:).rawCD,'-o','HandleVisibility','off')
end
theme("light")
ylim([-1 1])
yticks(-1:0.2:1)
xlim([-25 25])
xticks(-25:5:25)
myExportGraphics(gcf,'noDriftCorr0012.eps','C:\Users\James\OneDrive - University of Calgary\Thesis\Ch4\')

%% CL Comparison

figure()
hold on
fillAoA = [meanFinal.AoA; flipud(meanFinal.AoA)];
conf95CL = [meanFinal.CL+ meanFinal.ErrCL; flipud(meanFinal.CL - meanFinal.ErrCL)];
conf95CD = [meanFinal.CD+ meanFinal.ErrCD; flipud(meanFinal.CD - meanFinal.ErrCD)];
plot(-25:1:25,deg2rad(-25:1:25)*2*pi,'Color','black',displayName = 'Thin Airfoil Theory',LineWidth=1)
fill(fillAoA,conf95CL,'b','FaceAlpha',0.35,'EdgeColor','none','HandleVisibility','off');
plot(meanFinal.AoA,meanFinal.CL,'-xb',DisplayName='Current Elliptic NACA 0012     ')
plot(FloresCL.x,FloresCL.y,'o',DisplayName='Flores NACA 0015 Wing')
plot(OhtakeL.x,OhtakeL.y,'+r',DisplayName='Ohtake NACA 0012 Airfoil')
legend()
xlabel('Angle of Attack ($^\circ$)');
ylabel('$C_L$');
theme("light")
ylim([-1 1])
xlim([-25 25])
xticks(-25:5:25)
myExportGraphics(gcf,'L0012comparison.eps','C:\Users\James\OneDrive - University of Calgary\Thesis\Ch4\')

%% CD Comparison

figure()
hold on
fill(fillAoA,-conf95CD,'b','FaceAlpha',0.35,'EdgeColor','none','HandleVisibility','off');
plot(0,0*2*pi,'ok',displayName = 'Thin Airfoil Theory',LineWidth=1)
plot(meanFinal.AoA,-meanFinal.CD,'-xb',DisplayName='Current Elliptic NACA 0012')
plot(FloresCD.x,-FloresCD.y,'o',DisplayName='Flores NACA 0015 Wing')
plot(OhtakeD.x,OhtakeD.y,'+r',DisplayName='Ohtake NACA 0012 Airfoil')
legend('Location','southwest')
xlabel('Angle of Attack ($^\circ$)');
ylabel('$C_D$');
theme("light")
xlim([-25 25])
xticks(-25:5:25)
myExportGraphics(gcf,'D0012comparison.eps','C:\Users\James\OneDrive - University of Calgary\Thesis\Ch4\')

%% CL Comparison

figure()
hold on
% title('Raw $C_n$ vs AoA Corrected Airfoil')
fillAoA = [meanFinal.AoA; flipud(meanFinal.AoA)];
conf95CL = [meanFinal.CL+ meanFinal.ErrCL; flipud(meanFinal.CL - meanFinal.ErrCL)];
conf95CD = [meanFinal.CD+ meanFinal.ErrCD; flipud(meanFinal.CD - meanFinal.ErrCD)];
% plot(-25:1:25,deg2rad(-25:1:25)*2*pi,'Color','black',displayName = 'Thin Airfoil Theory',LineWidth=1)
fill(fillAoA,conf95CL,'b','FaceAlpha',0.35,'EdgeColor','none','HandleVisibility','off');
plot(OhtakeL.x,OhtakeL.y,'+g',DisplayName='Ohtake NACA 0012 Airfoil')
plot(meanFinal.AoA,meanFinal.CL,'-xb',DisplayName='Current Elliptic NACA 0012')
plot(lltAoA,OhtakeFull,'r',DisplayName='Full Wing LLT')
plot(lltAoA,OhtakeHalf,'k',DisplayName='Half Wing LLT')

legend()
xlabel('Angle of Attack ($^\circ$)');
ylabel('$C_L$');
theme("light")
ylim([-1 1])
xlim([-25 25])
xticks(-25:5:25)
myExportGraphics(gcf,'LvsLLT0012.eps','C:\Users\James\OneDrive - University of Calgary\Thesis\Ch4\')

%% Functions

function [returnTable,driftStats] = driftProcess(driftTable,dataTable,type,S,c)
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

    returnTable.indCL = returnTable.CL./qS;
    returnTable.indCD = returnTable.CD./qS;
    returnTable.srDrCL = srDrCL;
    returnTable.srDrCD = srDrCD;
end


function [meanTable] = meanStats(table,sensorMisalignDeg,slopesErr,S)
    AoA = unique(table.AoA);
    meanTable = zeros(length(AoA),8);
    meanTable = array2table(meanTable);
    meanTable.Properties.VariableNames = {'AoA' 'q' 'CL' 'CD' 'CM' 'ErrCL' 'ErrCD' 'ErrCM'};
    runs = length(unique(table.Run));

    for alpha = 1:length(AoA)
        lift = mean(table(table.AoA==AoA(alpha),:).Lift);
        thrust = mean(table(table.AoA==AoA(alpha),:).Drag);
        tempSRCL = sqrt(sum(table(table.AoA==AoA(alpha),:).srCL.^2));
        tempSRCD = sqrt(sum(table(table.AoA==AoA(alpha),:).srCD.^2));
        tempMeanQ = mean(table(table.AoA==AoA(alpha),:).q);
        tempCL = mean(table(table.AoA==AoA(alpha),:).CL);
        tempCD = mean(table(table.AoA==AoA(alpha),:).CD);
        VFx = mean(table(table.AoA==AoA(alpha),:).VFx);
        VFy = mean(table(table.AoA==AoA(alpha),:).VFy);
        VBx = mean(table(table.AoA==AoA(alpha),:).VBx);
        VBy = mean(table(table.AoA==AoA(alpha),:).VBy);

        thrustMisalign = lift*cosd(sensorMisalignDeg)-thrust*sind(sensorMisalignDeg);
        liftMisalign = -lift*sind(sensorMisalignDeg)-thrust*cosd(sensorMisalignDeg);

        thrustBR = sqrt((VFx^2*slopesErr(1,1)^2 + VBx^2*slopesErr(1,2)^2 +  ...
            thrustMisalign^2*deg2rad(sensorMisalignDeg)^2)/(tempMeanQ*S)^2 + ...
            (thrust/(tempMeanQ^2*S))^2*1.99072^2);

        liftBR = sqrt((VFy^2*slopesErr(2,1)^2 + VBy^2*slopesErr(2,2)^2 + ...
            liftMisalign^2*deg2rad(sensorMisalignDeg)^2)/(tempMeanQ*S)^2 + ...
            (lift/(tempMeanQ^2*S))^2*1.99072^2);

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
