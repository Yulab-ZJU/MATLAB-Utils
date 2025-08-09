function stat = mu_cbpt_impl(data, cfg)
% Description: cluster-based permutation test for 2 or more than 2 groups of data
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
%          - design: design matrix of trialinfo (DO NOT SPECIFY IN YOUR cfg)
%          - ivar: number or list with indices indicating the independent variable(s)
%                  (default = 1, DO NOT SPECIFY IN YOUR cfg)
% Output:
%     stat: result of fieldtrip
%           - prob: prob of cluster-based Monte Carlo permutation test, [nCh, nSample]
%           - posclusters/negclusters: 1*k struct of information of each cluster
%           - posclusterslabelmat/negclusterslabelmat: cluster position specified by 
%                                                      non-zero values, [nCh, nSample]
%           - mask: significant sample position, [nCh, nSample] logical
%           - stat: the effect at the sample level (t-value or f-value by cfg.statistic), [nCh, nSample]

ft_promotepaths;
narginchk(1, 2);

if nargin < 2
    cfg = [];
end

cfg_default.method           = 'montecarlo';         % use the Monte Carlo Method to calculate the significance probability
cfg_default.correctm         = 'cluster';
cfg_default.correcttail      = 'alpha';              % 'alpha': equivalent to performing a Bonferroni correction for the two tails, i.e., 
                                                     %          divide alpha by two. Each tail will be tested with alpha = 0.025.
                                                     % 'prob': multiplying the p-values with a factor of 2
                                                     
cfg_default.clusterstatistic = 'maxsum';             % test statistic that will be evaluated under the permutation distribution.

cfg_default.clusteralpha     = 0.05;                 % alpha level of the sample-specific test statistic that will be used for thresholding
cfg_default.alpha            = 0.05;                 % alpha level of the permutation test

cfg_default.neighbours       = [];                   % the neighbours specify for each sensor with which other sensors it can form clusters
cfg_default.minnbchan        = 0;                    % minimum number of neighborhood channels that is
                                                     % required for a selected sample to be included
                                                     % in the clustering algorithm (default=0).

% cfg_default.latency          = [0 1];                % time interval over which the experimental conditions must be compared (in seconds)

cfg_default.numrandomization = 1e3;                  % number of draws from the permutation distribution

if numel(data) == 2
    cfg_default.statistic    = 'indepsamplesT';      % statistic method to evaluate the effect at the sample level
    cfg_default.tail         = 0;                    % -1, 1 or 0 (default = 0); one-sided or two-sided test
    cfg_default.clustertail  = 0;                    % identical to tail option
else
    cfg_default.statistic    = 'indepsamplesF';      % statistic method to evaluate the effect at the sample level
    cfg_default.tail         = 1;                    % -1, 1 or 0 (default = 0); one-sided or two-sided test
    cfg_default.clustertail  = 1;                    % identical to tail option
end

cfg = mu.getorfull(cfg, cfg_default);

cfg.channel = data(1).label;                % cell-array with selected channel labels
cfg.design  = vertcat(data.trialinfo)';     % design matrix
cfg.ivar    = 1;                            % number or list with indices indicating the independent variable(s)

temp = mat2cell(reshape(data, [numel(data), 1]), ones(numel(data), 1));
stat = ft_timelockstatistics(cfg, temp{:});
end