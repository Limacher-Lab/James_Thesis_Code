function [cosParam, posOut, velOut, torOut] = cosRegressPow(data,figOn)
% The pitch motor in this file version has no gear ratio conversion. So use
% "Pitch" for power calibration purposes (the power calibration has no gear
% reduction in the process)

data = array2table(data);
allVars = 1:width(data);
varNames = ["pTime" "pos" "vTime" "vel" "tTime" "tor"];
data = renamevars(data,allVars,varNames);

emptyPosIdx = data.pTime <=0;
pos = data(~emptyPosIdx,1:2);

emptyVelIdx = data.vTime <= 0;
vel = data(~emptyVelIdx,3:4);

emptyTorIdx = data.tTime <= 0;
tor = data(~emptyTorIdx,5:6);

commonTimeVec = (0:0.0005:max(pos.pTime));
posComm = interp1(pos.pTime,pos.pos,commonTimeVec);
velComm = interp1(vel.vTime,vel.vel,commonTimeVec);
torComm = interp1(tor.tTime,tor.tor,commonTimeVec);

pMax = max(posComm);
pMin = min(posComm);
pRange = pMax-pMin;
pCentered = posComm-pMax+pRange/2;
pCrossing = commonTimeVec(pCentered.*circshift(pCentered,[0 1])<=0);
period = 2*mean(diff(pCrossing));
cycs = length(pCrossing)/2;
freq = 1/period;
totalTime = cycs*period;

removePosCommIdx = isnan(posComm) | commonTimeVec > totalTime;
commonPosTime = commonTimeVec(~removePosCommIdx);
posComm(removePosCommIdx) = [];

removeVelCommIdx = isnan(velComm) | commonTimeVec > totalTime;
commonVelTime = commonTimeVec(~removeVelCommIdx);
velComm(removeVelCommIdx) = [];

removeTorCommIdx = isnan(torComm) | commonTimeVec > totalTime;
commonTorTime = commonTimeVec(~removeTorCommIdx);
torComm(removeTorCommIdx) = []; 

pMean = mean(posComm);

fit = @(b,t) b(1).*(-cos(2*pi*t.*b(2)+pi/180*b(3)))+b(4);
fcn = @(b) sum((fit(b,commonPosTime)-posComm).^2);
cosParam = fminsearch(fcn, [pRange/2; freq; -15; pMean]);
cosParam(1) = cosParam(1)*90/1600;
cosParam(4) = cosParam(4)*90/1600;

posComm = posComm*90/1600;
velComm = velComm*2*pi/60;
torComm = torComm*7.4/100;

posOut = table(commonPosTime',posComm');
posOut.Properties.VariableNames = {'Time' 'Pos'};

velOut = table(commonVelTime',velComm');
velOut.Properties.VariableNames = {'Time' 'Vel'};

torOut = table(commonTorTime',torComm');
torOut.Properties.VariableNames = {'Time' 'Tor'};

if figOn == true
    % period
    pTimeIdx = data.pTime>=11*period & data.pTime<=14*period;
    figure()
    hold on
    plot(data.pTime(pTimeIdx),data.pos(pTimeIdx)*180/3200,'--o','DisplayName','Measured Value')
    plot(commonTimeVec,cosParam(1)*(-cos(2*pi*commonTimeVec*cosParam(2)+pi/180*cosParam(3)))+cosParam(4),'DisplayName','Fitted Curve')
    % plot(commonPosTime,posComm)
    ylim([-50 50])
    xlim([1.6005 1.734])
    xlabel('Time (s)')
    ylabel('Position ($^\circ$)')
    legend()
end

end