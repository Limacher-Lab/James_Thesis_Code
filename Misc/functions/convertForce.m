function [forceDataOut] = convertForce(forceData,slopes,intercepts,drift)

time = forceData.timeVec;
thrustFront = forceData.dataCh3Biased.*slopes(1,1)+intercepts(1,1);
thrustBack = forceData.dataCh0Biased.*slopes(1,2)+intercepts(1,2);
liftFront = forceData.dataCh4Biased.*slopes(2,1)+intercepts(2,1);
liftBack = forceData.dataCh1Biased.*slopes(2,2)+intercepts(2,2);
sideFront = forceData.dataCh5.*slopes(3,1);
sideBack = forceData.dataCh2.*slopes(3,2);

if ~isempty(drift)
    side = sideFront+sideBack-drift(3);
    thrust = thrustFront+thrustBack-drift(2);
    lift = -(liftFront+liftBack+drift(1));
else
    side = sideFront+sideBack;
    thrust = thrustFront+thrustBack; 
    lift = -(liftFront+liftBack);
end
% fSamp = 1/(time(2)-time(1));
% ny = 0.5*fSamp;
% wn = [23 30]/ny;
% 
% thrust = wedgeFilter(thrust,wn,'wedge');
% lift = wedgeFilter(lift,wn,'wedge');
% side = wedgeFilter(side,wn,'wedge');

% figure()
% plot(time,thrust)

forceDataOut = table(time,thrust,lift,side);
forceDataOut.Properties.VariableNames = {'Time' 'Thrust' 'Lift' 'Side'};

end