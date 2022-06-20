classdef MotionCorrectionPreview < handle
%MotionCorrectionPreview Contains methods that are common for motion 
% correction imviewer plugins

    properties (Abstract) 
        settings
        ImviewerObj
    end

    properties (Access = private)
        DefaultOptions = nansen.processing.MotionCorrection.getDefaultOptions();
    end
    
    methods (Access = protected)
        
        function onSettingsChanged(obj, name, value)
        %onSettingsChanged Update value in settings if value changes.    
            
            defaultFields = fieldnames(obj.DefaultOptions);
            for i = 1:numel(defaultFields)
                subFields = fieldnames( obj.DefaultOptions.(defaultFields{i}) );
                
                if any(strcmp(subFields, name))
                    obj.settings.(defaultFields{i}).(name) = value;
                end
            end
           
            % Deal with specific fields
            switch name
                case 'run'
                    obj.runTestAlign()
            end
        end

        function assertPreviewSettingsValid(obj)
            
            % Check if saveResult or showResults is selected
            if ~obj.settings.Preview.saveResults && ~obj.settings.Preview.showResults
                msg = 'Aborted, because neither "Save Results" nor "Show Results" are selected';
                obj.ImviewerObj.displayMessage(msg);
                return
            end
        end
        
        function folderPath = getExportDirectory(obj)
            folderPath = fileparts(obj.ImviewerObj.ImageStack.FileName);
        end

        function [saveFolder, datePrefix] = prepareSaveFolder(obj)
        %prepareSaveFolder Prepare save folder for saving preview results.
        
            saveFolder = '';
            namePostfix = strcat(lower(obj.Name), '_preview');
            namePostfix = strrep(namePostfix, ' ', '_');
            
            
            datePrefix = datestr(now, 'yyyymmdd_HH_MM_SS');
            folderName = strcat(datePrefix, '_', namePostfix);

            if ~isempty(obj.DataIoModel)
                rootDir = obj.DataIoModel.getTargetFolder();
                saveDir = fullfile(rootDir, 'image_registration');
            else
                rootDir = fileparts( obj.settings.Export.SaveDirectory );
                saveDir = rootDir;
            end

            if ~isfolder(rootDir)
                msg = 'Folder for saving results does not exist. Aborting...';
                obj.ImviewerObj.displayMessage(msg);
                return
            end

            saveFolder = fullfile(saveDir, 'motion_correction_preview', folderName);
            if ~isfolder(saveFolder); mkdir(saveFolder); end
        end
        
        function imArray = loadSelectedFrameSet(obj)
        %loadSelectedFrameSet Load images for frame interval in settings
            
            imArray = [];
                        
            % Get frame interval from settings
            firstFrame = obj.settings.Preview.firstFrame;            
            lastFrame = (firstFrame-1) + obj.settings.Preview.numFrames;
            
            % Make sure we dont grab more than is available.
            firstFrame = max([1, firstFrame]);
            firstFrame = min(firstFrame, obj.ImviewerObj.ImageStack.NumTimepoints);
            lastFrame = min(lastFrame, obj.ImviewerObj.ImageStack.NumTimepoints);
            
            if lastFrame-firstFrame < 2
                errMsg = 'Error: Need at least two frames to run motion correction';
                obj.ImviewerObj.displayMessage(errMsg)
                pause(2)
                obj.ImviewerObj.clearMessage()
                return
            end
            
            obj.ImviewerObj.displayMessage('Loading Data...')

            % Todo: Enable imagestack preprocessing...
                
            imArray = obj.ImviewerObj.ImageStack.getFrameSet(firstFrame:lastFrame);
            imArray = squeeze(imArray);
            
            if obj.settings.Preprocessing.NumFlybackLines ~= 0
                IND = repmat({':'}, 1, ndims(imArray));
                IND{1} = obj.settings.Preprocessing.NumFlybackLines : size(imArray, 1);
                imArray = imArray(IND{:});
            end
            
        end

    end
    
    methods (Static)
        function saveProjections(Y, M, getSavepath)
        %saveProjections(M, getSavepath)    
        %
        %   saveProjections(M, getSavepath) 
        %       M: corrected images
        %       getSavepath : function handle to create absolute filepath.
        
            imAvg = mean(M, 3);
            imMax = max(M, [], 3);
            imAvg = stack.makeuint8(imAvg);
            imMax = stack.makeuint8(imMax);
            imwrite(imAvg, getSavepath('avg_projection.tif'))
            imwrite(imMax, getSavepath('max_projection.tif'))
            
            imAvg = mean(Y, 3);
            imMax = max(Y, [], 3);
            imAvg = stack.makeuint8(imAvg);
            imMax = stack.makeuint8(imMax);
            imwrite(imAvg, getSavepath('avg_projection_raw.tif'))
            imwrite(imMax, getSavepath('max_projection_raw.tif'))
            
            
        end
    end
    
end