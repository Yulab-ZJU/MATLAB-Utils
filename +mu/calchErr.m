function chErr = calchErr(trialsData, padDir)
% See mu.calchFunc for more information
chErr= calchFunc(@mu.se, trialsData, padDir);
