function [ col,row,numNonNanElements ] = getFOVtocalibrate( array, display,exp )
%getFOVtocalibrate Calculates the number and coordinates of FOVs to
%calibrate based on grid offset arrays. Hardcoded: Index to voltage
%conversion.
%   Detailed explanation goes here
nonNanLogicalIndex = ~isnan(array);
[row,col] = find(nonNanLogicalIndex);
numNonNanElements = sum(nonNanLogicalIndex(:));
%Converts array coordinates to Voltages

AO0 = row*0.5-2.5;
AO1 = col*0.5-2.5;

if exp == 0
    if display==1
    disp('Coordinates of FOV to calibrate:');
    disp(table(row,col));

    disp('AO voltages of FOV to calibrate:');
    disp(table(AO0,AO1));

    disp('Number of FOVs to calibrate:');
    disp(numNonNanElements);
    end
else
     if display==1
    disp('Coordinates of calibrated FOVs:');
    disp(table(row,col));

    disp('AO voltages of calibrated FOVs:');
    disp(table(AO0,AO1));

    disp('Number of calibrated FOVs:');
    disp(numNonNanElements);
    end
end

