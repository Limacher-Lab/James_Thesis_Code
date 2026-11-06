% Location to export figures
imgLoc = 'C:\Users\James\OneDrive - University of Calgary\Thesis\Ch5\';

baseFol = ["Deltas 1\" "Deltas 2\"];
subFol = ["M00\" "M01\" "M02\" "M03\" "M04\" "M05\" "M06\" "M07\" "M08\" "M09\" "M10\"];

slopes = [29.574 31.820; 
          30.296 32.028;
          29.3562 30.1330];

delta1 = dir(fullfile(baseFol(1),"*.mat"));
delta2 = [];
for i=1:length(subFol)
    delta2 = [delta2; dir(fullfile(baseFol(2),subFol(i),"*.mat"))];
end

delta3 = dir(fullfile("Deltas 3","*.mat"));
delta4 = dir(fullfile("Deltas 4","*.mat"));
delta5 = dir(fullfile("Deltas 5","*.mat"));
delta6 = dir(fullfile("Deltas 6","*.mat"));

delta1 = struct2table(delta1);
delta2 = struct2table(delta2);
delta3 = struct2table(delta3);
delta4 = struct2table(delta4);
delta5 = struct2table(delta5);
delta6 = struct2table(delta6);

F0Lift1 = zeros(length(delta1.name),2);
F0Thrust1 = zeros(length(delta1.name),2);

F0Lift2 = zeros(length(delta2.name),2);
F0Thrust2 = zeros(length(delta2.name),2);

F0Lift3 = zeros(length(delta3.name),2);
F0Thrust3 = zeros(length(delta3.name),2);

F0Lift4 = zeros(length(delta4.name),2);
F0Thrust4 = zeros(length(delta4.name),2);

F0Lift5 = zeros(length(delta5.name),2);
F0Thrust5 = zeros(length(delta5.name),2);

F0Lift6 = zeros(length(delta6.name),2);
F0Thrust6 = zeros(length(delta6.name),2);

for i=1:length(delta1.name)
    temp = load(fullfile(baseFol(1),delta1.name(i)));
    F0Lift1(i,1) = str2double(temp.freq);
    F0Thrust1(i,1) = str2double(temp.freq);
    frontThrust = temp.dataCh3*slopes(1,1);
    backThrust = temp.dataCh0*slopes(1,2);
    frontLift = temp.dataCh4*slopes(2,1);
    backLift = temp.dataCh1*slopes(2,2);
    thrust = mean(frontThrust+backThrust);
    lift = mean(frontLift+backLift);
    F0Thrust1(i,2) = thrust;
    F0Lift1(i,2) = lift;
end


for i=1:length(subFol)
    for j=1:9
        temp = load(fullfile(baseFol(2),subFol(i),delta2.name((i-1)*9+j)));
        F0Lift2((i-1)*9+j,1) = str2double(temp.freq);
        F0Thrust2((i-1)*9+j,1) = str2double(temp.freq);
        frontThrust = temp.dataCh3*slopes(1,1);
        backThrust = temp.dataCh0*slopes(1,2);
        frontLift = temp.dataCh4*slopes(2,1);
        backLift = temp.dataCh1*slopes(2,2);
        thrust = mean(frontThrust+backThrust);
        lift = mean(frontLift+backLift);
        F0Thrust2((i-1)*9+j,2) = thrust;
        F0Lift2((i-1)*9+j,2) = lift;
    end
end

for i=1:length(delta3.name)
    temp = load(fullfile("Deltas 3",delta3.name(i)));
    F0Lift3(i,1) = str2double(temp.freq);
    F0Thrust3(i,1) = str2double(temp.freq);
    frontThrust = temp.dataCh3*slopes(1,1);
    backThrust = temp.dataCh0*slopes(1,2);
    frontLift = temp.dataCh4*slopes(2,1);
    backLift = temp.dataCh1*slopes(2,2);
    thrust = mean(frontThrust+backThrust);
    lift = mean(frontLift+backLift);
    F0Thrust3(i,2) = thrust;
    F0Lift3(i,2) = lift;
end

for i=1:length(delta4.name)
    temp = load(fullfile("Deltas 4",delta4.name(i)));
    F0Lift4(i,1) = str2double(temp.freq);
    F0Thrust4(i,1) = str2double(temp.freq);
    frontThrust = temp.dataCh3*slopes(1,1);
    backThrust = temp.dataCh0*slopes(1,2);
    frontLift = temp.dataCh4*slopes(2,1);
    backLift = temp.dataCh1*slopes(2,2);
    thrust = mean(frontThrust+backThrust);
    lift = mean(frontLift+backLift);
    F0Thrust4(i,2) = thrust;
    F0Lift4(i,2) = lift;
end

for i=1:length(delta5.name)
    temp = load(fullfile("Deltas 5",delta5.name(i)));
    F0Lift5(i,1) = str2double(temp.freq);
    F0Thrust5(i,1) = str2double(temp.freq);
    frontThrust = temp.dataCh3*slopes(1,1);
    backThrust = temp.dataCh0*slopes(1,2);
    frontLift = temp.dataCh4*slopes(2,1);
    backLift = temp.dataCh1*slopes(2,2);
    thrust = mean(frontThrust+backThrust);
    lift = mean(frontLift+backLift);
    F0Thrust5(i,2) = thrust;
    F0Lift5(i,2) = lift;
end

for i=1:length(delta6.name)
    temp = load(fullfile("Deltas 6",delta6.name(i)));
    F0Lift6(i,1) = str2double(temp.freq);
    F0Thrust6(i,1) = str2double(temp.freq);
    frontThrust = temp.dataCh3*slopes(1,1);
    backThrust = temp.dataCh0*slopes(1,2);
    frontLift = temp.dataCh4*slopes(2,1);
    backLift = temp.dataCh1*slopes(2,2);
    thrust = mean(frontThrust+backThrust);
    lift = mean(frontLift+backLift);
    F0Thrust6(i,2) = thrust;
    F0Lift6(i,2) = lift;
end

deltaF0Thrust1 = zeros(length(F0Thrust1)-1,2);
deltaF0Thrust2 = zeros(length(F0Thrust2)-1,2);
deltaF0Thrust3 = zeros(length(F0Thrust3)-1,2);
deltaF0Thrust4 = zeros(length(F0Thrust4)-1,2);
deltaF0Thrust5 = zeros(length(F0Thrust5)-1,2);
deltaF0Thrust6 = zeros(length(F0Thrust6)-1,2);
deltaF0Lift1 = zeros(length(F0Lift1)-1,2);
deltaF0Lift2 = zeros(length(F0Lift2)-1,2);
deltaF0Lift3 = zeros(length(F0Lift3)-1,2);
deltaF0Lift4 = zeros(length(F0Lift4)-1,2);
deltaF0Lift5 = zeros(length(F0Lift5)-1,2);
deltaF0Lift6 = zeros(length(F0Lift6)-1,2);

deltaF0Thrust1(:,1) = F0Thrust1(1:end-1,1);
deltaF0Thrust1(:,2) = F0Thrust1(2:end,2)-F0Thrust1(1:end-1,2);
deltaF0Lift1(:,1) = F0Lift1(1:end-1,1);
deltaF0Lift1(:,2) = F0Lift1(2:end,2)-F0Lift1(1:end-1,2);

deltaF0Thrust2(:,1) = F0Thrust2(1:end-1,1);
deltaF0Thrust2(:,2) = F0Thrust2(2:end,2)-F0Thrust2(1:end-1,2);
deltaF0Lift2(:,1) = F0Lift2(1:end-1,1);
deltaF0Lift2(:,2) = F0Lift2(2:end,2)-F0Lift2(1:end-1,2);

deltaF0Thrust3(:,1) = F0Thrust3(1:end-1,1);
deltaF0Thrust3(:,2) = F0Thrust3(2:end,2)-F0Thrust3(1:end-1,2);
deltaF0Lift3(:,1) = F0Lift3(1:end-1,1);
deltaF0Lift3(:,2) = F0Lift3(2:end,2)-F0Lift3(1:end-1,2);

deltaF0Thrust4(:,1) = F0Thrust4(1:end-1,1);
deltaF0Thrust4(:,2) = F0Thrust4(2:end,2)-F0Thrust4(1:end-1,2);
deltaF0Lift4(:,1) = F0Lift4(1:end-1,1);
deltaF0Lift4(:,2) = F0Lift4(2:end,2)-F0Lift4(1:end-1,2);

deltaF0Thrust5(:,1) = F0Thrust5(1:end-1,1);
deltaF0Thrust5(:,2) = F0Thrust5(2:end,2)-F0Thrust5(1:end-1,2);
deltaF0Lift5(:,1) = F0Lift5(1:end-1,1);
deltaF0Lift5(:,2) = F0Lift5(2:end,2)-F0Lift5(1:end-1,2);

deltaF0Thrust6(:,1) = F0Thrust6(1:end-1,1);
deltaF0Thrust6(:,2) = F0Thrust6(2:end,2)-F0Thrust6(1:end-1,2);
deltaF0Lift6(:,1) = F0Lift6(1:end-1,1);
deltaF0Lift6(:,2) = F0Lift6(2:end,2)-F0Lift6(1:end-1,2);

F0Thrust = [F0Thrust1; F0Thrust2; F0Thrust3; F0Thrust4; F0Thrust5; F0Thrust6];
F0Lift = [F0Lift1; F0Lift2; F0Lift3; F0Lift4; F0Lift5; F0Lift6];

deltaF0Thrust = [deltaF0Thrust1; deltaF0Thrust2; deltaF0Thrust3; deltaF0Thrust4; deltaF0Thrust5; deltaF0Thrust6];
deltaF0Lift = [deltaF0Lift1; deltaF0Lift2; deltaF0Lift3; deltaF0Lift4; deltaF0Lift5; deltaF0Lift6];

%%

figure()
hold on
plot(deltaF0Thrust(:,2),'DisplayName','$\Delta T_{ref}$')
plot(deltaF0Lift(:,2),'DisplayName','$\Delta L_{ref}$')
legend()
xlabel('Run Number')
ylabel('$\Delta F_{ref}$ (N)')
grid on
theme('light')
myExportGraphics(gcf,'deltasOrder.eps','C:\Users\James\OneDrive - University of Calgary\Thesis\Ch5\')

%%

figure()
hold on
box1 = boxplot(deltaF0Lift(:,2),deltaF0Lift(:,1),'whisker',100);
set(box1,'LineWidth',2)
xlabel('Frequency Inbetween Tests (Hz)')
ylabel('$\Delta L_{ref}$ (N)')
grid on
theme('light')
myExportGraphics(gcf,'LWhisker.eps','C:\Users\James\OneDrive - University of Calgary\Thesis\Ch5\')

%%

figure()
hold on
box2 = boxplot(deltaF0Thrust(:,2),deltaF0Thrust(:,1),'whisker',100);
set(box2,'LineWidth',2)
xlabel('Frequency Inbetween Tests (Hz)')
ylabel('$\Delta T_{ref}$ (N)')
grid on
theme('light')
myExportGraphics(gcf,'TWhisker.eps','C:\Users\James\OneDrive - University of Calgary\Thesis\Ch5\')

%%

mean(deltaF0Thrust(:,2))
mean(deltaF0Lift(:,2))

std(deltaF0Thrust(:,2))
std(deltaF0Lift(:,2))

%%
figure()
histogram(deltaF0Thrust(:,2),'binwidth',0.025,'DisplayName','Thrust Delta')
% title('Thrust Delta Distribution')
xlabel('$\Delta T_{ref}$ (N)')
ylabel("Number of Occurences")
myExportGraphics(gcf,'thrustDeltaDist.eps','C:\Users\James\OneDrive - University of Calgary\Thesis\Ch5\')

figure()
histogram(deltaF0Lift(:,2),'binwidth',0.01,'DisplayName','Lift Delta')
% title('Lift Delta Distribution')
xlabel('$\Delta L_{ref}$ (N)')
ylabel('Number of Occurences')
myExportGraphics(gcf,'liftDeltaDist.eps','C:\Users\James\OneDrive - University of Calgary\Thesis\Ch5\')