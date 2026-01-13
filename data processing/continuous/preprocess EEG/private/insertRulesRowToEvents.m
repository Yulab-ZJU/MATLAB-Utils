function trialsData2 = insertRulesRowToEvents(trialsData, rules, varargin)
%INSERTRULESROWT OEVENTS  Insert rules row fields into trialsData.events by matching code.
%
% trialsData: struct array with fields:
%   - trialIndex (optional)
%   - events : struct array, each event has field .code (numeric, can be NaN)
%
% rules: table with field 'code' and other parameter columns.
%
% Name-Value:
%   'OnMissing'   : "keep" (default) | "warn" | "error"
%   'OnDuplicate' : "first" (default) | "error"
%   'ExcludeVars' : string/cellstr of variable names to skip (default: ["code"])
%
% Output:
%   trialsData2 : same as trialsData, but each event with code gets fields from rules row.

p = inputParser;
p.addParameter('OnMissing',   "keep");
p.addParameter('OnDuplicate', "first");
p.addParameter('ExcludeVars', "code");
p.parse(varargin{:});

onMissing   = string(p.Results.OnMissing);
onDuplicate = string(p.Results.OnDuplicate);
excludeVars = string(p.Results.ExcludeVars);

assert(istable(rules) && ismember("code", rules.Properties.VariableNames), ...
    "rules must be a table and contain variable 'code'.");

trialsData2 = trialsData;

% ---- build code -> row index map ----
ruleCodes = rules.code;
if iscell(ruleCodes), ruleCodes = cellfun(@double, ruleCodes); end
ruleCodes = double(ruleCodes(:));

% Handle duplicates
[uc, ~, ic] = unique(ruleCodes, 'stable');
if numel(uc) < numel(ruleCodes)
    dupCodes = uc(accumarray(ic,1) > 1);
    switch onDuplicate
        case "first"
            % keep first occurrence: build map using first index
        case "error"
            error("rules.code has duplicates: %s", mat2str(dupCodes'));
        otherwise
            error("Invalid OnDuplicate: %s", onDuplicate);
    end
end

% Map: code -> first row index
code2row = containers.Map('KeyType','double','ValueType','double');
for i = 1:height(rules)
    c = double(ruleCodes(i));
    if ~isKey(code2row, c)
        code2row(c) = i;
    end
end

% Which vars to inject
vars = string(rules.Properties.VariableNames);
vars = vars(~ismember(vars, excludeVars));

% ---- process each trial ----
if ~isfield(trialsData2, "events")
    return;
end

for t = 1:numel(trialsData2)
    ev = trialsData2(t).events;
    if isempty(ev), continue; end

    % ensure struct array
    if ~isstruct(ev)
        error("trialsData(%d).events must be struct array.", t);
    end

    for e = 1:numel(ev)
        if ~isfield(ev(e),"code"), continue; end
        c = ev(e).code;

        if isempty(c) || any(isnan(c))
            continue
        end

        c = double(c);

        if ~isKey(code2row, c)
            switch onMissing
                case "keep"
                    % do nothing
                case "warn"
                    warning("No matching rules row for code=%g (trial %d, event %d).", c, t, e);
                case "error"
                    error("No matching rules row for code=%g (trial %d, event %d).", c, t, e);
                otherwise
                    error("Invalid OnMissing: %s", onMissing);
            end
            continue
        end

        r = code2row(c); % matched rules row index

        % inject each rules variable as field into event struct
        for v = 1:numel(vars)
            name = vars(v);

            col = rules.(name);
            % extract scalar value at row r
            val = col(r,:);

            % normalize table slicing outcomes
            if istable(val)
                % rare case: nested table; keep as table
            else
                % if it's a cell, unwrap single cell
                if iscell(val) && isscalar(val)
                    val = val{1};
                end
                % if it's string scalar, keep as string
                if isstring(val) && ~isscalar(val)
                    val = val(1);
                end
                % if it's categorical, keep as is
                % if it's numeric row, squeeze
                if isnumeric(val) && ~isscalar(val)
                    val = val(1);
                end
            end

            ev(e).(char(name)) = val;
        end

        % optionally also store the matched row index
        ev(e).rulesRow = r;
    end

    trialsData2(t).events = ev;
end
end
