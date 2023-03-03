function imageStackData = initializeData(dataReference, varargin)
%imviewer.stack.initialize Initialize an imageStack object from a data reference.    
%     
%   Data Reference can be a file- or folder path or it can be a matlab
%   array.
%
%   INPUTS:
%       dataReference : matrix | array | char | cell array of chars
%           Reference to image data. Different types are allowed:
%           
%           - matrix (n x m) : treated as a grayscale image
%           - array (n x m x 3) : treated as a grayscale image
%           - array (3D / 4D ) : treated as an image stack
%           - char : treated as a path string to a image stack file
%           - cell : treated as a cell array of path string to multiple
%                    image stack file
%   
%   PARAMETERS:


% TODO:
%   [ ] dataReference from clipboard could be a cell array of strings...
%   [ ] Work out what todo if dataReference is a cellarray of pathStrings. 
%       Should open many stack objects or concatenate into one stack
%       object?
% 	[?] Fix so that many can be loaded...


    [nvPairs, varargin] = utility.getnvpairs(varargin{:});
    
    % CASE 0: dataReference is already ImageStackData
    if isa(dataReference, 'nansen.stack.data.abstract.ImageStackData')
        imageStackData = dataReference;
        return
    end
    
    
    % CASE 1: dataReference is empty. First, check if there is a filepath
    % on the clipboard. If not, open filebrowser.
    if isempty(dataReference) && isa(dataReference, 'char')
        dataReference = utility.path.checkClipboard();

        if isempty(dataReference)
            dataReference = nansen.stack.browse();
        else
            fprintf('Opening file found on clipboard: %s\n', ...
                dataReference{1})
        end
    end
    
    % CASE 2: dataReference is an empty double. Create matrix of nans
    if isempty(dataReference) && isa(dataReference, 'double')
        imageStackData = nansen.stack.data.MatlabArray(nan(512,512));
        return
    end
    
    % CASE 3: dataReference is a matlab array
    if isnumeric(dataReference) && ndims(dataReference) >= 2
        imageStackData = nansen.stack.data.MatlabArray(dataReference, nvPairs{:});
        return
    end
    

    % CASE 4: dataReference is a cell array. Confirm that cells are pathstrings
    if isa(dataReference, 'cell')
        isValidPathStr = @(x) ischar(x) && (isfile(x) || isfolder(x));
        isValidCellArray = cellfun(@(x) isValidPathStr(x), dataReference);
        
        msg = 'Cell array must contain strings to files or folders';
        assert(all(isValidCellArray), msg)
    end
    
    
    % CASE 5: dataReference is a character vector. Check if folder
    if isa(dataReference, 'char') || isa(dataReference, 'string')
        if isfolder(dataReference)
            L = dir(dataReference);
            [selectionInd, ~] = listdlg('ListString', {L.name}, ...
                'SelectionMode', 'single', 'ListSize', [250, 300], ...
                'Name', 'Select File to Open');
            if isempty(selectionInd); return; end
            fileName = L(selectionInd).name;
            dataReference = fullfile(dataReference, fileName);
        end
    end
    

    % Finally: Create an  ImageStackData from the dataReference
    
    if isa(dataReference, 'char') || isa(dataReference, 'string')
        dataReference = char(dataReference);
        imageStackData = nansen.stack.open(dataReference, varargin{:}, nvPairs{:});
    elseif isa(dataReference, 'cell')
        imageStackData = nansen.stack.open(dataReference, varargin{:}, nvPairs{:});
    elseif isnumeric(dataReference) || islogical(dataReference)
        imageStackData = nansen.stack.data.MatlabArray(dataReference, nvPairs{:});
    elseif isa(dataReference, 'nansen.stack.data.abstract.ImageStackData')
        imageStackData = dataReference;
    else
        error(['dataReference is not valid. See help for ', ...
            'nansen.stack.ImageStack for description of valid inputs'] )
    end
    
end