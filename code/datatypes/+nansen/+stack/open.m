function virtualData = open(pathStr, varargin)
%imviewer.stack.open Open imageStack from file using a suitable FileAdapter
%
%   

    [nvPairs, varargin] = utility.getnvpairs(varargin{:});

    % Initialize output
    % virtualData = [];

    % pathStr can be both a cell array (a list of pathStr) or a char/string
    % with a single path. If latter is the case, put it in a cell array,
    % because the rest of the function assumes the variable is a list of
    % pathStrings.
    
    if isstring(pathStr); pathStr = char(pathStr); end
    if ~isa(pathStr, 'cell'); pathStr = {pathStr}; end
    
    numFiles = numel(pathStr);
    [folder, filename, fileext] = fileparts(pathStr{1});
    

    assert(all(contains(pathStr, fileext)), 'All files must be the same')
    

    % Todo: Add a call to a function that checks whether data should be
    % loaded using a custom FileAdapter class.
    virtualData = openUsingCustomFileAdapter(pathStr, nvPairs{:});
    if ~isempty(virtualData)
        return
    end

    switch lower(fileext)
        
        case {'.tif', '.tiff'}
            
            if isfile(pathStr{1})
                % No idea if this is important, but everything looks fine
                warning('off', 'imageio:tiffmexutils:libtiffWarning')
                imInfo = Tiff(pathStr{1});
                warning('on', 'imageio:tiffmexutils:libtiffWarning')
            else
                imInfo = struct;
            end
            
            virtualData = [];
            
            % Should file be opened using the custom ScanImageTiff adapter?
            try
                softwareName = imInfo.getTag('Software');
                if strcmp(softwareName(1:2), 'SI')
                    isMultiFov = nansen.stack.virtual.ScanImageTiff.checkIfMultiRoi(imInfo);
                    if isMultiFov
                        ophys.twophoton.ScanImageMultiRoi2PSeries(pathStr).view()
                    else
                        virtualData = nansen.stack.virtual.ScanImageTiff(pathStr, varargin{:}, nvPairs{:});
                    end
                elseif contains(softwareName, 'Prairie View')
                    virtualData = nansen.stack.virtual.PrairieViewTiffs(pathStr, varargin{:}, nvPairs{:});
                end
            catch
                % Do nothing.
            end

            % Fall back to opening tiffs using a generic tiff-file adapter
            if isempty(virtualData)
                if numFiles > 1
                    virtualData = nansen.stack.virtual.TiffMultiPart(pathStr, varargin{:}, nvPairs{:});
                else
                    %try TODO
                    %    virtualData = nansen.stack.virtual.Tiff(pathStr, varargin{:}, nvPairs{:});
                    %catch
                        virtualData = nansen.stack.virtual.TiffMultiPart(pathStr, varargin{:}, nvPairs{:});
                    %end
                end
            end
            
        case '.h5'
            virtualData = nansen.stack.virtual.HDF5(pathStr, '', varargin{:}, nvPairs{:});
            
        case '.mdf'
            virtualData = nansen.stack.virtual.MDF(pathStr, nvPairs{:});

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
            
        case {'.raw','.ini'}
            
            if nansen.stack.virtual.SciScanRaw.fileCheck(pathStr)
                virtualData = nansen.stack.virtual.SciScanRaw(pathStr, nvPairs{:});
            else
                virtualData = nansen.stack.virtual.Binary(pathStr, varargin{:}, nvPairs{:});
            end
            
        case {'.avi', '.mov', '.mpg', '.mp4'}
            virtualData = nansen.stack.virtual.Video(pathStr, nvPairs);

        case {'.tsm'}
            virtualData = nansen.stack.virtual.TSM(pathStr, nvPairs);
            
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


function virtualData = openUsingCustomFileAdapter(filePath, varargin)
%openUsingCustomFileAdapter Get virtual data using file adapter based on name    
    import nansen.dataio.fileadapter.imagestack.ImageStack
    
    if iscell(filePath); filePath = filePath{1}; end
    
    virtualDataClass = ImageStack.getVirtualDataClassNameFromFilename(filePath);
    
    if ~isempty(virtualDataClass)
        virtualDataClassFcn = str2func(virtualDataClass);
        virtualData = virtualDataClassFcn(filePath, varargin{:});
    else
        virtualData = [];
    end
end


% NEW VERSION (tbd):

% % virtualData = virtualStack(pathStr, varargin{:});
% % 
% % obj = nansen.stack.ImageStack(virtualData);
% % 
% % % This should be done within the imagestack constructor
% % obj.filePath = pathStr{1};
