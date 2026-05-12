%MESOHOLO-DOC
% mesoholo — mesoscale holography code (Abdeladim et al., 2026).
% Relative path in repository: matlab/rig/holo_computer/ShootSequencesMsocket.m
% See README.md at repo root and docs/DEPENDENCIES.md for setup and hardware notes.
%

function [T,O] = ShootSequencesMsocket(Setup,sequences,masterSocket);
flushMSocket(masterSocket);
% global T

sendVar = 'C';
mssend(masterSocket,sendVar);


order = [];
disp('waiting for socket to send sequence number')
while isempty(order)
    order = msrecv(masterSocket,.5); %% order is the same as sendThis being sent from DAQ
                                     %%% i.e., current sequence of holograms on this trial
end
disp(['received sequence of length ' num2str(length(order))]);

if any(order>length(sequences))
    disp('ERROR: Sequence error. blanking SLM...')
    blank = zeros(size(sequences{1}));
    outcome = Function_Feed_SLM(Setup.SLM, blank);
    return
end

T=zeros([1 10E5]);
O = zeros([1 10E5]);

timeout = false;
counter = 1;

% while (~timeout || ~timeout) && counter<=length(order)
for i=1:length(order)
     t=tic;
    currorder = order(i);
    
%     outcome = Function_Feed_SLM(Setup.SLM, sequences{currorder});
    calllib('Blink_C_wrapper', 'Write_image', 1, sequences{currorder}, ...
        1920*1152, Setup.SLM.wait_For_Trigger, ...
        Setup.SLM.external_Pulse, Setup.SLM.timeout_ms);
    outcome = calllib('Blink_C_wrapper', 'ImageWriteComplete', 1, ...
        Setup.SLM.timeout_ms);

    T(counter)=toc(t);
%     disp(T(1:counter));
    O(counter) = outcome;
%     if(i==1)
%         t=tic;
%     end
    if outcome == -1
        timeout = true;
        breakpoint = i;
        break;
    end
%     fprintf('%d ',i)
%     counter = counter+1;
end


if ~timeout
    disp(['completed sequence to the end, took ',num2str(toc(t)),' seconds'])
else
%     disp(['timeout while waiting to display hologram orders ' num2str(counter-1)]);
    disp(['timeouts while waiting to display hologram orders ' num2str(breakpoint)]);
end