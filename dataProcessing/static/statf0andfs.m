

subPath = ["Wing On/" "No Wing/"];
path = subPath;

slopes = [29.574 31.820; 
          30.296 32.028;
          29.3562 30.1330];

intercepts = [-0.0116 -0.0968;...
               0.0886 0.2038];


for i=1:2
    tempFiles = dir(fullfile(path(i),'*.mat'));
    tempFiles = struct2table(tempFiles);
    if i==1
        f0 = zeros(2,height(tempFiles));
    else
        fs = zeros(2,height(tempFiles));
    end
    for j = 1:height(tempFiles)
        tempFData = load(fullfile(path(i),tempFiles.name(j)));
        tempForces = convertForce(tempFData,slopes,intercepts,[]);
        if i==1
            f0(1,j) = mean(tempForces.Lift);
            f0(2,j) = mean(tempForces.Thrust);
        else
            fs(1,j) = mean(tempForces.Lift);
            fs(2,j) = mean(tempForces.Thrust);
        end
    end
end

stdf0 = 2.201*std(f0(:,1:12)')/sqrt(12);
stdfs = 2.201*std(fs(:,1:12)')/sqrt(12);
overallf0 = mean(f0(:,1:12),2);
overallfs = mean(fs(:,1:12),2);

WingOn = table(f0(1,:)',f0(2,:)');
WingOn.Properties.VariableNames = {'Lift Axis' 'Thrust Axis'};

StandOnly = table(fs(1,:)',fs(2,:)');
StandOnly.Properties.VariableNames = {'Lift Axis' 'Thrust Axis'};