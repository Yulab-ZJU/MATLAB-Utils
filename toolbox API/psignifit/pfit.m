function fitRes = pfit(data, varargin)
% Description: do sigmoid fitting via psigfit toolbox
% Input:
%     data: n*2 | n*3 matrix, the first column is x, the second column is
%           correct ratio(when 2 columns) | correct counts (when 3 columns with
%           column 3 being the total counts corresponding to a certain x).
%     xFit: The custom x'. Default: 1000 points with linspace in the range of [min(data, max(data)]
%     sigmoidName: This sets the type of sigmoid you fit to your data.
%     expType: This sets which parameters you want to be free and which you fix and to
%              which values, for standard experiment types.
%     expN: The number of alternatives when "expType" is set to "nAFC".
%     threshPC: Which percent correct correspond to the threshold?
%     useGPU : Decide use GPU or not
%     plotFitRes: A boolean to control whether you immediately have a view
%                 of fit result
%
% Output:
%     fitRes: struct
%       -xFit:
%       -yFit:
%       -pFitRes:
%       -data:
% example:
%     pfit(data, "expType", "YesNo", "plotFitRes", 0, "sigmoidName", 'gaussint', "xFit", linspace(x1,x2, 1000));

mIp = inputParser;
mIp.addRequired("data", @(x) ismatrix(x) & ismember(size(x, 2), [2, 3]));
mIp.addParameter("xFit", linspace(data(1, 1), data(end, 1), 1000), @isnumeric);
mIp.addParameter("sigmoidName", "norm", @(x) any(validatestring(x, {'norm', 'gauss', 'gaussint', 'logistic', 'logn', 'weibull', 'gumbel', 'rgumbel', 'tdist'})));
mIp.addParameter("expType", "YesNo", @(x) any(validatestring(x, {'YesNo', '2AFC', 'nAFC'})));
mIp.addParameter("expN", 3, @(x) x >= 3);
mIp.addParameter("threshPC", 0.5, @(x) x > 0 & x < 1);
mIp.addParameter("useGPU", 0, @(x) ismember(x, [0, 1]));
mIp.addParameter("plotFitRes", 0, @(x) ismember(x, [0, 1]));
mIp.parse(data, varargin{:});

xFit = mIp.Results.xFit;
opts.sigmoidName = char(mIp.Results.sigmoidName);
opts.expType = char(mIp.Results.expType);
opts.expN = mIp.Results.expN;
opts.threshPC = mIp.Results.threshPC;
opts.useGPU = mIp.Results.useGPU;
plotFitRes = mIp.Results.plotFitRes;

if size(data, 2) == 1
    error("Invalid input 'data' !");
elseif size(data, 2) == 2
    if any(data(:, 2) > 1 | data(:, 2) < 0)
        error("Invalid input 'data' !");
    else
        data(:, 3) = 1000;
        data(:, 2) = fix(data(:, 2) * 1000);
    end
end

result = psignifit(data,opts);
yFit = result.psiHandle(xFit);

if plotFitRes
    plotPsych(result);
end

yFitChk = result.psiHandle(data(:, 1));
yRaw = data(:, 2)./data(:, 3);

fitRes.R2 = rsquare(yRaw, yFitChk);
fitRes.xFit = xFit;
fitRes.yFit = yFit;
fitRes.result = structSelect(result, ["Fit", "options"]);

fitRes.data = data;
fitRes.opts = opts;

return;
end

%% 
function [r2, rmse] = rsquare(y,f,varargin)
% Compute coefficient of determination of data fit model and RMSE
%
% [r2 rmse] = rsquare(y,f)
% [r2 rmse] = rsquare(y,f,c)
%
% RSQUARE computes the coefficient of determination (R-square) value from
% actual data Y and model data F. The code uses a general version of
% R-square, based on comparing the variability of the estimation errors
% with the variability of the original values. RSQUARE also outputs the
% root mean squared error (RMSE) for the user's convenience.
%
% Note: RSQUARE ignores comparisons involving NaN values.
%
% INPUTS
%   Y       : Actual data
%   F       : Model fit
%
% OPTION
%   C       : Constant term in model
%             R-square may be a questionable measure of fit when no
%             constant term is included in the model.
%   [DEFAULT] TRUE : Use traditional R-square computation
%            FALSE : Uses alternate R-square computation for model
%                    without constant term [R2 = 1 - NORM(Y-F)/NORM(Y)]
%
% OUTPUT
%   R2      : Coefficient of determination
%   RMSE    : Root mean squared error
%
% EXAMPLE
%   x = 0:0.1:10;
%   y = 2.*x + 1 + randn(size(x));
%   p = polyfit(x,y,1);
%   f = polyval(p,x);
%   [r2 rmse] = rsquare(y,f);
%   figure; plot(x,y,'b-');
%   hold on; plot(x,f,'r-');
%   title(strcat(['R2 = ' num2str(r2) '; RMSE = ' num2str(rmse)]))
%
% Jered R Wells
% 11/17/11
% jered [dot] wells [at] duke [dot] edu
%
% v1.2 (02/14/2012)
%
% Thanks to John D'Errico for useful comments and insight which has helped
% to improve this code. His code POLYFITN was consulted in the inclusion of
% the C-option (REF. File ID: #34765).

if isempty(varargin); c = true;
elseif length(varargin)>1; error 'Too many input arguments';
elseif ~islogical(varargin{1}); error 'C must be logical (TRUE||FALSE)'
else c = varargin{1};
end

% Compare inputs
if ~all(size(y)==size(f)); error 'Y and F must be the same size'; end

% Check for NaN
tmp = ~or(isnan(y),isnan(f));
y = y(tmp);
f = f(tmp);

if c
    r2 = max(0,1 - sum((y(:)-f(:)).^2)/sum((y(:)-mean(y(:))).^2));
else 
    r2 = 1 - sum((y(:)-f(:)).^2)/sum((y(:)).^2);
    if r2<0
        % http://web.maths.unsw.edu.au/~adelle/Garvan/Assays/GoodnessOfFit.html
        warning('Consider adding a constant term to your model') %#ok<WNTAG>
        r2 = 0;
    end
end

rmse = sqrt(mean((y(:) - f(:)).^2));
end

%% 
function sNew = structSelect(s, fieldSel)
fieldSel = string(fieldSel);
if length(s) > 1
    sField = fields(s);
    wrongIdx = find(~ismember(fieldSel, sField));
    if ~isempty(wrongIdx)
        error(strcat(strjoin(fieldSel(wrongIdx), ","), " is not a field in the old structure!"));
    end

    [~, selectIdx] = ismember(fieldSel, sField);

    structLength = length(s);
    oldCell = table2cell(struct2table(s));
    [m, n] = size(oldCell);
    if n == structLength
        oldCell = oldCell';
    end

    if ~isCellByCol(oldCell)
        oldCell = oldCell';
    end

    valueSel = oldCell(:, selectIdx);

    sNew = easyStruct(fieldSel, valueSel);
else
    for sIndex = 1 : length(fieldSel)
        sNew.(fieldSel(sIndex)) = s.(fieldSel(sIndex));
    end
end
end

%% 
function res = easyStruct(fieldName,fieldVal)
evalstr=['res=struct('];
%% if certain field is double defined, delete the old one
deleteIdx= [];
fieldN = unique(fieldName);
if length(fieldN) ~= length(fieldName)
    for i = 1:length(fieldN)
        if sum(strcmp(fieldName,fieldN{i})) > 1
            idx = find(strcmp(fieldName,fieldN{i}));
            reserveIdx = max(find(strcmp(fieldName,fieldN{i})));
            deleteIdx = [deleteIdx ; idx(idx~=reserveIdx)];
        end
    end
end
fieldName(deleteIdx) = [];
fieldVal(:,deleteIdx) = [];

for Paranum=1:length(fieldName)
    evalstr=[ evalstr '''' fieldName{Paranum} ''',' 'fieldVal(:,' num2str(Paranum) '),'];
end
evalstr(end)=[')'];
evalstr=[evalstr ';'];
eval(evalstr);
end

%% 
function trueOrFalse = isCellByCol(data)
    if ~iscell(data)
        trueOrFalse = false;
        return
    else
        temp = cellfun(@class, data', 'UniformOutput', false);
        temp = cellfun(@(x) strrep(x, 'single', 'double'), temp, "UniformOutput", false);
        if isscalar(unique(temp))
            trueOrFalse = true;
        else
            uniqueClass = cellfun(@unique, num2cell(temp, 2), 'UniformOutput', false);
            trueOrFalse = all(cellfun(@length, uniqueClass) == 1);
        end
    end
end