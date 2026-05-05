function [SourceCell,Data]=extractROIs3_uday(img,skimg,Opts)
sources=[];

if ~isfield(Opts,'radius')
radius = 5;
else
radius = Opts.radius;
end

if ~isfield(Opts,'SizeThreshold')
SizeThreshold = 250;
else
SizeThreshold = Opts.SizeThreshold;
end

if ~isfield(Opts,'maxSourcesPerPlane')
MaxSources = 250;
else
MaxSources = Opts.maxSourcesPerPlane;
end

if ~isfield(Opts,'height')
height=1:512;
else
height = Opts.height;
end

if ~isfield(Opts,'width')
width=101:412;
else
width=Opts.width;
end

nd=size(img,3);

thresh=[];

% preprocess
filt=(fspecial('gaussian',round(10*[Opts.yppu,Opts.xppu]),2));

tic
disp(['Filtering Image ']);
for j = 1:nd  % for each depth
    z=zeros(size(img,1),size(img,2));
    temp=squeeze(img(:,:,j));
    temp = temp(height,width);
    temp = temp - medfilt2(temp,[20,20]);
    temp2=conv2(temp,filt,'same');
%     temp2 = imgaussfilt(temp,1);
%     [tempgx,tempgy] = gradient(temp2);
%     temp2 = abs(del2(temp2)).*(abs(tempgx)+abs(tempgy));
%     temp2 = imgaussfilt(temp2,1);
    
    z(height,width)=temp2;
    Data(j).raw = z;
    Data(j).raw2 = -z;
    
%     temp=squeeze(skimg(:,:,j));
%     temp2=conv2(temp,filt,'same');
%     skz=zeros(size(img,1),size(img,2));
%     skz(height,width)=temp2(height,width);
%     Data(j).skraw=skz;
end
toc

imageSizeX = size(img,2);
imageSizeY = size(img,1);
[columnsInImage rowsInImage] = meshgrid(1:imageSizeX, 1:imageSizeY);
for k = 1:nd
    clear OC OC2;
    tic
    disp(['Segmenting Depth ' num2str(k)]);
    
    if(max(max(Data(k).raw))>1)
    [output] = FastPeakFind(Data(k).raw);
    OC(:,1)=output(1:2:end);
    OC(:,2)=output(2:2:end);
    num1 = size(OC,1);
    else
        OC = [];
    end
    
%     [output] = FastPeakFind(Data(k).raw2);
%     OC2(:,1)=output(1:2:end);
%     OC2(:,2)=output(2:2:end);
%     OC = [OC;OC2];
    
    if(~isempty(OC))

    pixbnd = 20*mean([Opts.xppu,Opts.yppu]);
    pixwin = floor(-pixbnd):ceil(pixbnd);
    for j = 1:size(OC,1)
        if(j<=num1)
            currim = Data(k).raw;
        else
            currim = Data(k).raw2;
        end
        
        circlePixels = (((rowsInImage  - OC(j,2)).^2)/((radius(1)+0)*Opts.xppu)^2 + ...
            ((columnsInImage - OC(j,1)).^2)/((radius(1)+0)*Opts.xppu)^2 <= 1);
%         circlePixels(circlePixels==0) = NaN;
%         Flo=circlePixels.*Data(k).raw;
        Flo = circlePixels(OC(j,2)+pixwin,OC(j,1)+pixwin).*...
            currim(OC(j,2)+pixwin,OC(j,1)+pixwin);
        Flo = Flo(:);
%         Flo(isnan(Flo)) = [];
        Flo(Flo==0) = [];
        
        nbdPixels = (((rowsInImage  - OC(j,2)).^2)/((radius(2)+0)*Opts.xppu)^2 + ...
            ((columnsInImage - OC(j,1)).^2)/((radius(2)+0)*Opts.xppu)^2 <= 1);
%         circlePixels(isnan(circlePixels)) = 0;
        nbdPixels = nbdPixels-circlePixels;
        assignin('base','nbdPixels',nbdPixels);
%         nbdPixels(nbdPixels==0) = NaN;
        nbdFlo = nbdPixels(OC(j,2)+pixwin,OC(j,1)+pixwin).*...
            currim(OC(j,2)+pixwin,OC(j,1)+pixwin);
        nbdFlo = nbdFlo(:);
%         nbdFlo(isnan(nbdFlo)) = [];
        nbdFlo(nbdFlo==0) = [];
        
        OC(j,3) = mean(Flo);
        OC(j,4) = std(Flo);
%         OC(j,4) = max(Flo);
        OC(j,5) = mean(nbdFlo);
        OC(j,6) = std(nbdFlo);
        
%         Sk = circlePixels.*Data(k).skraw;
%         Sk = Sk(:);
%         Sk(Sk==0)=[];
%         OC(j,5) = mean(Sk);
    end
%     OC(OC(:,3)-OC(:,5)<0.8*OC(:,3),:) = [];
    OC(OC(:,5)>0.8*OC(:,3),:) = []; % 0.67 - 0.8
    OC(OC(:,4)>8*OC(:,3),:) = []; % 6 - 8
    OC(:,3) = OC(:,3)-OC(:,5);

    edgecutoff = 5;
    OC(OC(:,1)<min(OC(:,1))+edgecutoff | OC(:,1)>max(OC(:,1))-edgecutoff,:) = [];
    OC(OC(:,2)<min(OC(:,2))+edgecutoff | OC(:,2)>max(OC(:,2))-edgecutoff,:) = [];
    
    Data(k).thresh=quantile(OC(:,3),Opts.redQuantileRange);

    %     [min(OC(:,3)),max(OC(:,3))]
    OC(OC(:,3)<Data(k).thresh(1)|OC(:,3)>Data(k).thresh(2),:)=[];
%     OC(OC(:,5)<quantile(OC(:,5),0.05),:) = [];
%     if(k==2)
%         OC(OC(:,2)<=500 & OC(:,1)<=300,:,:) = [];
%     else
%         OC() = [];
%         OC() = [];
%     end

    OC=sortrows(OC,3);
    OC=flipud(OC);    %brightest first
    
%     OC(abs(OC(:,1)-min(OC(:,1)))<5,:) = [];
%     OC(abs(OC(:,1)-max(OC(:,1)))<5,:) = [];
    
    %%%% Set distance threshold
    OC(:,1) = round(OC(:,1)/Opts.xppu);
    OC(:,2) = round(OC(:,2)/Opts.yppu);
    mindist = 0;
    count = 0;
    try
    while(mindist < Opts.distThreshold)
        count = count+1;
        distmat = pdist2(OC(:,1:2),OC(:,1:2));
        distmat = distmat + 999*eye(length(OC(:,1)));
        mindist = min(distmat(:));
        distvec = distmat(count,:);
        if(any(distvec < Opts.distThreshold))
            badinds = find(distvec < Opts.distThreshold);
            OC(badinds,:) = [];
            count = 0;
        end
    end
    OC(:,1) = round(OC(:,1)*Opts.xppu);
    OC(:,2) = round(OC(:,2)*Opts.yppu);
%     OC=flipud(OC);    %brightest first
    catch
    end
    
    if size(OC,1)>MaxSources;
        try
            OC=OC(1:MaxSources,:);
        catch
            OC=OC;
        end
    else
        OC=OC;
    end
    OC = sortrows(OC,1); % SORT BY X location?
    Data(k).OC = OC;

   sources = zeros(size(img,1),size(img,2),size(Data(k).OC,1));
   SE=strel('disk',round(radius(1)),4);
      
   for n = 1:size(sources,3)
        sources(:,:,n) = (((rowsInImage  - OC(n,2)).^2)/((radius(1)+0)*Opts.yppu)^2 + ...
            ((columnsInImage - OC(n,1)).^2)/((radius(1)+0)*Opts.xppu)^2 <= 1);
%          sources(Data(k).OC(n,2),Data(k).OC(n,1),n)=1;
%          sources(:,:,n)=imdilate(sources(:,:,n),SE);
   end
   
    SourceCell{k}=sources;
    disp([num2str(size(sources,3)),' rois found']);
    toc
    else
        SourceCell{k} = [];
        disp([num2str(0),' rois found']);
    end
end

planestoremove = [];
for i=planestoremove
    SourceCell{i} = [];
end
