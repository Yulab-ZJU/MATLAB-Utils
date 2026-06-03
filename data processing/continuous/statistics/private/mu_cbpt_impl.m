function stat = mu_cbpt_impl(data, cfg)
% Description: cluster-based permutation test for 2 or more groups of data.
% NOTICE: If you run into error messages like "too many args input for nearest",
%         then solution to function name duplication is to add fieldtrip path to
%         the beginning of pathdef.m (or via path settings) or run `ft_setPath2Top` 
%         script.
% Input:
%     data: n*1 struct with fields:
%           - time: 1-by-nSample double
%           - label: channel label, nCh-by-1 char cell array
%           - trial: trial data, nTrial*nCh*nSample double
%           - trialinfo: trial type label (>=1 and begins with 1),
%                        nTrial-by-1 double
%     cfg: configurations (you can alter settings marked * for better performance)
%          - method: method to calculate significance probability (default: 'montecarlo')
%        * - statistic: 'indepsamplesT'(for 2 groups), 'indepsamplesF'(for more than 2 groups)
%          - correctm: 'no', 'max', 'cluster'(default), 'bonferoni', 'holms', or 'fdr'.
%          - correcttail: 'alpha' (default) or 'prob'. 
%                         'alpha': equivalent to performing a Bonferroni correction for the two tails, i.e., 
%                                  divide alpha by two. Each tail will be tested with alpha = 0.025.
%                         'prob': multiplying the p-values with a factor of 2
%        * - clusterstatistic: 'maxsum'(default), 'maxsize', or 'wcm'
%        * - clusteralpha: alpha level of the sample-specific test statistic that will be used
%                          for thresholding (default = 0.05)
%        * - alpha: alpha level of the permutation test (default = 0.025)
%        * - numrandomization: number of draws from the permutation distribution (default = 1e3)
%          - tail & clustertail: -1, 1 or 0 (default = 0): one-sided or two-sided test
%        * - neighbours: the neighbours specify for each sensor with which other sensors it can
%                        form clusters
%        * - minnbchan: minimum number of neighborhood channels that is required for a selected
%                       sample to be included in the clustering algorithm (default = 0).
%          - latency: time interval over which the experimental conditions must be compared (in seconds)
%          - channel: cell-array with selected channel labels (default = 'all')
% Output:
%     stat: result of fieldtrip
%           - prob: prob of cluster-based Monte Carlo permutation test, [nCh, nSample]
%           - posclusters/negclusters: 1*k struct of information of each cluster
%           - posclusterslabelmat/negclusterslabelmat: cluster position specified by 
%                                                      non-zero values, [nCh, nSample]
%           - mask: significant sample position, [nCh, nSample] logical
%           - stat: the effect at the sample level (t-value or f-value by cfg.statistic), [nCh, nSample]
%
% For two paired conditions, this function uses:
%     cfg.statistic = 'depsamplesT'
%     cfg.uvar      = 1;   % unit/subject variable
%     cfg.ivar      = 2;   % condition variable
%
% For two independent conditions, this function uses:
%     cfg.statistic = 'indepsamplesT'
%     cfg.ivar      = 1;
%
% For more than two conditions:
%     paired     -> 'depsamplesFmultivariate'
%     independent -> 'indepsamplesF'
%
% Additional cfg field:
%     cfg.paired = true, false, or 'auto'
%                  default = 'auto'
%
%                  'auto' uses dependent-samples design when all conditions
%                  have the same number of observations.
%
% Important:
%     For paired tests, observations must be ordered identically across
%     conditions. For example, data(1).trial(k,:,:) and data(2).trial(k,:,:)
%     should correspond to the same participant.

ft_promotepaths;
narginchk(1, 2);

if nargin < 2 || isempty(cfg)
    cfg = [];
end

nCond = numel(data);
nObs  = arrayfun(@(x) size(x.trial, 1), data);

% -------------------------------------------------------------------------
% Resolve whether this is a paired/dependent-samples design
% -------------------------------------------------------------------------
if isfield(cfg, "paired")
    paired = cfg.paired;
    cfg = rmfield(cfg, "paired");
else
    paired = 'auto';
end

if ischar(paired) || isstring(paired)
    paired = string(paired);

    switch lower(paired)
        case "auto"
            paired = numel(unique(nObs)) == 1;
        case {"true", "paired", "dependent", "depsamples"}
            paired = true;
        case {"false", "independent", "indepsamples"}
            paired = false;
        otherwise
            error("cfg.paired must be true, false, or 'auto'.");
    end
end

paired = logical(paired);

if paired && numel(unique(nObs)) ~= 1
    error(["Dependent-samples statistics require the same number of observations " ...
           "in all conditions. Current numbers are: %s."], mat2str(nObs));
end

% -------------------------------------------------------------------------
% Default FieldTrip cfg
% -------------------------------------------------------------------------
cfg_default = [];

cfg_default.method           = 'montecarlo';
cfg_default.correctm         = 'cluster';
cfg_default.correcttail      = 'alpha';

cfg_default.clusterstatistic = 'maxsum';
cfg_default.clusteralpha     = 0.05;
cfg_default.alpha            = 0.05;

cfg_default.neighbours       = [];
cfg_default.minnbchan        = 0;

cfg_default.numrandomization = 1e3;

% Choose default sample-level statistic
if nCond == 2
    if paired
        cfg_default.statistic = 'depsamplesT';
    else
        cfg_default.statistic = 'indepsamplesT';
    end

    cfg_default.tail        = 0;
    cfg_default.clustertail = 0;
else
    if paired
        cfg_default.statistic = 'depsamplesFmultivariate';
    else
        cfg_default.statistic = 'indepsamplesF';
    end

    cfg_default.tail        = 1;
    cfg_default.clustertail = 1;
end

cfg = mu.getorfull(cfg, cfg_default);

% -------------------------------------------------------------------------
% Build FieldTrip design matrix
% -------------------------------------------------------------------------
cfg.channel = data(1).label;

if paired
    % Dependent-samples design:
    % row 1: unit/participant index
    % row 2: condition index
    %
    % Example for 2 conditions and 47 participants:
    % design(1,:) = [1:47, 1:47]
    % design(2,:) = [ones(1,47), 2*ones(1,47)]
    nUnit = nObs(1);

    design = zeros(2, nUnit * nCond);

    for cIndex = 1:nCond
        colIdx = (cIndex - 1) * nUnit + (1:nUnit);

        design(1, colIdx) = 1:nUnit;
        design(2, colIdx) = cIndex;
    end

    cfg.design = design;
    cfg.uvar   = 1;
    cfg.ivar   = 2;
else
    % Independent-samples design:
    % one row indicating condition label.
    design = [];

    for cIndex = 1:nCond
        design = [design, cIndex * ones(1, nObs(cIndex))]; %#ok<AGROW>
    end

    cfg.design = design;
    cfg.ivar   = 1;

    if isfield(cfg, "uvar")
        cfg = rmfield(cfg, "uvar");
    end
end

% -------------------------------------------------------------------------
% Run FieldTrip statistics
% -------------------------------------------------------------------------
dataCell = mat2cell(reshape(data, [nCond, 1]), ones(nCond, 1));

stat = ft_timelockstatistics(cfg, dataCell{:});

end