%MESOHOLO-DOC
% Repository: mesoholo (Abdeladim et al., 2026). File: python/suite2p_pipeline/check_onlineVSoffline.m
% Purpose: Compare suite2p outputs from online vs offline runs (paths under ``data/sessions``).
%
repo = mesoholo_repo_from_script();
onlinepath = fullfile(repo, 'data', 'sessions', 'HS_CamKIIGC6s_59', '210617', 'Online');
offlinepath = fullfile(repo, 'data', 'sessions', 'HS_CamKIIGC6s_59', '210617', 'suite2p', 'combined');
onlinefolder = 'RFcircleCI1';
pathpp = fullfile(repo, 'data', 'postprocessed', 'HS_CamKIIGC6s_59', '210617');

%% load suite2p outputs
% Nplanes refers to number of MROI strips
onlinedir=dir(onlinepath);
Nplanes = nnz(contains({onlinedir.name}, 'plane'));
online = struct();
for ii = 1:Nplanes
    % temps2p = load(strcat(suite2ppath, 'plane_', num2str(ii-1), '/suite2p/plane0/Fall.mat'));
    temps2p = load(sprintf('%splane_%d/suite2p/plane0/Fall.mat', onlinepath, ii-1));
    if ii==1
        online = temps2p;
    else
        online = [online temps2p];
    end
end
offline = load([offlinepath 'Fall.mat']);

%% compare mean images
figure
imshow(offline.ops.meanImg/prctile(offline.ops.meanImg(:),99))
title('offline suite2p meanImg')

onlineops = [online.ops];
onmeanImg = cat(2,onlineops.meanImg);
figure
imshow(onmeanImg/prctile(onmeanImg(:),99))
hold on; plot(onmed(:,2), onmed(:,1), 'r+')
title('online suite2p meanImg stitched together')

%% compare ROI coordinates
offstat = cell2mat(offline.stat);
offmed = double( cat(1, offstat.med) );

Lxs = zeros(1,Nplanes);
onmed = zeros(0,2);
for ii = 1:Nplanes
    Lxs(ii) = size(online(ii).ops.meanImg,2);
temponstat = cell2mat(online(ii).stat);
temponmed = double( cat(1, temponstat.med) );
temponmed(:,2) = temponmed(:,2) + sum(Lxs(1:ii-1));
onmed = cat(1, onmed, temponmed);
end

figure; hold all
annotation('textbox', [0.1 0.9 0.9 0.1], 'string', 'online (r+) vs offline (ko) all ROIs', 'edgecolor', 'none')
plot(onmed(:,2), onmed(:,1), 'r+')
plot(offmed(:,2), offmed(:,1), 'ko')
xlim([0 size(offline.ops.meanImg,2)])
ylim([0 size(offline.ops.meanImg,1)])

onoffroipixdist = sqrt((onmed(:,1)-offmed(:,1)').^2 + (onmed(:,2)-offmed(:,2)').^2);

%% find corresponding time points
load(strcat(pathpp, 'presuite2p_params.mat'))
disp(foldername)
% whichfolder = input('index of online-processed folder\n');
whichfolder = find(strcmp(onlinefolder, foldername));
startfileind = find(whichvisfile==whichfolder, 1, 'first');
endfileind = find(whichvisfile==whichfolder, 1, 'last');

numtimepointsperfile = numframesperfile/numchannels;
starttimeind = [1; cumsum(numtimepointsperfile(1:end-1))+1];
endtimeind = cumsum(numtimepointsperfile);

off2ontimeinds = starttimeind(startfileind):endtimeind(endfileind);

onlineF = cat(1,online.F);
onoffcorrF = corr(onlineF', offline.F(:,off2ontimeinds)');

[maxon2offcorrF, imaxon2offcorrF] = max(onoffcorrF, [], 2);
[minon2offdist, iminon2offdist] = min(onoffroipixdist, [], 2);
fprintf('%.2f%% match in max F correlation and minimum distance online to offline\n', 100*mean(imaxon2offcorrF==iminon2offdist))

[maxoff2oncorrF, imaxoff2oncorrF] = max(onoffcorrF, [], 1);
[minoff2ondist, iminoff2ondist] = min(onoffroipixdist, [], 1);
fprintf('%.2f%% match in max F correlation and minimum distance offline to online\n', 100*mean(imaxoff2oncorrF==iminoff2ondist))

d = onoffroipixdist(sub2ind(size(onoffroipixdist), (1:length(imaxon2offcorrF))', imaxon2offcorrF));
figure; plot(d, maxon2offcorrF, '.')
xlabel('Distance (Pixels)')
ylabel('Max On-Off F Correlation')
title('For Each Online ROI')
xlim([0 50])