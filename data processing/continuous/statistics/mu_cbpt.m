function stat = mu_cbpt(cfg, varargin)
% Description: cluster-based permutation test for 2 or more groups of data.
%
% Input:
%     cfg: configurations
%          - paired: true, false, or 'auto' (default = 'auto')
%                    true  : dependent-samples design
%                    false : independent-samples design
%                    'auto': use dependent-samples design when all groups
%                            have the same number of observations
%
%          For paired/dependent-samples tests, observations across conditions
%          must be ordered identically, e.g.,
%          varargin{1}{k} and varargin{2}{k} should come from the same subject.
%
%     trialsData:
%          each input condition is a cell array.
%          each cell should contain one observation, usually [nCh x nSample].
%
% Output:
%     stat: FieldTrip cluster-based permutation result.

narginchk(3, inf);

% Validate data size
[nch, nsample] = mu.checkdata(varargin{:});

data = struct("time"     , cell(numel(varargin), 1), ...
              "label"    , cell(numel(varargin), 1), ...
              "trial"    , cell(numel(varargin), 1), ...
              "trialinfo", cell(numel(varargin), 1), ...
              "dimord"   , cell(numel(varargin), 1));

for index = 1:numel(varargin)
    trialsData = varargin{index};

    data(index).time  = linspace(0, 1, nsample); % normalized time
    data(index).label = compose('%d', (1:nch)');

    % Convert each observation from [nCh x nSample] to [1 x nCh x nSample],
    % then concatenate into [nObs x nCh x nSample].
    data(index).trial = cell2mat(cellfun(@(x) permute(x, [3, 1, 2]), ...
                                        trialsData, ...
                                        "UniformOutput", false));

    data(index).trialinfo = repmat(index, [numel(trialsData), 1]);
    data(index).dimord    = 'rpt_chan_time';
end

stat = mu_cbpt_impl(data, cfg);

end