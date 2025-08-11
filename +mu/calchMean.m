function [chMean, trialsData] = calchMean(trialsData, padDir)
% See mu.calchFunc for more information
[chMean, trialsData] = calchFunc(@mean, trialsData, padDir);
