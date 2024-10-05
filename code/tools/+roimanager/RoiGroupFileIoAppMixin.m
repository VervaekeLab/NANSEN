classdef RoiGroupFileIoAppMixin < handle
%RoiGroupFileIoAppMixin Class providing an app with a roigroup and methods 
% for loading and saving rois to file.

    properties (Abstract)
        RoiGroup % roimanager.roiGroup % Todo: Add property validation, but need to upgrade roiClassifier.App first.
        roiFilePath
    end
    
    methods (Access = public)
               
        function loadedRoiGroup = loadRois(obj, loadPath)
        %loadRois Load rois from file
            
            lastwarn('')
            
             % Load roi array from selected file path.
            if isfile(loadPath)
                fileObj = nansen.dataio.fileadapter.roi.RoiGroup(loadPath);
                try
                    loadedRoiGroup = fileObj.load();
                    obj.roiFilePath = loadPath;
                catch ME
                    rethrow(ME)
                end
                
            else
                error('File does not exist')
            end           
        end
        
        function wasSaved = saveRois(obj, initPath)
        %saveRois Save rois to file.
            
            doSaveRois = true;
            wasSaved = false;
            
            if nargin < 2; initPath = ''; end
            savePath = obj.getRoiPath(initPath, 'save');
            if isempty(savePath); doSaveRois=false; end
            
            if isfile(savePath) && doSaveRois
                doOverwrite = obj.promptOverwriteRois();
                if ~doOverwrite
                    doSaveRois = false;
                end
            end

            if doSaveRois
                % Save roigroup using roigroup fileadapter
                fileObj = nansen.dataio.fileadapter.roi.RoiGroup(savePath, '-w');
                fileObj.save(obj.RoiGroup);
                
                %Todo....
                saveMsg = sprintf('Rois Saved to %s\n', savePath);
                fprintf('%s', saveMsg) 
                                        
                obj.roiFilePath = savePath;
                
                obj.RoiGroup.markClean()
                wasSaved = true;
            end

            if ~nargout
                clear wasSaved
            end
        end
         
    end

    methods (Access = protected)
       
        function initPath = getRoiInitPath(obj)
        %getRoiInitPath Get path to start uigetfile or uiputfile
            initPath = obj.roiFilePath;
        end
        
        function filePath = getRoiPath(obj, initPath, mode)
        %getRoiPath Get roi path for loading or saing using uidialogs
        
        % Todo: Use roigroup fileadapter...
        
            filePath = '';
            
            if nargin < 2 || isempty(initPath)
                initPath = obj.getRoiInitPath();
                
                if isfile(initPath)
                    [initPath, fileName, ext] = fileparts(initPath);
                end

            end
            
            fileSpec = {   '*.mat', 'Mat Files (*.mat)'; ...
                           '*.npy', 'Numpy Files (*.npy)'; ...
                           '*', 'All Files (*.*)' ...
                            };
            
            switch mode
                case 'load'
                    [filename, filePath, ~] = uigetfile(fileSpec, ...
                        'Load Roi File', initPath, 'MultiSelect', 'on');
                    
                case 'save'
                    if ~isempty(initPath) && isfile(initPath)
                        filePath = initPath; return;

                    elseif exist('fileName', 'var') && ~isempty(fileName)
                        if ~contains(fileName, '_roi')
                            initPath = fullfile(initPath, strcat(fileName, '_rois.mat'));
                        else
                            initPath = fullfile(initPath, [fileName, ext]);
                        end
                    end
                    [filename, filePath, ~] = uiputfile(fileSpec, ...
                        'Save Roi File', initPath);
            end
            
            if isequal(filename, 0) % User pressed cancel
                filePath = '';
            else
                filePath = fullfile(filePath, filename);
            end
        end
        
        function wasAborted = promptSaveRois(obj)
        %promptSaveRois Open dialog prompting to save rois
        
            wasAborted = true;
                        
            if ~isempty(obj.RoiGroup) && any( [obj.RoiGroup.IsDirty] )
            
                message = 'Save changes to rois?';
                title = 'Confirm Exit';

                selection = questdlg(message, title, ...
                    'Yes', 'No', 'Cancel', 'Yes');

                switch selection

                    case 'Yes'
                        obj.saveRois()
                        wasAborted = false;
                    case 'No'
                        wasAborted = false;
                        
                    otherwise
                        % pass
                end
                
            else
                wasAborted = false;
            end
            
        end

        function doOverwrite = promptOverwriteRois(obj)
            
            message = 'File already exists, do you want to overwrite this file?';
            title = 'Confirm Save';

            selection = questdlg(message, title, ...
                'Yes', 'No', 'Cancel', 'Yes');

            switch selection
                case 'Yes'
                    doOverwrite = true;
                otherwise
                    doOverwrite = false;
            end
        end

        function importRois(obj, initPath)
        %importRois Import rois using uidialog
        
            if nargin < 2; initPath = ''; end
            loadPath = obj.getRoiPath(initPath, 'load');
            if isempty(loadPath); return; end
            
            obj.loadRois(loadPath)
        end

    end

end