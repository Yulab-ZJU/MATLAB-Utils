function gfp = mu_GFP(trialsData, chs2Ignore)
narginchk(1, 2);

if nargin < 2
    chs2Ignore = [];
end

switch class(trialsData)
    case "cell"
        channels = 1:size(trialsData{1}, 1);
        trialsData = cellfun(@(x) x(~ismember(channels, chs2Ignore), :), trialsData, "UniformOutput", false);
        gfp = cellfun(@(x) sqrt(sum((x - mean(x, 1)) .^ 2, 1) / size(x, 1)), trialsData, "UniformOutput", false);
    case "double"
        channels = 1:size(trialsData, 1);
        trialsData = trialsData(~ismember(channels, chs2Ignore), :);
        gfp = sqrt(sum((trialsData - mean(trialsData, 1)) .^ 2, 1) / size(trialsData, 1));
    otherwise
        error("Invalid data type");
end

return;
end