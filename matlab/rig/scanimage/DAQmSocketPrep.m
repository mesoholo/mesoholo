% holoRequest

mesoholo_setup();

msocketPath = getenv("MESOHOLO_MSOCKET_PATH");
if strlength(msocketPath) > 0
    addpath(genpath(char(msocketPath)));
end
MasterIP = '128.32.177.163';
global DAQSocket
disp('waiting to connect')
DAQSocket = msconnect(MasterIP, 3040);
disp('waiting for var')
invar = msrecv(DAQSocket,.5);


while ~strcmp(invar, 'A')
    invar = msrecv(DAQSocket, .5);
end
disp('received validation from daq')
mssend(DAQSocket, 'B');

%%

