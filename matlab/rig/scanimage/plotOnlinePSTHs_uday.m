function plotOnlinePSTHs_uday(PSTHs,powers,savePath,saveName,baselinePeriod,samplePeriod)
baselineSubtract=1;
% baselinePeriod =1:5;
% samplePeriod =8:14;

sigThreshold = 1;

saveThis =1;

figure(1004);clf
set(gcf,'Units','normalized','Position',[0.68 0.04 0.3 0.88])

powerList = unique(powers);

count=0;
for i=1:numel(powerList)
    p=powerList(i);
    numPassAvg = sum(powers==p);
    x = PSTHs(powers==p,:,:);
    m = squeeze(nanmean(x,1));
    
    x = permute(x,[2 1 3]);
    dataPeriods = x(:,:,samplePeriod);
     sz =size(dataPeriods);
    dataPeriods = reshape(dataPeriods,[sz(1) sz(2)*sz(3)]);
    mData = nanmean(dataPeriods,2);
    
    basePeriods = x(:,:,baselinePeriod);
    sz =size(basePeriods);
    basePeriods = reshape(basePeriods,[sz(1) sz(2)*sz(3)]);
    mBase = nanmean(basePeriods,2);
    sBase = nanstd(basePeriods,[],2)/sqrt(numPassAvg);
    
    threshold = mBase+sigThreshold*sBase;
    
    sigCells = mData>threshold;
    
    if baselineSubtract
        b = nanmean(m(:,baselinePeriod),2);
        m = bsxfun(@minus,m,b);
    end
    
    st = baselinePeriod(end);
    count=count+1;
    subplot(numel(powerList),2,count)
    set(gca, 'ColorOrder', lines(size(m,1)), 'NextPlot', 'replacechildren');
    plot(m');hold on
    ylabel({['Power : ' num2str(p)]; ['Avg of ' num2str(numPassAvg)]})
    title(['Power: ',num2str(round(p*1000/4,1)),' mW'])
    
    count=count+1;
    subplot(numel(powerList),2,count)
    colormap redblue
    imagesc(m);hold on
    title([num2str(sum(sigCells)) ' of ' num2str(numel(sigCells)) ' putatively activated'])
    
end

%%%%%%%%%%Rescale axes to match
naxes = length(get(gcf,'Children'));
ymin = 999999; ymax = -ymin;
cmin = 999999; cmax = -cmin;
for k=1:naxes
    if(mod(k,2))
        subplot(naxes/2,2,k)
        ylim = get(gca,'ylim');
        ymin = min([ymin,ylim]);
        ymax = max([ymax,ylim]);
    else
        subplot(naxes/2,2,k)
        clim = get(gca,'clim');
        cmin = min([cmin,clim]);
        cmax = max([cmax,clim]);
    end
end
ylim = [ymin ymax];
% clim = [cmin cmax];
clim = [-max(abs([cmin cmax])),+max(abs([cmin cmax]))];
for k=1:naxes
    if(mod(k,2))
        subplot(naxes/2,2,k)
        set(gca,'ylim',ylim)
        plot([st;st],get(gca,'ylim')','k')
    else
        subplot(naxes/2,2,k)
        set(gca,'clim',clim)
        plot([st;st],get(gca,'ylim')','k')
    end
end
%%%%%%%%%%%

out.PSTHs = PSTHs;
out.powers = powers;

if saveThis
save(fullfile(savePath,saveName),'out')
end