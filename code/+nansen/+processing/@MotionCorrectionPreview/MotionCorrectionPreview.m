classdef MotionCorrectionPreview < handle
%MotionCorrectionPreview Contains methods that are common for motion 
% correction imviewer plugins

% Todo: Should this inherit from imviewer.ImviewerPlugin and have
% nansen.plugin.imviewer.FlowRegistration and 
% nansen.plugin.imviewer.NoRMCorre as subclasses?

    properties (Abstract) 
        settings
        ImviewerObj
    end
    
    properties (Abstract, Hidden)
        TargetFolderName
    end

    properties (Access = private)
        DefaultOptions = nansen.processing.MotionCorrection.getDefaultOptions();
    end
    
    methods (Access = protected)
        
        function onSettingsChanged(obj, name, value)
        %onSettingsChanged Update value in settings if value changes.    
            
            % Deal with specific fields
            switch name
                case 'run'
                    obj.runTestAlign()
                case 'BidirectionalCorrection'
                    if strcmp(value, 'Time Dependent') || strcmp(value, 'Continuous')
                        msgbox('This is not implemented yet, constant bidirectional correction will be used')
                    end
                case 'OutputFormat'
                    oldFilename = obj.settings.Export.FileName;
                    newFilename = obj.buildFilenameWithExtension(oldFilename);
                    obj.settings.Export.FileName = newFilename; 
            end

            defaultFields = fieldnames(obj.DefaultOptions);
            for i = 1:numel(defaultFields)
                subFields = fieldnames( obj.DefaultOptions.(defaultFields{i}) );
                
                if any(strcmp(subFields, name))
                    obj.settings.(defaultFields{i}).(name) = value;
                end
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
        
        function fileName = buildFilenameWithExtension(obj, fileName)

            % Strip current filename of all extensions.
            fileName = strsplit(fileName, '.'); % For file with multiple extentsions, i.e .ome.tif
            
            switch obj.settings.Export.OutputFormat
                case 'Binary'
                    fileName = sprintf('%s.raw', fileName{1});
                case 'Tiff'
                    fileName = sprintf('%s.tif', fileName{1});
                otherwise
                    error('Unknown output format')
            end
        end

        function dataSet = prepareTargetDataset(obj)
            
            folderPath = obj.settings.Export.SaveDirectory;
            %folderPath = fileparts( obj.ImviewerObj.ImageStack.FileName );
            %folderPath = fullfile(folderPath, 'motion_correction_flowreg');
            if ~isfolder(folderPath); mkdir(folderPath); end

            [~, datasetID] = fileparts(obj.settings.Export.FileName);
            
            dataSet = nansen.dataio.dataset.SingleFolderDataSet(folderPath, ...
                'DataSetID', datasetID );
            
            dataSet.addVariable('TwoPhotonSeries_Original', ...
                'Data', obj.ImviewerObj.ImageStack)
            

            dataSet.addVariable('TwoPhotonSeries_Corrected', ...
                'FilePath', obj.settings.Export.FileName, ...
                'Subfolder', 'motion_corrected');
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
                       
            import nansen.wrapper.normcorre.utility.apply_bidirectional_offset

            imArray = [];
                        
            % Get frame interval from settings
            firstFrame = obj.settings.Preview.firstFrame;            
            lastFrame = (firstFrame-1) + obj.settings.Preview.numFrames;
            
            % Make sure we dont grab more than is available.
            firstFrame = max([1, firstFrame]);
            firstFrame = min(firstFrame, obj.ImviewerObj.ImageStack.NumTimepoints);
            lastFrame = min(lastFrame, obj.ImviewerObj.ImageStack.NumTimepoints);
            
            if lastFrame-firstFrame < 1
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

% %             if mod( size(imArray,1), 2 ) ~= 0
% %                 
% %             end

            if ~strcmp( obj.settings.Preprocessing.BidirectionalCorrection, 'None')
                if ndims(imArray) == 4
                    imArrayMean = squeeze( mean(imArray, 3) );
                    colShift = correct_bidirectional_offset(imArrayMean, size(imArray,4), 10);
    
                    for i = 1:size(imArray, 3)
                        imArray(:,:,i,:) = apply_bidirectional_offset(imArray(:, :, i, :), colShift);
                    end
                    
                elseif ndims(imArray) == 3
                    [~, imArray] = correct_bidirectional_offset(imArray, size(imArray,3), 10);
                end
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
        
            dim = ndims(M);
        
            imAvg = mean(M, dim);
            imMax = max(M, [], dim);
            imAvg = stack.makeuint8(imAvg);
            imMax = stack.makeuint8(imMax);
            imwrite(imAvg, getSavepath('avg_projection.tif'))
            imwrite(imMax, getSavepath('max_projection.tif'))
            
            imAvg = mean(Y, dim);
            imMax = max(Y, [], dim);
            imAvg = stack.makeuint8(imAvg);
            imMax = stack.makeuint8(imMax);
            imwrite(imAvg, getSavepath('avg_projection_raw.tif'))
            imwrite(imMax, getSavepath('max_projection_raw.tif'))
            
            
        end
    end
    
end