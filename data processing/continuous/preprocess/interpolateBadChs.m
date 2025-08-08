function trialsData = interpolateBadChs(trialsData, badCHs, neighbours)
% Description: Interpolate data of bad channels by averaging neighbour channels
% Input parameter [neighbours]: see mPrepareNeighbours and ft_prepare_neighbours

narginchk(2, 3);

if nargin < 3 || isempty(neighbours)
    % default: for ECoG recording of an 8*8 electrode array
    neighbours = mPrepareNeighbours;
end

neighbch = {neighbours.neighbch}';

% Ranking
score = cellfun(@(x) sum(~ismember(x, badCHs)) / numel(x), neighbch(badCHs));
score(isnan(score)) = -1;
[~, sortIdx] = sort(score, "descend");
badCHs = badCHs(sortIdx);

% Replace bad chs by averaging neighbour chs
interpolateFlag = false(numel(badCHs), 1);
for bIndex = 1:numel(badCHs)
    chsTemp = neighbch{badCHs(bIndex)};
    badCHsRemained = badCHs(~interpolateFlag);

    if isempty(chsTemp)
        warning(['No neighbours specified for channel ', num2str(badCHs(bIndex)), '. Skip']);
        continue;
    end

    if all(ismember(chsTemp, badCHsRemained))
        warning(['All neighbour channels are bad for channel ', num2str(badCHs(bIndex))]);
    end

    for tIndex = 1:length(trialsData)
        trialsData{tIndex}(badCHs(bIndex), :) = mean(trialsData{tIndex}(chsTemp(~ismember(chsTemp, badCHsRemained)), :), 1);
    end

    interpolateFlag(bIndex) = true;
end

return;
end