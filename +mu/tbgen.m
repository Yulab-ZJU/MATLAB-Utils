function [y, durs, ICIseq] = tbgen(ICIs, durs, f, fs, type, varargin)

mIp = inputParser;
mIp.addRequired("ICIs", @(x) validateattributes(x, {'numeric'}, {'vector', 'positive'}));
mIp.addRequired("durs", @(x) validateattributes(x, {'numeric'}, {'vector', 'positive', 'numel', numel(ICIs)}));
mIp.addRequired("f", @(x) validateattributes(x, {'numeric'}, {'vector', 'nonnegative'}));
mIp.addRequired("fs", @(x) validateattributes(x, {'numeric'}, {'scalar', 'positive', 'integer'}));
mIp.addRequired("type", @mustBeTextScalar);

mIp.addParameter("sigmas", 0.5, @(x) validateattributes(x, {'numeric'}, {'vector', 'positive'}));
mIp.addParameter("pulseLen", 3e-3, @(x) validateattributes(x, {'numeric'}, {'scalar', 'positive'}));
mIp.addParameter("range", [], @(x) validateattributes(x, {'numeric'}, {'numel', 2, 'increasing', 'positive'}));

mIp.addParameter("fsDevice", fs, @(x) validateattributes(x, {'numeric'}, {'scalar', 'positive'}));
mIp.addParameter("harmonics", 1, @(x) validateattributes(x, {'numeric'}, {'vector', 'positive'}));
mIp.addParameter("rfTime", 1e-3, @(x) validateattributes(x, {'numeric'}, {'nonnegative', 'scalar'}));

mIp.parse(ICIs, durs, f, fs, type, varargin{:});

type = validatestring(type, {'REG', 'IRREG'});
sigmas = mIp.Results.sigmas;
pulseLen = mIp.Results.pulseLen;
range = mIp.Results.range;
fsDevice = mIp.Results.fsDevice;
harmonics = mIp.Results.harmonics;
rfTime = mIp.Results.rfTime;

ICIs = ICIs(:);
durs = durs(:);
f = f(:);
nSeg = numel(ICIs);
assert(all([numel(durs) == nSeg, numel(f) == nSeg]), 'Invalid segment parameters input');

% Generate tone burst segments
tbSeg = arrayfun(@(x) mu.tonegen(x, pulseLen, fs, ...
                                 "fsDevice", fsDevice, ...
                                 "harmonics", harmonics, ...
                                 "rfOpt", "both", ...
                                 "rfTime", rfTime, ...
                                 "normOpt", true), ...
                 f, "UniformOutput", false);


if isscalar(sigmas)
    sigmas = repmat(sigmas, [numel(ICIs), 1]);
end

sigmas = ICIs(:) .* sigmas(:);
clickCounts = ceil(fix(durs .* fs) ./ fix(ICIs .* fs));

if strcmpi(type, "REG")
    % generate ICI sequence with fixed click numbers and ICIs
    ICIseq = arrayfun(@(x, y) repmat(x, [y, 1]), ICIs, clickCounts, "UniformOutput", false);

    % return actual duration for each ICI
    durs = cellfun(@sum, ICIseq);

    % generate tone burst for different parts
    y = cellfun(@(x, y) genToneBurstByICIseq(x, fs, y), ICIseq, tbSeg, "UniformOutput", false);
    ICIseq = cat(1, ICIseq{:});
    y = cat(1, y{:});

else % IRREG
    % generate ICI sequence with fixed click numbers but random ICIs
    ICIseq = cell(nSeg, 1);

    for index = 1:nSeg
        avg = ICIs(index);
        sigma = sigmas(index);

        % loop for each click
        ICIseq{index} = zeros(clickCounts(index), 1);

        for cIndex = 1:length(ICIseq{index})
            temp = normrnd(avg, sigma, 1);

            if cIndex == 1
                temp = avg;
            elseif cIndex == 2

                while ~(temp >= 0.3 * avg && temp <= 1.7 * avg) || ...
                      ~(temp + ICIseq{index}(cIndex - 1) >= 1.2 * avg && temp + ICIseq{index}(cIndex - 1) <= 3.1 * avg) || ...
                      (~isempty(range) && ~(temp >= range(1) && temp <= range(2)))
                    temp = normrnd(avg, sigma, 1);
                end

            else

                while ~(temp >= 0.3 * avg && temp <= 1.7 * avg) || ...
                      ~(temp + ICIseq{index}(cIndex - 1) >= 1.2 * avg && temp + ICIseq{index}(cIndex - 1) <= 3.1 * avg) || ...
                      ~(temp + sum(ICIseq{index}(cIndex - 2:cIndex - 1)) >= 1.8 * avg && temp + sum(ICIseq{index}(cIndex - 2:cIndex - 1)) <= 4.6 * avg) || ...
                      (~isempty(range) && ~(temp >= range(1) && temp <= range(2)))
                    temp = normrnd(avg, sigma, 1);
                end

            end

            ICIseq{index}(cIndex) = temp;
        end

    end

    % return actual duration for each ICI
    durs = cellfun(@sum, ICIseq);

    % generate tone burst for different parts
    y = cellfun(@(x, y) genToneBurstByICIseq(x, fs, y), ICIseq, tbSeg, "UniformOutput", false);
    ICIseq = cat(1, ICIseq{:});
    y = cat(1, y{:});
end

return;
end

%% 
function y = genToneBurstByICIseq(ICIseq, fs, tbSeg)
    nSeg = length(tbSeg);
    nEveryICI = fix(ICIseq .* fs);
    y = zeros(sum(nEveryICI), 1);
    temp = [0; cumsum(nEveryICI(1:end - 1))];
    
    for index = 1:length(temp)
        y(temp(index) + 1:temp(index) + nSeg) = tbSeg(:);
    end
    
    return;
end