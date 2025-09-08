function varargout = getObjVal(FigsOrAxes, ObjType, varargin)
% GETOBJVAL  Get properties of graphic objects with optional filtering.
%
% Usage:
%   [vals, objs] = mu.getObjVal(FigsOrAxes, ObjType)
%   [vals, objs] = mu.getObjVal(FigsOrAxes, ObjType, getParams)
%   [vals, objs] = mu.getObjVal(FigsOrAxes, ObjType, getParams, searchParams, searchValue)
%
% Inputs:
%   FigsOrAxes   - Handle or array of figure or axes graphics objects
%   ObjType      - Type of graphic object to find (line, patch, bar, image, axes, figure, FigOrAxes, Histogram)
%   getParams    - (optional) string array of property names to get from found objects
%   searchParams - (optional) string array of property names to filter objects by
%   searchValue  - (optional) values corresponding to searchParams for filtering
%
% Outputs:
%   varargout{1} - If getParams is empty, returns handles of found objects;
%                  otherwise, struct array with requested properties for each found object.
%   varargout{2} - Handles of found objects matching search criteria (empty if none found)

% Parse and validate inputs
mIp = inputParser;
validObjTypes = {'line', 'patch', 'bar', 'image', 'axes', 'figure', 'FigOrAxes', 'Histogram'};

mIp.addRequired("FigsOrAxes", @(x) all(ishandle(x) & isgraphics(x)));
mIp.addRequired("ObjType", @(x) ischar(x) || isstring(x));
mIp.addOptional("getParams", [], @(x) isempty(x) || all(isstring(x) | ischar(x)));
mIp.addOptional("searchParams", [], @(x) isempty(x) || all(isstring(x) | ischar(x)));
mIp.addOptional("searchValue", [], @(x) isempty(x) || isnumeric(x) || isstring(x) || iscellstr(x));
mIp.parse(FigsOrAxes, ObjType, varargin{:});

getParams = mIp.Results.getParams;
searchParams = mIp.Results.searchParams;
searchValue = mIp.Results.searchValue;
ObjType = validatestring(ObjType, validObjTypes);

% Normalize getParams and searchParams to string arrays for consistent handling
if ~isempty(getParams)
    getParams = string(getParams);
end
if ~isempty(searchParams)
    searchParams = string(searchParams);
end

% Find target objects
if ObjType ~= "FigOrAxes"
    Obj = findobj(FigsOrAxes, "Type", ObjType);
else
    % Combine figures and axes handles
    figs = findobj(FigsOrAxes, "Type", "figure");
    axesh = findobj(FigsOrAxes, "Type", "axes");
    Obj = [figs; axesh];
end

if isempty(Obj)
    warning("No objects of type '%s' found.", ObjType);
    varargout{1} = [];
    if nargout > 1, varargout{2} = []; end
    return;
end

% Filter objects by searchParams and searchValue if provided
if ~isempty(searchParams)
    if numel(searchParams) ~= numel(searchValue)
        error("searchParams and searchValue must have the same length.");
    end
    mask = true(size(Obj));
    for idx = 1:numel(searchParams)
        propVals = get(Obj, searchParams(idx));
        val = searchValue(idx);
        if isnumeric(val)
            % Numeric comparison, allow scalar or arrays
            if iscell(propVals)
                compMask = cellfun(@(x) isequal(x,val), propVals);
            else
                compMask = (propVals == val);
            end
        else
            % String comparison, case-insensitive
            if iscell(propVals)
                compMask = cellfun(@(x) strcmpi(string(x), string(val)), propVals);
            else
                compMask = strcmpi(string(propVals), string(val));
            end
        end
        mask = mask & compMask;
    end
    Obj = Obj(mask);
end

if isempty(Obj)
    % No objects after filtering
    %warning("No objects matching filter criteria found.");
    varargout{1} = [];
    if nargout > 1, varargout{2} = []; end
    return;
end

% If no getParams, return the filtered object handles
if isempty(getParams)
    varargout{1} = Obj;
    if nargout > 1
        varargout{2} = Obj;
    end
    return;
end

% Get requested properties for each object, return as struct array
nObj = numel(Obj);
result = struct();

for pIdx = 1:numel(getParams)
    propName = getParams(pIdx);
    try
        propVals = get(Obj, propName);
    catch ME
        error("Failed to get property '%s' from objects: %s", propName, ME.message);
    end

    % If single object, wrap to cell for uniform processing
    if nObj == 1
        propVals = {propVals};
    end

    % Assign to struct
    for oIdx = 1:nObj
        result(oIdx).(propName) = propVals{oIdx};
    end
end

varargout{1} = result;

if nargout > 1
    varargout{2} = Obj;
end

end
