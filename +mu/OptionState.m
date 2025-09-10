classdef OptionState
    % OptionState - Unified on/off state
    % Supports true/'on'/'show'/'yes' and false/'off'/'hide'/'no'
    
    enumeration
        On
        Off
    end
    
    methods
        function tf = toLogical(obj)
            tf = (obj == mu.OptionState.On);
        end
        
        function str = toString(obj)
            if obj == mu.OptionState.On
                str = "on";
            else
                str = "off";
            end
        end
    end
    
    methods(Static)
        function obj = create(x)
            narginchk(0, 1);
            
            if nargin < 1
                obj = mu.OptionState.Off;
                return;
            end
            
            if isa(x, 'mu.OptionState')
                obj = x;
            elseif isnumeric(x)
                if ~ismember(x, [0, 1])
                    error("Invalid input for OptionState: %d. It should either be 0 or 1.", x);
                end
                if x == 1
                    obj = mu.OptionState.On;
                else
                    obj = mu.OptionState.Off;
                end
            elseif islogical(x)
                if x
                    obj = mu.OptionState.On;
                else
                    obj = mu.OptionState.Off;
                end
            elseif ischar(x) || isstring(x)
                s = lower(string(x));
                switch s
                    case {"on", "true", "show", "yes"}
                        obj = mu.OptionState.On;
                    case {"off", "false", "hide", "no"}
                        obj = mu.OptionState.Off;
                    otherwise
                        error("Invalid input for OptionState: %s", x);
                end
            else
                error("Unsupported input type for OptionState.");
            end
        end

        function [tf, ME] = validate(x)
            try
                mu.OptionState.create(x);
                tf = true;
                ME = [];
            catch ME
                tf = false;
            end
        end
    end
end
