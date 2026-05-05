clear all
% Put a hologram on the SLM in Holo computer. Setup internal power to a
% fixed value. 
holo = [0.55,0.55,0,1];
sendgalvo = 1;
if(sendgalvo)
    disp('going to connect to SI to send galvo info');
    SISocket = SImsocketPrep;
    ExpStruct.SISocket = SISocket;
end
%---------------------------------------------------------

livepowerpath = ['C:\Users\MesoHolo\Desktop\livepower\livepower.csv'];
powerwaittime = 8;
waitdisptime = 2;
voltages0 = linspace(-2,2,9);
voltages1 = linspace(-2,2,9);
power = zeros(length(voltages0),length(voltages1));
for i =1:length(voltages0)
    for j =1:length(voltages1)
         sendgalvo = [voltages0(i),voltages1(j)];
        if ~isempty(sendgalvo)
                invar=[]; t= tic;
                while ~strcmp(invar,'C') && toc(t)<0.1;
                    invar = msrecv(ExpStruct.SISocket,.5);
                end
                if toc(t)>0.5
                    disp('SI computer handshake error')
                else
                    disp('received handshake from SI computer ');
                end
                mssend(ExpStruct.SISocket, sendgalvo) ;
               
        end   
        pause(powerwaittime );
        mpowlist = importdata(livepowerpath,'\t',15);
        mpows = mpowlist.data;
        currpow = max(mpows(end-powerwaittime+1:end));
    
    power(i,j) = currpow;
    disp(['Current power : ',num2str(currpow),'W'])
    
    end
end

power = power*1000;
powerNorm = power/power(5,5);
powerNorm = 1./powerNorm;
