function varargout = parsestruct(S, varargin)
% PARSESTRUCT Parse fields from a struct vector.
% Usage:
%   mu.parsestruct(S)                  % assign all fields to caller workspace
%   mu.parsestruct(S, 'a', 'b')         % assign selected fields to caller workspace
%   [A, B] = mu.parsestruct(S, 'a', 'b')  % return outputs
%
% Input:
%   S: struct vector
%   varargin: optional list of field names to parse (default: all fields)
%
% Output:
%   varargout: requested fields as output arguments
%
% Notice:
%   If not all field values have compatible types/sizes, outputs are returned as cell arrays.

validateattributes(S, {'struct'}, {'vector'});

% Determine fields to parse
if isempty(varargin)
    fieldsToParse = string(fieldnames(S));
else
    fieldsToParse = string(varargin);
    % validate field names
    invalid = fieldsToParse(~ismember(fieldsToParse, string(fieldnames(S))));
    if ~isempty(invalid)
        error("Invalid field name(s): %s", strjoin(invalid, ", "));
    end
end

nFields = numel(fieldsToParse);

% Determine output mode
if nargout > 0
    % return outputs
    varargout = cell(1, nFields);
    for k = 1:nFields
        try
            varargout{k} = vertcat(S.(fieldsToParse(k)));
        catch
            % incompatible types/sizes -> return as cell array
            varargout{k} = {S.(fieldsToParse(k))}';
        end
    end
else
    % assign to caller workspace
    for k = 1:nFields
        try
            if iscolumn(S)
                val = vertcat(S.(fieldsToParse(k)));
            else
                val = horzcat(S.(fieldsToParse(k)));
            end
        catch
            val = {S.(fieldsToParse(k))}';
        end
        assignin('caller', fieldsToParse(k), val);
    end
end

return;
end
