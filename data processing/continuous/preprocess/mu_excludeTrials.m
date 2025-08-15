function [tIdx, chIdx] = mu_excludeTrials(trialsData, varargin)
% Description: exclude trials with sum(Data > mean + 3 * variance | Data < mean - 3 * variance) / length(Data) > tTh
% Input:
%     trialsData: nTrials*1 cell vector with each cell containing an nCh*nSample matrix of data
%     tTh: threshold of percentage of bad data. For one trial, if nSamples(bad) > tTh*nSamples(total)
%          in any reserved channel, it will be excluded. (default: 0.2)
%     chTh: threshold for excluding bad channels.
%           If set [0, 1], it stands for percentage of trials.
%           If set integer > 1, it stands for nTrials.
%           The smaller, the stricter and the more bad channels. (default: 0.1)
%     userDefineOpt: If set "on", bad channels will be defined by user.
%                    If set "off", use [chTh] setting to exclude bad channels. (default: "off")
%     absTh: absolute threshold (default: [])
%     badCHs: bad channel number array (default: [])
%             If specified, [chTh] and [userDefineOpt] will not work.
% Output:
%     tIdx: excluded trial index (column vector)
%     chIdx: bad channel index (column vector)

mIp = inputParser;
mIp.addRequired("trialsData", @(x) iscell(x));
mIp.addOptional("tTh", 0.2, @(x) validateattributes(x, {'numeric'}, {'scalar', '>', 0, '<', 1}));
mIp.addOptional("chTh", 0.1, @(x) validateattributes(x, {'numeric'}, {'scalar', '>=', 0}));
mIp.addParameter("userDefineOpt", "off", @(x) any(validatestring(x, {'on', 'off'})));
mIp.addParameter("absTh", [], @(x) validateattributes(x, {'numeric'}, {'scalar'}));
mIp.addParameter("badCHs", [], @(x) validateattributes(x, {'numeric'}, {'positive', 'integer', 'vector', '<=', size(trialsData{1}, 1)}));
mIp.parse(trialsData, varargin{:});

tTh = mIp.Results.tTh;
chTh = mIp.Results.chTh;
userDefineOpt = mIp.Results.userDefineOpt;
absTh = mIp.Results.absTh;
badCHs = mIp.Results.badCHs;

% statistics
chMeanAll = mean(cat(1, trialsData{:}), 1);
chStdAll = std(cat(1, trialsData{:}), [], 1);
tIdxAll = cellfun(@(x) sum(x > chMeanAll + 3 * chStdAll | x < chMeanAll - 3 * chStdAll, 2) / size(x, 2), trialsData, "UniformOutput", false);

chMean = mu.calchMean(trialsData);
chStd = mu.calchStd(trialsData);
tIdx = cellfun(@(x) sum(x > chMean + 3 * chStd | x < chMean - 3 * chStd, 2) / size(x, 2), trialsData, "UniformOutput", false);

% sort channels
temp = mu.reslice(trialsData, 1);
V0_All = cellfun(@(x) sum(x > chMeanAll + 3 * chStdAll | x < chMeanAll - 3 * chStdAll, 2) / size(x, 2), temp, "UniformOutput", false);
V_All = cellfun(@(x) x > tTh, V0_All, "UniformOutput", false);
V0 = cellfun(@(x) sum(x > mean(x, 1) + 3 * std(x, [], 1) | x < mean(x, 1) - 3 * std(x, [], 1), 2) / size(x, 2), temp, "UniformOutput", false);
V = cellfun(@(x) x > tTh, V0, "UniformOutput", false);

badtrialIdx = cellfun(@(x, y) any(x) | any(y), mu.reslice(V_All, 1), mu.reslice(V, 1));

V_All = cellfun(@(x) sum(x), V_All);
V = cellfun(@(x) sum(x), V);

% show channel-bad trials
if chTh > 1 && chTh == fix(chTh)
    goodChIdx = V_All < chTh & V < chTh; % marked true means reserved channels
elseif chTh <= 1
    goodChIdx = V_All < chTh * length(trialsData) & V < chTh * length(trialsData); % marked true means reserved channels
else
    error('Invalid channel threshold input.');
end

channels = (1:length(goodChIdx))'; % all channels
nTrial_bad_All = arrayfun(@(x) [num2str(x), '/', num2str(length(trialsData))], V_All, "UniformOutput", false);
nTrial_bad_Single = arrayfun(@(x) [num2str(x), '/', num2str(length(trialsData))], V, "UniformOutput", false);
mark = repmat("good", [length(channels), 1]);
mark(~goodChIdx) = "bad";
disp(table(channels, nTrial_bad_All, nTrial_bad_Single, mark));
if all(goodChIdx)
    disp('All channels are good.');
else
    disp(['Possible bad channel numbers: ', num2str(find(~goodChIdx)')]);
end

if ~isempty(badCHs) % fixed bad channels
    goodChIdx = true(length(goodChIdx), 1);
    goodChIdx(badCHs) = false;
else
    % bad channels defined by user
    if strcmp(userDefineOpt, "on")
        badCHs = validateinput('Please input bad channel number (0 for preview): ', @(x) validateattributes(x, {'numeric'}, {'2d', 'integer', 'nonnegative'}));

        if isequal(badCHs, 0)
            % raw wave
            mu_plotWaveArray(struct("chMean", chMean, "chErr", chStd), [0, 1]);
            mu.scaleAxes("y", "symOpts", "max", "uiOpt", "show");

            % good trials (mean, red) against bad trials (single, grey)
            previewRawWave(trialsData, badtrialIdx, V_All);

            % histogram
            temp = mu.reslice(tIdx, 1);
            figure("WindowState", "maximized");
            margins = [0.05, 0.05, 0.1, 0.1];
            paddings = [0.01, 0.03, 0.01, 0.01];
            pltsz = mu.autoplotsize(numel(channels));
            for index = 1:numel(channels)
                ax = mu.subplot(pltsz(1), pltsz(2), index, "margins", margins, "paddings", paddings);
                hold(ax, "on");
                histogram(ax, temp{index}, "Normalization", "probability", "BinWidth", 0.05, "FaceColor", "b", "DisplayName", "Single");
                histogram(ax, V0_All{index}, "Normalization", "probability", "BinWidth", 0.05, "FaceColor", "r", "DisplayName", "All");
                if ismember(index, find(~goodChIdx))
                    title(ax, ['CH ', num2str(index), ' (bad)']);
                else
                    title(ax, ['CH ', num2str(index)]);
                end
                if index <= (pltsz(1) - 1) * pltsz(2)
                    xticklabels(ax, '');
                end
                if mod(index - 1, pltsz(2)) ~= 0
                    yticklabels(ax, '');
                end
                if index == 1
                    legend(ax, "show");
                else
                    legend(ax, "hide");
                end
            end
            mu.scaleAxes("x", [0.1, inf]);
            mu.scaleAxes("y", "on");
            mu.addLines(struct("X", tTh));

            k = 'N';
        else
            k = 'Y';
            goodChIdx = true(length(goodChIdx), 1);
            goodChIdx(badCHs) = false;
        end

        while strcmpi(k, 'n')
            badCHs = validateinput('Please input bad channel number: ', @(x) validateattributes(x, {'numeric'}, {'2d', 'integer', 'positive'}));
            
            % sort trials - preview
            goodChIdx = true(length(goodChIdx), 1);
            goodChIdx(badCHs) = false;
            tIdxTemp = cellfun(@(x) sum(x(goodChIdx, :) > chMean(goodChIdx, :) + 3 * chStd(goodChIdx, :) | x(goodChIdx, :) < chMean(goodChIdx, :) - 3 * chStd(goodChIdx, :), 2) / size(x, 2), trialsData, "UniformOutput", false);
            tIdxTemp = cellfun(@(x) ~any(x > tTh), tIdxTemp); % marked true means reserved trials
            if any(~tIdxTemp)
                disp(['Preview: A number of ', num2str(sum(~tIdxTemp)), ' trials will be excluded.']);
            else
                disp('Preview: All will pass.');
            end

            k = validateinput('Press Y or Enter to continue or N to reselect bad channels: ', @(x) isempty(x) || any(validatestring(x, {'y', 'n', 'N', 'Y', ''})), 's');
        end

    end

end

tIdx = cellfun(@(x) ~any(x(goodChIdx) > tTh), tIdx); % marked true means reserved trials

% Absolute threshold
if ~isempty(absTh)
    tIdx = tIdx & cellfun(@(x) all(abs(x(goodChIdx, :)) < absTh, "all"), trialsData);
end

if any(~tIdx)
    tIdx = find(~tIdx);
    disp(['Trials excluded (N=', num2str(length(tIdx)), '): ', num2str(tIdx')]);
else
    tIdx = [];
    disp('All pass.');
end

chIdx = find(~goodChIdx);
if ~isempty(chIdx)
    disp(['Bad Channels: ', num2str(chIdx')]);
else
    disp('No channel is excluded.');
end

return;
end

%% 
function previewRawWave(trialsData, badtrialIdx, V)
    % Preview good trials (mean, red) against bad trials (single, grey)

    [nch, ~] = mu.checkdata(trialsData);
    temp = find(badtrialIdx);
    chData = struct();
    
    if ~isempty(temp) || all(badtrialIdx)

        for index = 1:length(temp)
            chData(index).chMean = trialsData{temp(index)};
            chData(index).color = [200, 200, 200] / 255;
        end
    
        chData(index + 1).chMean = mu.calchMean(trialsData(~badtrialIdx));
        chData(index + 1).color = 'r';
    else
        chData.chMean = mu.calchMean(trialsData);
        chData.color = 'r';
    end
    
    Fig = mu_plotWaveArray(chData, [0, 1], "Channels", setdiff(1:nch, find(V == 0)));
    mu.scaleAxes(Fig, "y", "cutoffRange", [-200, 200], "symOpts", "max", "uiOpt", "show");
    return;
end