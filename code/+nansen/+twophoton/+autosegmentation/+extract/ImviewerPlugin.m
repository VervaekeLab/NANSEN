classdef ImviewerPlugin < imviewer.ImviewerPlugin
        
    
    properties (Constant, Hidden = true)
        USE_DEFAULT_SETTINGS = false        % Ignore settings file
        DEFAULT_SETTINGS = []
    end
    
    properties (Constant)
       Name = 'EXTRACT' 
    end
    
    properties
        hGridLines
        hCellTemplates
        gobjectTransporter
        %settings
    end
        
    
    methods
        function delete(obj)
            delete(obj.hGridLines)
            delete(obj.hCellTemplates)
            delete(obj.gobjectTransporter)
        end
    end
    
    
    methods
        function tf = onKeyPress(src, evt) % todo: rename to onKeyPressed
                        
        end
        
        %onMousePressed(src, evt)

    end
    
    methods (Access = protected)
        function onPluginActivated(obj)
            
        end
        
                
        function onSettingsChanged(obj, name, value)
            
            
            switch name
                case {'num_partitions_x', 'num_partitions_y'}
                    obj.settings.Main.(name) = value;
                    obj.plotGrid()
                    
                    obj.checkGridSize()
                    
                case 'use_gpu'
                    obj.settings.Main.(name) = value;
                    if value && ismac
                        obj.showTip('Note: GPU acceleration with Parallel Computing Toolbox is not supported on macOS versions 10.14 (Mojave) and above. Support for earlier macOS versions will be removed in a future MATLAB release.')
                    end
                    
                case 'avg_cell_radius'
                    obj.settings.Main.(name) = value;
                    obj.plotCellTemplates(value)
                    
                case 'temporal_denoising'
                    obj.settings.Preprocess.(name) = value;
                    if value
                        obj.showTip('Note: This might increase processing time considerably for long movies')
                    end
                    
                case 'reestimate_S_if_downsampled'
                    obj.settings.Downsample.(name) = value;
                    if value
                        obj.showTip('This is not recommended as precise shape of cell images are typically not essential, and processing will take longer')
                    end
                    
                case 'trace_output_option'
                    obj.settings.Main.(name) = value;
                    
                    if strcmp(value, 'raw')
                        obj.showTip('Please check EXTRACT''s FAQ before using this options')
                    end
                    
            end
            
        end
        
    end
    
    methods (Static) % Inherited... 
        function getPluginIcon()
            
        end
    end
    
    
    methods
        
        function changeSetting(obj, name, value)
            obj.onSettingsChanged(name, value)
        end

        function showTip(obj, message)
            
            msgTime = max([1.5, numel(message)./30]);
            obj.PrimaryApp.displayMessage(message, [], msgTime)

        end
         
        function plotGrid(obj)
            
            xLim = [1,obj.PrimaryApp.imWidth];
            yLim = [1,obj.PrimaryApp.imHeight];
            
            numRows = obj.settings.Main.num_partitions_y;
            numCols = obj.settings.Main.num_partitions_x;
            
            xPoints = linspace(xLim(1),xLim(2), numCols+1);
            yPoints = linspace(yLim(1),yLim(2), numRows+1);
            
            xPoints = xPoints(2:end-1);
            yPoints = yPoints(2:end-1);

            xDataVert = cat(1, xPoints, xPoints);
            yDataVert = [repmat(yLim(1), 1, numCols-1); repmat(yLim(2), 1, numCols-1)];
            xDataHorz = [repmat(xLim(1), 1, numRows-1); repmat(xLim(2), 1, numRows-1)];
            yDataHorz = cat(1, yPoints, yPoints);
            
            if ~isempty(obj.hGridLines)
                delete(obj.hGridLines)
            end
            
            h = plot(obj.Axes, xDataVert, yDataVert, xDataHorz, yDataHorz);
            obj.hGridLines = h;
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
                        
            numRows = obj.settings.Main.num_partitions_y;
            numCols = obj.settings.Main.num_partitions_x;
            
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