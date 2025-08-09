function [p, stat] = mu_cbpt_GFP(data1, data2, varargin)
% Perform permutation test on GFP data.
%
% [data1] and [data2] are of one of these data type:
%     N-by-S matrix (N is subject number, S is sample number)
%     T-by-S matrix (T is trial number)
%     T-by-1 cell with elements of C-by-S double (C is channel number).
%
% [Type] specifies which kind of data (ERP or GFP) to compare. (default: 'ERP')
% To compare ERP: use `CBPT` for permutation test
%     If [data1] (T1*S) and [data2] (T2*S) are numeric matrices, treat data
%     as single-channel data (convert to T*1 cell with 1*S matrix) and
%     apply `CBPT`.
%     If [data1] (T1*1) and [data2] (T2*1) are cell arrays with C*S data, 
%     apply `CBPT`.
% To compare GFP:
%     If [data1] (N1*S) and [data2] (N2*S) are numeric matrices, shuffle 
%     rows between conditions and then average across N subjects.
%     If [data1] (T1*1) and [data2] (T2*1) are cell arrays with C*S data, 
%     shuffle at trial level → compute ERP → compute GFP.
%
% [p] returned as two-tailed (default) or one-tailed p value of the
% permutation test.
% For 'left' tail, the alternative hypothesis is data1<data2, that is if 
% p<0.01, reject the null hypothesis (the desired result is data1<data2).
% If you want data1<data2, use 'left'.
% If you want data1>data2, use 'right'.
% If you want data1~=data2, use 'both'.
%
% For [stat] returned as the permuted wave difference matrix (nperm-by-S double).

mIp = inputParser;
mIp.addRequired("data1", @(x) validateattributes(x, {'numeric', 'cell'}, {'2d'}));
mIp.addRequired("data2", @(x) validateattributes(x, {'numeric', 'cell'}, {'2d'}));
mIp.addOptional("nperm", 1e3, @(x) validateattributes(x, {'numeric'}, {'scalar', 'integer', 'positive'}));
mIp.addParameter("Tail", "both", @(x) any(validatestring(x, {'both', 'left', 'right'})));
mIp.addParameter("Type", "ERP", @(x) any(validatestring(x, {'ERP', 'GFP'})));
mIp.addParameter("chs2Ignore", [], @(x) validateattributes(x, {'numeric'}, {'positive', 'integer', 'vector'}));
mIp.addParameter("EEGPos", [], @(x) isscalar(x) & isstruct(x));
mIp.parse(data1, data2, varargin{:});

nperm = mIp.Results.nperm;
Tail = mIp.Results.Tail;
Type = mIp.Results.Type;
chs2Ignore = mIp.Results.chs2Ignore;
EEGPos = mIp.Results.EEGPos;

if ~isempty(EEGPos) & isempty(chs2Ignore)
    chs2Ignore = EEGPos.ignore;
end

if isa(data1, "double") && isa(data2, "double")

    if ~isequal(size(data1, 2), size(data2, 2))
        error("data1 and data2 should be of the same sample number");
    end

    nSample = size(data1, 2);
    A = size(data1, 1);
    B = size(data2, 1);

    if strcmpi(Type, "ERP")
        % use CBPT
        data1 = mat2cell(data1, ones(A, 1));
        data2 = mat2cell(data2, ones(B, 1));
        Type = "ERP";
    elseif strcmpi(Type, "GFP")
        temp = [data1; data2];
        [resPerm1, resPerm2] = deal(zeros(nperm, nSample));

        dispstat('', 'init');
        for index = 1:nperm
            shuffleIdx = 1:(A + B);
            shuffleIdx = randperm(length(shuffleIdx));
            resPerm1(index, :) = mean(temp(shuffleIdx(1:A), :), 1);
            resPerm2(index, :) = mean(temp(shuffleIdx(A + 1:A + B), :), 1);
            dispstat(['Permutation: ', num2str(index), '/', num2str(nperm)]);
        end
        
        wave1 = mean(data1, 1);
        wave2 = mean(data2, 1);
    end

end

if iscell(data1) && iscell(data2)

    if ~isequal(size(data1{1}), size(data2{1}))
        error("data1 and data2 should be of the same size");
    end

    if strcmpi(Type, "ERP")
        channels = 1:size(data1{1}, 1);

        cfg = [];
        cfg.numrandomization = nperm;
        if strcmpi(Tail, "left")
            cfg.tail = -1;
        elseif strcmpi(Tail, "right")
            cfg.tail = 1;
        else
            cfg.tail = 0;
        end
        cfg.clustertail = cfg.tail;

        if ~isempty(EEGPos)
            labels = EEGPos.channelNames;
            cfg.neighbours = EEGPos.neighbours;
            cfg.minnbchan = 1; % set 1 to enable ChannelxSample clustering
        else
            labels = arrayfun(@num2str, channels(:), "UniformOutput", false);
        end

        % replace bad channels with zeros
        idx1 = cellfun(@(x) any(isnan(x), 2), data1, "UniformOutput", false);
        idx1 = any(cat(2, idx1{:}), 2);
        idx2 = cellfun(@(x) any(isnan(x), 2), data2, "UniformOutput", false);
        idx2 = any(cat(2, idx2{:}), 2);
        idx = idx1 | idx2; % channels with nan values
        data1 = cellfun(@(x) x(~idx, :), data1, "UniformOutput", false);
        data1 = cellfun(@(x) mu.insertrows(x, find(idx)), data1, "UniformOutput", false);
        data2 = cellfun(@(x) x(~idx, :), data2, "UniformOutput", false);
        data2 = cellfun(@(x) mu.insertrows(x, find(idx)), data2, "UniformOutput", false);

        stat = mu_cbpt(cfg, data1, data2);
        p = stat.prob;
        stat.labels = labels;
        return;

    elseif strcmpi(Type, "GFP")
        temp = [data1; data2];
        A = length(data1);
        B = length(data2);
        nSample = size(data1{1}, 2);
        [resPerm1, resPerm2] = deal(zeros(nperm, nSample));

        dispstat('', 'init');
        for index = 1:nperm
            shuffleIdx = 1:(A + B);
            shuffleIdx = randperm(length(shuffleIdx));
            resPerm1(index, :) = mu_GFP(mu.calchMean(temp(shuffleIdx(1:A))), chs2Ignore);
            resPerm2(index, :) = mu_GFP(mu.calchMean(temp(shuffleIdx(A + 1:A + B))), chs2Ignore);
            dispstat(['Permutation: ', num2str(index), '/', num2str(nperm)]);
        end

        wave1 = mu_GFP(mu.calchMean(data1), chs2Ignore);
        wave2 = mu_GFP(mu.calchMean(data2), chs2Ignore);
    end

end

dWave = wave1 - wave2;
stat = resPerm1 - resPerm2;

pLeft = sum(stat < dWave, 1) / nperm; % ratio that supports null hypothesis: x < y
pRight = sum(stat > dWave, 1) / nperm; % ratio that supports null hypothesis: x > y
pBoth = min(pLeft, pRight) * 2;

switch Tail
    case "both"
        p = pBoth;
    case "left"
        p = pLeft;
    case "right"
        p = pRight;
end

% cluster correction
[clus, ~] = spm_bwlabel(double(p < 0.05), 6);
p = p(clus ~= 0);

return;
end