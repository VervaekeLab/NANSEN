classdef FileConcatenator < handle
    
    % Todo: Collect methods from adapters into this class. E.g in
    % prairietiff, files are sorted.. In Image, there is one file per
    % frame.. MultiPartTiff can have some of its methods replaces by this
    % class... suite2p gets files from different folders...
    
    properties
        FilePath
        NumFramesPerFile
    end
    
    properties (Dependent)
        NumFiles
    end
    
    properties (Access = private)
        FilePathList = {}   % Keep list of all filepaths if multiple files are open.
        FrameIndexInfo
    end
    
    methods
        
        function obj = FileConcatenator(filePathList)
            obj.FilePathList = filePathList;
        end
        
        function [fileNum, frameNumInFile] = getFrameFileInd(obj, frameNum)
            fileNum = obj.FrameIndexInfo.fileNum(frameNum);
            frameNumInFile = obj.FrameIndexInfo.frameInFile(frameNum);
        end
    end
    
    methods
        
        function numFiles = get.NumFiles(obj)
            numFiles = numel(obj.FilePathList);
        end
        
        function set.NumFramesPerFile(obj, value)
            obj.NumFramesPerFile = value;
            obj.createFrameIndexMap();
        end
    end

    methods (Access = private)
        
        function createFrameIndexMap(obj)
        %createFrameIndexMap Create a mapping from frame number to file part
            
            assert( numel( obj.NumFramesPerFile ) == obj.NumFiles, ...
                'Number of files and number of frames per file does not match')
            
            obj.FrameIndexInfo = ...
                struct('frameNum', [], 'fileNum', [], 'frameInFile', []);

            count = 0;

            for i = 1:numel(obj.FilePathList)

                n = obj.NumFramesPerFile(i);
                currentInd = count + (1:n);

                obj.FrameIndexInfo.frameNum(currentInd) = currentInd; % Not really needed.
                obj.FrameIndexInfo.fileNum(currentInd) = i;
                obj.FrameIndexInfo.frameInFile(currentInd) = 1:n;

                count = count + n;
            end
        end
    end
        
    methods (Static)
        
        function filepath = lookForMultipartFiles(filepath, level)
        %
        %
        %   filepath = lookForMultipartFiles(filepath, level) returns
        %
        %   level can have three values:
        %       0: Don't get any other files
        %       1: Get all files with same file extension
        %       2: Get all files with same filename length
        %       3: Get all files with same filename length, where only
        %          numbers are differing (default)
       
            if nargin < 2; level = 3; end
            
            if ~iscell(filepath); filepath = {filepath}; end
            
            if level == 0; return; end
            
            if ischar(filepath) || (iscell(filepath) && numel(filepath)==1)
                    
                [folder, filename, ext] = fileparts(filepath{1});
                
                % List files in folder with same extension as reference
                L = dir(fullfile(folder, ['*', ext]));
                
                % Remove "shadow" files
                keep = ~ strncmp({L.name}, '.', 1);
                L = L(keep);
                
                if numel(L) == 1
                    return
                end
                
                referenceName = strcat(filename, ext);
                
                if level == 1
                    filepath = fullfile({L.folder}, {L.name});
                    
                elseif level == 2
                    % Count length of filenames
                    filenameLength = cellfun(@numel, {L.name});
                    
                    keep = filenameLength == numel( referenceName );
                    filepath = fullfile({L(keep).folder}, {L(keep).name});
                    
                elseif level == 3
                    % Remove all numbers from filenames. If all names are
                    % identical after, we assume folder contains multipart files.
                    referenceAlphabetic = regexprep(referenceName, '\d*', '');
                    fileNamesAlphabetic = regexprep({L.name}, '\d*', '');
                    
                    keep = strcmp(fileNamesAlphabetic, referenceAlphabetic);
                    filepath = fullfile({L(keep).folder}, {L(keep).name});
                end
            end
            
            if iscell(filepath) && isrow(filepath)
                filepath = transpose(filepath);
            end
        end
    end
end
