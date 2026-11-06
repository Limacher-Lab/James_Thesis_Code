function [forcesOut] = phaseAvgForces(forces,cycs,actFreq,filt)

lift = forces.Lift(1:length(forces.Time)/cycs);
thrust = forces.Thrust(1:length(forces.Time)/cycs);
side = forces.Side(1:length(forces.Time)/cycs);
nonDimT = forces.Time(1:length(forces.Time)/cycs)*actFreq;

for k=2:cycs
    lift2 = forces.Lift((k-1)*length(lift)+1:k*length(lift));
    lift = lift + lift2;

    thrust2 = forces.Thrust((k-1)*length(thrust)+1:k*length(thrust));
    thrust = thrust + thrust2;

    side2 = forces.Side((k-1)*length(thrust)+1:k*length(thrust));
    side = side + side2;
end
lift = lift/cycs;
thrust = thrust/cycs;
side = side/cycs;

if filt == true
    fSamp = 1/(forces.Time(2)-forces.Time(1));
    ny = 0.5*fSamp;
    wn = [23 30]/ny;
    lift = wedgeFilter(lift,wn,'wedge');
    thrust = wedgeFilter(thrust,wn,'wedge');
    side = wedgeFilter(side,wn,'wedge');
end

forcesOut = table(nonDimT,lift,thrust,side);
forcesOut.Properties.VariableNames = {'nonT' 'Lift' 'Thrust' 'Side'};

end