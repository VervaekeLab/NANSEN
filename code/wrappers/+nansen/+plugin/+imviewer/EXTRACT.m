classdef EXTRACT < imviewer.ImviewerPlugin & applify.mixin.ModalMethodPreviewController
%EXTRACT Preview EXTRACT ROI segmentation parameters in imviewer.
%
%   EXTRACT is an imviewer plugin for inspecting EXTRACT grid and cell
%   template parameters against the current image stack before running ROI
%   segmentation.
%
%   SYNTAX:
%       extractPlugin = nansen.plugin.imviewer.EXTRACT(imviewerHandle)
%       extractPlugin = nansen.plugin.imviewer.EXTRACT(imviewerHandle, options)
%       extractPlugin = nansen.plugin.imviewer.EXTRACT(imviewerHandle, options, Name, Value, ...)

    properties (Constant)
       Name = 'EXTRACT'
    end

    properties (Access = private)
        hGridLines
        hCellTemplates
        gobjectTransporter
    end

    methods % Structors

        function obj = EXTRACT(imviewerHandle, varargin)
        %EXTRACT Create an EXTRACT plugin for an imviewer app.
        %
        %   extractPlugin = EXTRACT(imviewerHandle)
        %   creates the plugin using default EXTRACT options.
        %
        %   extractPlugin = EXTRACT(imviewerHandle, options, Name, Value, ...)
        %   creates the plugin using a struct or nansen.manage.OptionsManager
        %   for options. Remaining arguments are plugin flags or property-value
        %   pairs, such as '-p' for partial construction.

            arguments
                imviewerHandle applify.AppWithPlugin
            end
            arguments (Repeating)
                varargin
            end

            [options, pluginArgs] = ...
                applify.mixin.HasOptionsManager.splitOptionsArgument(varargin);

            obj@applify.mixin.ModalMethodPreviewController(options)
            obj@imviewer.ImviewerPlugin(imviewerHandle, pluginArgs{:})

            hasRunMethodOnFinishArgument = any(cellfun(@(arg) ...
                (ischar(arg) || (isstring(arg) && isscalar(arg))) && ...
                strcmp(arg, 'RunMethodOnFinish'), pluginArgs));
            if ~hasRunMethodOnFinishArgument
                obj.RunMethodOnFinish = false;
            end

            if ~obj.PartialConstruction
                obj.openControlPanel()
            end

            if ~nargout
                clear obj
            end
        end

        function delete(obj)
            delete(obj.hGridLines)
            delete(obj.hCellTemplates)
            delete(obj.gobjectTransporter)
        end
    end

    methods (Access = {?applify.mixin.AppPlugin, ?applify.AppWithPlugin} )

        function tf = keyPressHandler(obj, src, evt) %#ok<INUSD>
            tf = false;
            % Todo?
        end
    end

    methods

        function openControlPanel(obj, mode)
            obj.plotGrid()
            obj.editOptions()
        end

        function optionsEditor = openOptionsEditor(obj)
        %openOptionsEditor Open editor for method options.
            optionsEditor = openOptionsEditor@applify.mixin.ModalMethodPreviewController(obj);
            obj.arrangeAppWindows(optionsEditor)
        end

        function run(~)
        %run Run EXTRACT segmentation.
            error('nansen:plugin:imviewer:EXTRACT:RunNotImplemented', ...
                'EXTRACT does not implement run yet.')
        end

        function changeOption(obj, name, value)
            obj.onOptionsChanged(name, value)
        end

        function showTip(obj, message)

            msgTime = max([1.5, numel(message)./30]);
            obj.PrimaryApp.displayMessage(message, [], msgTime)
        end
    end

    methods (Access = protected)

        function onPluginActivated(obj)
            onPluginActivated@imviewer.ImviewerPlugin(obj)
            % Placeholder in case specialized operations need to run here
        end

        function onOptionsChanged(obj, name, value)

            switch name
                case {'num_partitions_x', 'num_partitions_y'}
                    obj.Options.Main.(name) = value;
                    obj.plotGrid()

                    obj.checkGridSize()

                case 'use_gpu'
                    obj.Options.Main.(name) = value;
                    if value && ismac
                        obj.showTip('Note: GPU acceleration with Parallel Computing Toolbox is not supported on macOS versions 10.14 (Mojave) and above. Support for earlier macOS versions will be removed in a future MATLAB release.')
                    end

                case 'avg_cell_radius'
                    obj.Options.Main.(name) = value;
                    obj.plotCellTemplates(value)

                case 'temporal_denoising'
                    obj.Options.Preprocess.(name) = value;
                    if value
                        obj.showTip('Note: This might increase processing time considerably for long movies')
                    end

                case 'reestimate_S_if_downsampled'
                    obj.Options.Downsample.(name) = value;
                    if value
                        obj.showTip('This is not recommended as precise shape of cell images are typically not essential, and processing will take longer')
                    end

                case 'trace_output_option'
                    obj.Options.Main.(name) = value;

                    if strcmp(value, 'raw')
                        obj.showTip('Please check EXTRACT''s FAQ before using this options')
                    end
            end
        end
    end

    methods (Access = private)

        function plotGrid(obj)

            % Delete old grid if it exists
            if ~isempty(obj.hGridLines)
                delete(obj.hGridLines)
            end

            % Plot grid lines
            numRows = obj.Options.Main.num_partitions_y;
            numCols = obj.Options.Main.num_partitions_x;

            hLine = imviewer.plot.plotGridLines(obj.PrimaryApp, numRows, numCols);

            obj.hGridLines = hLine;
            set(obj.hGridLines, 'Color', ones(1,3)*0.5);
            set(obj.hGridLines, 'HitTest', 'off', 'Tag', 'EXTRACT Gridlines');
        end

        function plotCellTemplates(obj, radius)

            % Todo: create a roimap and add a couple of round rois???

            if isempty(radius) || radius == 0
                return
            end

            [X, Y] = uim.shape.circle(radius);

            if isempty(obj.gobjectTransporter)
                obj.gobjectTransporter = applify.gobjectTransporter(obj.Axes);
            end

            % Assign the Ancestor App of the roigroup to the app calling
            % for its creation.

            if ~isempty(obj.hCellTemplates) % Update radius
                x0 = arrayfun(@(h) mean(h.XData), obj.hCellTemplates);
                y0 = arrayfun(@(h) mean(h.YData), obj.hCellTemplates);

                for i = 1:numel(x0)
                    h = obj.hCellTemplates(i);
                    h.XData = x0(i) + X - radius;
                    h.YData = y0(i) + Y - radius;
                end

            else % Initialize plots
                obj.hCellTemplates = gobjects(0);

                n = 25;
                theta = rand(1,n)*(2*pi);
                imRadius = min([obj.PrimaryApp.imWidth, obj.PrimaryApp.imHeight])./2;
                r = sqrt(rand(1,n)) * imRadius;
                [x0, y0] = pol2cart(theta, r);
                x0 = x0+imRadius;
                y0 = y0+imRadius;

                for i = 1:numel(x0)
                    h = patch(obj.Axes, x0(i)+X, y0(i)+Y, 'w', 'FaceAlpha', 0.4);
                    h.ButtonDownFcn = @(s,e) obj.gobjectTransporter.startDrag(h,e);
                    obj.hCellTemplates(i) = h;
                end
            end
        end

        function checkGridSize(obj)

            numRows = obj.Options.Main.num_partitions_y;
            numCols = obj.Options.Main.num_partitions_x;

            sizeX = obj.PrimaryApp.imWidth ./ numRows;
            sizeY = obj.PrimaryApp.imHeight ./ numCols;

            if any([sizeX, sizeY]  < 100)
                message = 'Using a gridsize less than 128 pixels is not advised';
                obj.showTip(message)
            else
                obj.PrimaryApp.clearMessage()
            end
        end
     end
end
