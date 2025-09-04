function stat = mu_cbpt(cfg, varargin)
% Description: cluster-based permutation test for 2 or more than 2 groups of data
% NOTICE: If you run into error messages like "too many args input for nearest",
%         then solution to function name duplication is to add fieldtrip path to
%         the beginning of pathdef.m (or via path settings) or run `ft_setPath2Top` 
%         script.
% Input:
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
%          - tail & clustertail: 1 (right), -1 (left) or 0 (both) (default = 0)
%        * - neighbours: the neighbours specify for each sensor with which other sensors it can
%                        form clusters
%        * - minnbchan: minimum number of neighborhood channels that is required for a selected
%                       sample to be included in the clustering algorithm (default = 0).
%          - latency: time interval over which the experimental conditions must be compared (in seconds)
%          - channel: cell-array with selected channel labels (default = 'all')
%          - design: design matrix of trialinfo (DO NOT specify it in your [cfg])
%          - ivar: number or list with indices indicating the independent variable(s)
%                  (default = 1, DO NOT specify it in your [cfg])
%     trialsData: cell data of trial
% Output:
%     stat: result of fieldtrip
%           - prob: prob of cluster-based Monte Carlo permutation test, [nCh, nSample]
%           - posclusters/negclusters: 1*k struct of information of each cluster
%           - posclusterslabelmat/negclusterslabelmat: cluster position specified by non-zero values, [nCh, nSample]
%           - mask: significant sample position, [nCh, nSample] logical
%           - stat: the effect at the sample level (t-value or f-value by cfg.statistic), [nCh, nSample]

narginchk(3, inf);

% validate
[nch, nsample] = mu.checkdata(varargin{:});

data = struct("time"     , cell(numel(varargin), 1), ...
              "label"    , cell(numel(varargin), 1), ...
              "trial"    , cell(numel(varargin), 1), ...
              "trialinfo", cell(numel(varargin), 1));
for index = 1:numel(varargin)
    trialsData = varargin{index};
    data(index).time = linspace(0, 1, nsample); % normalized time
    data(index).label = compose('%d', (1:nch)');
    data(index).trial = cell2mat(cellfun(@(x) permute(x, [3, 1, 2]), trialsData, "UniformOutput", false));
    data(index).trialinfo = repmat(index, [numel(trialsData), 1]);
end

stat = mu_cbpt_impl(data, cfg);
return;
end