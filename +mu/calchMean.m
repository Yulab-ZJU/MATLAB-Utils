function [chMean, trialsData] = calchMean(trialsData, padDir)
% See mu.calchFunc for more information
narginchk(1, 2);

if nargin < 2
    padDir = "last";
end

[chMean, trialsData] = mu.calchFunc(@mean, trialsData, padDir);
