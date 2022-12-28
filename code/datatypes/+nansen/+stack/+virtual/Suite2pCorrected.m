classdef Suite2pCorrected < nansen.stack.virtual.TiffMultiPart
    
    properties (Constant, Hidden)
        FilenameExpression = 'plane.*reg_tif.*file\d{3}_chan\d{1}'
        DATA_DIMENSION_ARRANGEMENT = 'YXTZC';
    end
    
    properties (Access = private)
        NumChannels_
        NumPlanes_
    end
    
    methods % Structors
    
        function obj = Suite2pCorrected(filePath, varargin)
            import('nansen.stack.virtual.Suite2pCorrected')
            filePath = Suite2pCorrected.lookForMultipartFiles(filePath);

            obj@nansen.stack.virtual.TiffMultiPart(filePath, varargin{:})
        end
        
    end
    
    methods (Access = protected)
        
        function numChannels = detectNumberOfChannels(obj)
            
            % Check if there is a channel expression if there are more than 
            % one file
            if numel(obj.FilePathList) > 1
                
                % expression for capturing channel and part numbers as tokens
                expression = 'plane(?<plane>\d{1}).*chan(?<channel>\d{1})';
                
                tokens = regexp( obj.FilePathList, expression, 'names');
                tokens = cat(1, tokens{:});
                
                % Get list of channel and plane numbers for each file part
                channelIdx = cellfun(@(c) str2double(c), {tokens.channel});
                planeIdx = cellfun(@(c) str2double(c), {tokens.plane});

                % Count number of unique channels and planes
                numChannels = numel( unique(channelIdx) );
                numPlanes = numel( unique(planeIdx) );
                
                if numChannels > 1
                    obj.ChannelMode = 'multipart';
                end

                % Rearrange list of files that first dimension holds the
                % "unique" parts and second dimension holds successive
                % channels and planes

                numParts = numel( obj.FilePathList );
                numPartsPerLength = floor(numParts / numChannels / numPlanes);

                obj.FilePathList = reshape(obj.FilePathList, ...
                    numPartsPerLength, numChannels*numPlanes);
                obj.tiffObj = reshape(obj.tiffObj, ...
                    numPartsPerLength, numChannels*numPlanes);
                
                obj.NumPlanes_ = numPlanes;
                obj.NumChannels_ = numChannels;

            end
        end
        
        function numPlanes = detectNumberOfPlanes(obj)
            numPlanes = obj.NumPlanes_;
        end
    end
    
    methods (Static)
        
        function filepath = lookForMultipartFiles(filepath)

            if ischar(filepath) || (iscell(filepath) && numel(filepath)==1)
                if iscell(filepath)
                    [folder, ~, ext] = fileparts(filepath{1});
                else
                    [folder, ~, ext] = fileparts(filepath);
                end
                
                rootDir = utility.path.getAncestorDir(folder, 2);
                
                allFolders = utility.path.listSubDir(rootDir, '', {}, 1);
                keep = contains(allFolders, 'reg_tif');
                allFolders = allFolders(keep);
                
                %L = dir(fullfile(folder, ['*', ext]));
                filenames = utility.path.listFiles(allFolders, '.tif');

                % If many files are found and all filenames are same length
                if numel(filenames) > 1 && numel( unique(cellfun(@numel, filenames)) ) == 1
                    filepath = fullfile(filenames);
                end
            end

        end
        
    end
    
    
    
end

