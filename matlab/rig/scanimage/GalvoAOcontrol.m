
%This allows you to give analog signals to X and Y galvos (instead of using
%NImax). WARNING: Never use voltages outside the -5 to 5 V range (safety
%lock anyways)

s = daq.createSession('ni');
addAnalogOutputChannel(s,'Dev1','ao0','Voltage');
addAnalogOutputChannel(s,'Dev1','ao1','Voltage');
rate = 20000;%Daq sampling rate in Hz
outputVoltageX = 0;%in volts AO0
outputVoltageY = 0.5;%in volts AO1
duration = 5; % duration in seconds for the continuous output

%Safety lock
outputVoltageX = max(min(outputVoltageX,5),-5);
outputVoltageY = max(min(outputVoltageY,5),-5);

%Create a time vector and corresponding voltage signal 

time = linspace(0,duration,duration*rate);
voltageSignalX = outputVoltageX * ones(size(time));
voltageSignalY = outputVoltageY * ones(size(time));
s.Rate = rate;
queueOutputData(s,[voltageSignalX',voltageSignalY']);
%Start the session in continuous mode
s.IsContinuous = true;
lh = addlistener(s,'DataRequired',@(src,event) src.queueOutputdata([voltageSignalX',voltageSignalY']));

startBackground(s);

pause(duration);
stop(s);
delete(lh);
release(s);