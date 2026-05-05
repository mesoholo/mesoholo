function Get = function_Eval3DCoC(CoC,Ask,modelterms)

FitX = CoC.FitX;
FitY = CoC.FitY;
FitZ = CoC.FitZ;

GetX = polyvaln(FitX,Ask);
GetY = polyvaln(FitY,Ask);
GetZ = polyvaln(FitZ,Ask);

% GetX = FitX(Ask(:,1));
% GetY = FitY(Ask(:,2));
% GetZ = FitZ(Ask(:,3));

% GetX = Ask*FitX(2:end)+FitX(1);
% GetY = Ask*FitY(2:end)+FitY(1);
% GetZ = Ask*FitZ(2:end)+FitZ(1);

% Get = polifyAsk(Ask,modelterms)*CoC.FitB;
% Get = [ones(size(Ask,1),1),Ask]*CoC.FitB(1:4,:);

Get = [GetX GetY GetZ]; 