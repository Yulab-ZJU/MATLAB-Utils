classdef mu_scaleplate < handle
    properties
        % figure handle
        Figure

        % scaleplate axes
        Axes
        Position

        % option
        ShowXScale
        ShowYScale

        % fix x,y val
        XVal
        YVal

        % scaleplate x,y scales
        XRange
        YRange
        XScale
        YScale

        % line params
        LineWidth
        LineStyle
        LineColor

        % text params
        FontSize
        FontWeight
        FontAngle
        FontName
        FontColor
    end

    properties(SetObservable)
        % text params
        XScaleUnit
        YScaleUnit

        % use fixed scaleplate
        FixScale
    end
    
    methods
        function obj = mu_scaleplate(varargin)

            if isscalar(varargin{1}) && isa(varargin{1}, "matlab.ui.Figure")
                Fig = varargin{1};
                varargin = varargin(2:end);
            else
                Fig = gcf;
            end

            mIp = inputParser;
            mIp.addRequired("Fig");
            mIp.addParameter("Position", [], @(x) validateattributes(x, 'numeric', {'numel', 2, 'vector', 'real'}));
            mIp.addParameter("LineWidth", 1, @(x) validateattributes(x, 'numeric', {'scalar', 'positive'}));
            mIp.addParameter("LineStyle", "-");
            mIp.addParameter("LineColor", [0, 0, 0]);
            mIp.addParameter("FontSize", [], @(x) validateattributes(x, 'numeric', {'scalar', 'positive'}));
            mIp.addParameter("FontWeight", []);
            mIp.addParameter("FontAngle", []);
            mIp.addParameter("FontName", []);
            mIp.addParameter("FontColor", [0, 0, 0]);
            mIp.addParameter("FixScale", mu.OptionState.Off);
            mIp.addParameter("XVal", [], @(x) validateattributes(x,'numeric', {'scalar', 'real'}));
            mIp.addParameter("YVal", [], @(x) validateattributes(x,'numeric', {'scalar', 'real'}));
            mIp.addParameter("XScaleUnit", '', @mustBeTextScalar);
            mIp.addParameter("YScaleUnit", '', @mustBeTextScalar);
            mIp.addParameter("ShowXScale", mu.OptionState.On, @mu.OptionState.validate);
            mIp.addParameter("ShowYScale", mu.OptionState.On, @mu.OptionState.validate);
            mIp.parse(Fig, varargin{:});

            obj.Figure = Fig;
            axesAll = findall(Fig, 'Type', 'axes', ...
                              '-not', 'Visible', 'off', ...
                              '-not', 'Tag', 'ScalePlate');
            if isempty(axesAll)
                error('No axes found in the figure.');
            end

            obj.LineWidth = mIp.Results.LineWidth;
            obj.LineStyle = mIp.Results.LineStyle;
            obj.LineColor = validatecolor(mIp.Results.LineColor);

            obj.FontSize   = mu.getor(mIp.Results, "FontSize"  , get(axesAll(1), "FontSize"  ), true);
            obj.FontWeight = mu.getor(mIp.Results, "FontWeight", get(axesAll(1), "FontWeight"), true);
            obj.FontAngle  = mu.getor(mIp.Results, "FontAngle" , get(axesAll(1), "FontAngle" ), true);
            obj.FontName   = mu.getor(mIp.Results, "FontName"  , get(axesAll(1), "FontName"  ), true);
            obj.FontColor  = validatecolor(mIp.Results.FontColor);
            
            obj.FixScale = mu.OptionState.create(mIp.Results.FixScale);
            obj.XVal = mIp.Results.XVal;
            obj.YVal = mIp.Results.YVal;

            obj.XScaleUnit = mIp.Results.XScaleUnit;
            obj.YScaleUnit = mIp.Results.YScaleUnit;

            obj.ShowXScale = mu.OptionState.create(mIp.Results.ShowXScale).toLogical;
            obj.ShowYScale = mu.OptionState.create(mIp.Results.ShowYScale).toLogical;

            posXY = mIp.Results.Position(:)'; % [x, y]
            temp = cat(1, axesAll.Position);
            axPos = get(axesAll(1), 'Position');
            if isempty(posXY)
                % set left-bottom as default position
                pos = [min(temp(:, 1)), min(temp(:, 2)), axPos(3), axPos(4)];
            else
                pos = [posXY, axPos(3), axPos(4)];
            end
            
            obj.Position = pos;
            obj.Axes = axes('Parent', Fig, 'Position', pos, 'Tag', 'ScalePlate', 'Visible', 'off');
            set(obj.Axes, 'HitTest', 'off', 'PickableParts', 'none');
            obj.updateScale();
            
            % register listener
            addlistener(axesAll(1), 'XLim', 'PostSet', @(src, evt) obj.updateScale());
            addlistener(axesAll(1), 'YLim', 'PostSet', @(src, evt) obj.updateScale());
            addlistener(obj, 'XScaleUnit', 'PostSet', @(src, evt) obj.updateScale());
            addlistener(obj, 'YScaleUnit', 'PostSet', @(src, evt) obj.updateScale());
            addlistener(obj, 'FixScale', 'PostSet', @(src, evt) obj.updateScale());
        end
        
        function updateScale(obj)
            axes(obj.Axes); 
            cla(obj.Axes);
            obj.getScale();

            if ~isempty(obj.XVal)
                obj.XScale = obj.XVal; % use user-specified value
            end

            if ~isempty(obj.YVal)
                obj.YScale = obj.YVal; % use user-specified value
            end

            xlim(obj.Axes, obj.XRange);
            ylim(obj.Axes, obj.YRange);

            lineParams = {'Color', obj.LineColor, 'LineWidth', obj.LineWidth, 'LineStyle', obj.LineStyle};
            textParams = {'FontSize', obj.FontSize, 'Color', obj.FontColor, 'FontWeight', obj.FontWeight, 'FontAngle', obj.FontAngle, 'FontName', obj.FontName};
            
            % x scale
            if obj.ShowXScale
                xtext = mu.ifelse(isempty(obj.XScaleUnit), num2str(obj.XScale), [num2str(obj.XScale), ' ', char(obj.XScaleUnit)]);
                line(obj.Axes, [-obj.XScale / 2, obj.XScale / 2] + mean(obj.XRange), [0, 0] + mean(obj.YRange) - obj.YScale / 2, ...
                     lineParams{:});
                text(obj.Axes, mean(obj.XRange), mean(obj.YRange) - obj.YScale / 2 * 1.2, xtext, ...
                     'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', ...
                     textParams{:});
            end
            
            % y scale
            if obj.ShowYScale
                ytext = mu.ifelse(isempty(obj.YScaleUnit), num2str(obj.YScale), [num2str(obj.YScale), ' ', char(obj.YScaleUnit)]);
                line(obj.Axes, [0, 0] + mean(obj.XRange) - obj.XScale / 2, [-obj.YScale / 2, obj.YScale / 2] + mean(obj.YRange), ...
                     lineParams{:});
                text(obj.Axes, mean(obj.XRange) - obj.XScale / 2 * 1.1, mean(obj.YRange), ytext, ...
                     'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle', ...
                     textParams{:});
            end

            return;
        end

        function getScale(obj)
            axesAll = findall(obj.Figure, 'Type', 'axes', ...
                              '-not', 'Visible', 'off', ...
                              '-not', 'Tag', 'ScalePlate');
            if isempty(axesAll), return; end
            
            obj.XRange = get(axesAll(1), 'XLim');
            obj.YRange = get(axesAll(1), 'YLim');

            if ~obj.FixScale.toLogical || isempty(obj.XScale) || isempty(obj.YScale)
                % do not use fixed scales
                obj.XScale = mode(diff(xticks(axesAll(1))));
                obj.YScale = mode(diff(yticks(axesAll(1))));
            end

            % xticks missing
            if isempty(obj.XScale)
                % use xlim/2
                obj.XScale = diff(obj.XRange) / 2;
            end

            % yticks missing
            if isempty(obj.YScale)
                % use ylim/2
                obj.YScale = diff(obj.YRange) / 2;
            end

            if obj.XScale > diff(obj.XRange) || obj.YScale > diff(obj.YRange)
                warning('Current scaleplate exceeds axis range. If you are using [FixScale], please consider setting it OFF.');
            end
            
            return;
        end

    end

end