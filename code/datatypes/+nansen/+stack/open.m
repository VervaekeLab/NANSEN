function virtualData = open(pathStr, varargin)
%imviewer.stack.open Open imageStack from file using a suitable FileAdapter
%
%   

    [nvPairs, varargin] = utility.getnvpairs(varargin{:});

    % Initialize output variable.
    %obj = [];

    
    % pathStr can be both a cell array (a list of pathStr) or a char/string
    % with a single path. If latter is the case, put it in a cell array,
    % because the rest of the function assumes the variable is a list of
    % pathStrings.
    
    if isstring(pathStr); pathStr = char(pathStr); end
    if ~isa(pathStr, 'cell'); pathStr = {pathStr}; end
    
    numFiles = numel(pathStr);
    
    [folder, filename, fileext] = fileparts(pathStr{1});

% %     S.filePath = folder;
% % 	S.stackname = filename;

    assert(all(contains(pathStr, fileext)), 'All files must be the same')
    
    %virtualData = virtualStack(pathStr, varargin{:});
    
    % Todo: Add a call to a function that checks whether data should be
    % loaded using a custom FileAdapter class.
    virtualData = []; %openCustomFileAdapter(pathStr);
    if ~isempty(virtualData)
        obj = nansen.stack.ImageStack(virtualData);
        return
    end
    
    
    switch lower(fileext)
        
        case {'.tif', '.tiff'}
            
            imInfo = Tiff(pathStr{1});
            virtualData = [];
            
            try
                softwareName = imInfo.getTag('Software');
                if strcmp(softwareName(1:2), 'SI')
                    virtualData = nansen.stack.virtual.ScanImageTiff(pathStr, varargin{:}, nvPairs{:});
                end
            catch
                % Do nothing.
            end
            
            if isempty(virtualData)
                if numel(pathStr) > 1
                    virtualData = nansen.stack.virtual.TiffMultiPart(pathStr, varargin{:}, nvPairs{:});
                else
                    %try
                    %    virtualData = nansen.stack.virtual.Tiff(pathStr, varargin{:}, nvPairs{:});
                    %catch
                        virtualData = nansen.stack.virtual.TiffMultiPart(pathStr, varargin{:}, nvPairs{:});
                    %end
                end
            end
            
            %obj = imviewer.ImageStack(virtualData);

        case '.h5'
            virtualData = nansen.stack.virtual.HDF5(pathStr, '', varargin{:}, nvPairs{:});
            
        case {'.jpg', '.png', '.bmp'}
%             tic
%             if numFiles > 1
%                 
%                 images = cell(numFiles, 1);
%                 for i = 1:numFiles
%                     images{i} = imread(pathStr{i});
%                 end
%                 try
%                     % Assume rgb images.
%                     imArray = cat(4, images{:});
%                 catch
%                     error('Sorry, loading images of different sizes is not supported.')
%                 end
%                 
%             else
%                 imArray = imread(pathStr{1});
%             end
%             toc
            
            virtualData = nansen.stack.virtual.Image(pathStr);
            %obj = nansen.stack.ImageStack(imArray);
            
        case {'.raw','.ini'}
            
            if nansen.stack.virtual.SciScanRaw.fileCheck(pathStr)
                virtualData = nansen.stack.virtual.SciScanRaw(pathStr, nvPairs{:});
            else
                virtualData = nansen.stack.virtual.Binary(pathStr, varargin{:}, nvPairs{:});
            end
            
            %obj = imviewer.ImageStack(virtualData);

        case {'.avi', '.mov', '.mpg', '.mp4'}
            virtualData = nansen.stack.virtual.Video(pathStr, nvPairs);
            %obj = imviewer.ImageStack(virtualData);
            
        otherwise

            if isempty(fileext) && isfolder(folder)
                error('NotImplemented:LoadFolder', ...
                    'Folder loading is not implemented yet')
            elseif ~isempty(fileext)
                error('NotImplemented:FileType', ...
                    'No load definition available for files of type %s', fileext)
            end

    end
    
end




% NEW VERSION:

% % virtualData = virtualStack(pathStr, varargin{:});
% % 
% % obj = imviewer.ImageStack(virtualData);
% % 
% % % This should be done within the imagestack constructor
% % obj.filePath = pathStr{1};




    