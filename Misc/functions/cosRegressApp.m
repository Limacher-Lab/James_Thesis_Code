function [cosParam, posOut, velOut, torOut, minData] = cosRegressApp(data,motor)

% This function is for use with apparatus test data because it gives back
% the pitch or stroke motion of the wing on the apparatus. It does this by
% removing the 3:1 ratio of the stroke motor motion compared to the wing
% stroke motion or removing the motion of the pitch motor required to
% eliminate the relative motion inside the gearbox from the stroke motion.

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

minData = min([height(pos), height(vel), height(tor)]);

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

if strcmpi(motor, "Pitch")
    posComm = (posComm + 631*cos(2*pi*cosParam(2)*commonPosTime)-124)*-90/1600;
elseif strcmpi(motor, "stroke")
    posComm = (posComm/3)*90/1600;
end
velComm = velComm*(-2*pi/60);
torComm = torComm*(-7.4/100);

posOut = table(commonPosTime',posComm');
posOut.Properties.VariableNames = {'Time' 'Pos'};

velOut = table(commonVelTime',velComm');
velOut.Properties.VariableNames = {'Time' 'Vel'};

torOut = table(commonTorTime',torComm');
torOut.Properties.VariableNames = {'Time' 'Tor'};
end