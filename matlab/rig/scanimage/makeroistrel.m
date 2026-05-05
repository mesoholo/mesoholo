function SE = makeroistrel(filtsz)

szf = round((filtsz+1)/2)*2-1; % round to nearest odd integer
[xx yy] = meshgrid(1:szf(2),1:szf(1));
s3 = ((xx-ceil(szf(2)/2))/(szf(2)/2)).^2 + ((yy-ceil(szf(1)/2))/(szf(1)/2)).^2;
SE = s3<1;