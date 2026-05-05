function msocketSendSI(sendThisSI,ExpStruct)

% then get handshake from SI
invar=[]; t=tic;
while (~strcmp(invar,'start') && ~strcmp(invar,'received') ) && toc(t)<0.2
    invar = msrecv(ExpStruct.SISocket,.5);
end
toc(t)
if toc(t)>0.2
    disp('SI handshake error')
else
    disp(['recieved handshake from SI, it says ' invar]);
end
flushMSocket(ExpStruct.SISocket);

% sendThisSI.ExpStruct = ExpStruct;

disp('sending to SI');
mssend(ExpStruct.SISocket, sendThisSI);