classdef dispstate < handle
    properties (Access = public)
        str
    end

    methods (Access = public)
        function update(obj, newstr)
            mustBeTextScalar(newstr);
            newstr = char(newstr);
            if isempty(obj.str)
                fprintf('%s', newstr);
                obj.str = newstr;
                return;
            end
            fprintf(repmat('\b', 1, length(obj.str)));
            fprintf('%s', newstr);
            obj.str = newstr;
        end

        function obj = dispstate(str)
            narginchk(0, 1);
            if nargin < 1
                return;
            end
            mustBeTextScalar(str);
            str = char(str);
            obj.str = str;
            fprintf('%s', str);
        end

        function finish(obj)
            fprintf('\n');
            obj.str = '';
        end
    end
end