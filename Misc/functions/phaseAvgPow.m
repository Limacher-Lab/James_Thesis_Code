function [powOut] = phaseAvgPow(C_P,cycs,actFreq)

CP = C_P(1:floor(length(C_P)/cycs),2);
nonDimT = C_P(1:floor(length(C_P)/cycs),1)*actFreq;

for k=2:cycs
    CP2 = C_P((k-1)*length(CP)+1:k*length(CP),2);
    CP = CP + CP2;
end
CP = CP/cycs;

powOut = table(nonDimT,CP);
powOut.Properties.VariableNames = {'nonT' 'CP'};

end