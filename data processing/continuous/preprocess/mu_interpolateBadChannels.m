function trialsData = mu_interpolateBadChannels(trialsData, badChs, neighbours)
% Description: Interpolate data of bad channels by averaging neighbour channels
% Input parameter [neighbours]: see mu_prepareNeighboursArray and ft_prepare_neighbours

neighbch = {neighbours.neighbch}';

% Ranking
score = cellfun(@(x) sum(~ismember(x, badChs)) / numel(x), neighbch(badChs));
score(isnan(score)) = -1;
[~, sortIdx] = sort(score, "descend");
badChs = badChs(sortIdx);

% Replace bad chs by averaging neighbour chs
interpolateFlag = false(numel(badChs), 1);
for bIndex = 1:numel(badChs)
    chsTemp = neighbch{badChs(bIndex)};
    badChsRemained = badChs(~interpolateFlag);

    if isempty(chsTemp)
        warning(['No neighbours specified for channel ', num2str(badChs(bIndex)), '. Skip']);
        continue;
    end

    if all(ismember(chsTemp, badChsRemained))
        warning(['All neighbour channels are bad for channel ', num2str(badChs(bIndex))]);
    end

    for tIndex = 1:length(trialsData)
        trialsData{tIndex}(badChs(bIndex), :) = mean(trialsData{tIndex}(chsTemp(~ismember(chsTemp, badChsRemained)), :), 1);
    end

    interpolateFlag(bIndex) = true;
end

return;
end