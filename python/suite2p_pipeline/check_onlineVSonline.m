%MESOHOLO-DOC
% Repository: mesoholo (Abdeladim et al., 2026). File: python/suite2p_pipeline/check_onlineVSonline.m
% Purpose: Compare two online suite2p output directories for the same session.
%
repo = mesoholo_repo_from_script();
onlinepath = fullfile(repo, 'data', 'sessions', 'HS_CamKIIGC6s_59', '210617', 'Online');
online2path = fullfile(repo, 'data', 'sessions', 'HS_CamKIIGC6s_59', '210617', 'Online_old');

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

online2 = struct();
for ii = 1:Nplanes
    % temps2p = load(strcat(suite2ppath, 'plane_', num2str(ii-1), '/suite2p/plane0/Fall.mat'));
    temps2p = load(sprintf('%splane_%d/suite2p/plane0/Fall.mat', online2path, ii-1));
    if ii==1
        online2 = temps2p;
    else
        online2 = [online2 temps2p];
    end
end

%% compare mean images
onlineops = [online.ops];
onmeanImg = cat(2,onlineops.meanImg);
figure
imshow(onmeanImg/prctile(onmeanImg(:),99))
% hold on; plot(onmed(:,2), onmed(:,1), 'r+')
title('online suite2p meanImg stitched together')

online2ops = [online2.ops];
onmeanImg2 = cat(2,online2ops.meanImg);
figure
imshow(onmeanImg2/prctile(onmeanImg2(:),99))
title('online2 suite2p meanImg stitched together')

%% compare ROI coordinates
Lxs = zeros(1,Nplanes);
onmed = zeros(0,2);
for ii = 1:Nplanes
    Lxs(ii) = size(online(ii).ops.meanImg,2);
temponstat = cell2mat(online(ii).stat);
temponmed = double( cat(1, temponstat.med) );
temponmed(:,2) = temponmed(:,2) + sum(Lxs(1:ii-1));
onmed = cat(1, onmed, temponmed);
end

onmed2 = zeros(0,2);
for ii = 1:Nplanes
temponstat = cell2mat(online2(ii).stat);
temponmed = double( cat(1, temponstat.med) );
temponmed(:,2) = temponmed(:,2) + sum(Lxs(1:ii-1));
onmed2 = cat(1, onmed2, temponmed);
end

figure; hold all
annotation('textbox', [0.1 0.9 0.9 0.1], 'string', 'online (r+) vs onmed2 (ko) all ROIs', 'edgecolor', 'none')
plot(onmed(:,2), onmed(:,1), 'r+')
plot(onmed2(:,2), onmed2(:,1), 'ko')
xlim([0 size(onmeanImg,2)])
ylim([0 size(onmeanImg,1)])

onon2roipixdist = sqrt((onmed(:,1)-onmed2(:,1)').^2 + (onmed(:,2)-onmed2(:,2)').^2);

%% find corresponding time points
onlineF = cat(1,online.F);
online2F = cat(1,online2.F);
onon2corrF = corr(onlineF', online2F');

[maxontoon2corrF, imaxontoon2corrF] = max(onon2corrF, [], 2);
[minontoon2dist, iminontoon2dist] = min(onon2roipixdist, [], 2);
fprintf('%.2f%% match in max F correlation and minimum distance online to online2\n', 100*mean(imaxontoon2corrF==iminontoon2dist))

[maxon2tooncorrF, imaxon2tooncorrF] = max(onon2corrF, [], 1);
[minon2toondist, iminon2toondist] = min(onon2roipixdist, [], 1);
fprintf('%.2f%% match in max F correlation and minimum distance online2 to online\n', 100*mean(imaxon2tooncorrF==iminon2toondist))

d = onon2roipixdist(sub2ind(size(onon2roipixdist), (1:length(imaxontoon2corrF))', imaxontoon2corrF));
figure; plot(d, maxontoon2corrF, '.')
xlabel('Distance (Pixels)')
ylabel('Max On-On2 F Correlation')
title('For Each Online ROI')
xlim([0 50])