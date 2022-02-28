classdef HDF5 < nansen.stack.data.VirtualArray

    
    % Todo: 
    %  [ ] If data set is not given, return all data sets that contain 3D
    %      arrays
    %  [ ] Make system for combining stack (i.e if channels or planes are
    %      stored in different datasets
    %  [ ] Implement finding datasets which are within groups...
    %  [ ] Subclass (?) for datasets within the NWB format...
    %  [ ] Check nwb-datapipe for inspiration how to use low level h5 functions 

    
properties
    DatasetName = ''
end

properties (Access = private, Hidden)
    h5FileInfo
    DatasetInfoH5
    DatasetFullName = ''
end

methods 
    
    function obj = HDF5(filePath, datasetName, varargin)
       
        % Open folder browser if there are no inputs.
        if nargin < 1; filePath = uigetdir; end
        
        if nargin < 2; datasetName = ''; end
        varargin = [varargin, {'DatasetName', datasetName}];
        
        if isa(filePath, 'char')
            filePath = {filePath};
        end
        
        msg = 'Currently only supports opening of individual files';
        assert(numel(filePath)==1, msg)
        
        % Create a virtual stack object
        obj@nansen.stack.data.VirtualArray(filePath, varargin{:})
        
    end
       
end

methods (Access = protected) % Implementation of abstract methods
        
    function obj = assignFilePath(obj, filePath)
        
        if isa(filePath, 'cell') && numel(filePath)==1
            filePath = filePath{1};
        else
            error('Something went wrong. Check how to specify filepath in class documentation')
        end
        
        [~, ~, ext] = fileparts(filePath);
        
        assert(strcmp(ext, '.h5') || strcmp(ext, '.nwb') , 'File must be a .h5 file')

        obj.FilePath = filePath;
        
        
        if isempty(obj.DatasetName)
            warning('Dataset is not specified, will use the first dataset that looks like an imagestack')
            %datasetNames = obj.listH5Datasets();
            obj = obj.findArrayDatasets();
        end
        
    end
    
    function getFileInfo(obj)
        
        if isempty(obj.h5FileInfo)
            obj.h5FileInfo = h5info(obj.FilePath);
        end
        
        obj.DatasetInfoH5 = h5info(obj.FilePath, ['/', obj.DatasetName] );
        obj.MetaData.Size = obj.DatasetInfoH5.Dataspace.Size;

        obj.MetaData.Class = obj.h5Type2matType(obj.DatasetInfoH5.Datatype);
                
        % TODO
        % Add more meta, specifically numPlanes and numChannels 
        
        
        obj.assignDataSize()
        
        obj.assignDataType()
        
    end
    
    function createMemoryMap(obj)
        
    end
    
    function assignDataSize(obj)
        obj.DataSize = obj.MetaData.Size;
    end
    
    function assignDataType(obj)
        obj.DataType = obj.MetaData.Class;
    end
    
end

methods % Implementation of abstract methods

    
    function data = readData(obj, subs)
        
        [start, count, stride] = obj.subs2h5ReadKeys(subs, size(obj));

        if isa(start, 'cell')
            data = cell(1, numel(start));
            
            for i = 1:numel(start)
                data{i} = h5read(obj.FilePath, ['/', obj.DatasetName], start{i}, count{i}, stride{i});
            end    
            data = cat(numel(subs), data{:});
            
        else
            data = h5read(obj.FilePath, ['/', obj.DatasetName], start, count, stride);
        end

    end
    
    function data = readFrames(obj, frameInd)
        % Not implemented, can read data directly from h5 file using 
        % readData method 
    end
    
    function writeFrames(obj, data, frameInd)
        % Not implemented
    end
    
    function data = getFrame(obj, frameInd, subs)
        data = obj.getFrameSet(frameInd, subs);
    end
    
    function data = getFrameSet(obj, frameInd, subs)
        % Todo...
        
        warning('Call readdata instead')

        if nargin < 3
            subs = repmat({':'}, 1, ndims(obj));
            subs{end} = frameInd;
            %subs = obj.frameind2subs(frameInd); % Todo...
        end
        
        [start, count, stride] = obj.subs2h5ReadKeys(subs, size(obj));
        
        data = h5read(obj.FilePath, ['/', obj.DatasetName], start, count, stride);
        
    end
    
    function writeFrameSet(obj, data, frameInd, subs)
        % Todo: Can I make order of arguments equivalent to upstream
        % functions?
        
        if nargin < 4
            subs = obj.frameind2subs(frameInd);
        end
        
        [start, count, stride] = obj.subs2h5ReadKeys(subs, size(obj));
        
        %Todo: Add proper credit: Lettencenter:neobegonia
        data = reshape(data,count);

        warning off
        h5write(obj.FilePath, ['/', obj.DatasetName], data, start, count, stride)
        warning on
        
    end
    
end

methods % Methods for finding datasets within h5 file
    
    function obj = findArrayDatasets(obj)
        
        fileInfo = h5info(obj.FilePath);
        obj.h5FileInfo = fileInfo;
        
        datasets = fileInfo.Datasets;
        numDatasets = numel(datasets);

        isDatasetArray = false(1, numDatasets);
        
        for i = 1:numDatasets
            isDatasetArray(i) = numel(datasets(1).Dataspace.Size) >= 3;
        end
        
        % Todo: Only continue with datasets that contain 3D or higherD array
        arrayDatasets = fileInfo(isDatasetArray).Datasets;
        numDatasets = numel(datasets);
        
        for i = 1%:numDatasets
            obj.DatasetName = arrayDatasets(i).Name;
        end

    end
    
    function datasetNames = listH5Datasets(obj, groupName)
    
        if nargin < 2 || isempty(groupName)
            groupName = '';
        end
        
        datasetNames = {};
        
        if isempty(groupName)
            info = h5info(obj.FilePath);
        else
            info = h5info(obj.FilePath, groupName);
        end
        
        for iGroup = 1:numel(info.Groups)
            newNames = obj.listH5Datasets(info.Groups(iGroup).Name);
            datasetNames = [datasetNames, newNames];
        end
        
        
        if ~isempty(info.Datasets)
            newNames = strcat(groupName, '/', {info.Datasets.Name});
            datasetNames = [datasetNames, newNames];
        end
        
    end
    
end

methods (Static) % H5 specific methods
    
    function dataType = h5Type2matType(S)
        
        switch(S.Type)
            case { 'H5T_STD_U64LE', 'H5T_STD_U64BE', ...
                   'H5T_STD_U32LE', 'H5T_STD_U32BE', ...
                   'H5T_STD_U16LE', 'H5T_STD_U16BE', ...
                   'H5T_STD_U8LE',  'H5T_STD_U8BE' }
                dataType = sprintf('uint%d', S.Size*8);

            case { 'H5T_STD_I64LE', 'H5T_STD_I64BE', ...
                   'H5T_STD_I32LE', 'H5T_STD_I32BE', ...
                   'H5T_STD_I16LE', 'H5T_STD_I16BE', ...
                   'H5T_STD_I8LE',  'H5T_STD_I8BE' }
                dataType = sprintf('int%d', S.Size*8);

            case { 'H5T_IEEE_F32BE', 'H5T_IEEE_F32LE' }
                dataType = 'single';
        
            case { 'H5T_IEEE_F64BE', 'H5T_IEEE_F64LE' }
                dataType = 'double';
                
            otherwise
                fprintf('%s\n', datatype.Type);
        
        end
        
    end
    
    function [start, count, stride] = subs2h5ReadKeys(subs, sz)
        
        % Todo: Give proper Credit: neobegonia package, LettenCenter
        
        % Find start, count and stride for reading H5.
        [start, count, stride] = deal( ones(1, numel(sz)) );

        for i = 1:numel(subs)
            if subs{i} == ':'
                % Write the whole dimension.
                start(i) = 1;
                count(i) = sz(i);
                stride(i) = 1;
            else
                % Input is a list of indices. 
                I = subs{i};

                if islogical(I)
                    I = find(I);
                end

                % Check if the selection can be defined with a single
                % stride value.
                if length(I) > 1
                    strides = unique(diff(I));
                    if length(strides) > 1 && i == numel(subs)
                        
                        [start, count, stride] = nansen.stack.virtual.HDF5.subs2h5ReadKeysMultiStride(subs, sz);
                        return
                        
                        %id = 'NANSEN:VirtualH5:IrregularStrideOnLastIndex';
                        %msg = 'Selection cannot be defined with a single stride value. Consider indexing multiple times.';
                        %throw( MException(id, msg) );
                    elseif length(strides) > 1 && i ~= numel(subs)
                        id = 'NANSEN:VirtualH5:IrregularStrideOnIndexing';
                        msg = 'Selection cannot be defined with a single stride value. Consider indexing multiple times.';
                        throw( MException(id, msg) );
                    else
                        stride(i) = strides;
                    end
                else
                    stride(i) = 1;
                end

                start(i) = I(1);
                count(i) = length(I);
            end
        end

    end
    
    function [start, count, stride] = subs2h5ReadKeysMultiStride(subs, sz)
        
        
        subsLastDim = subs{end};
                
        segments = {};
        count = 1;
        
        finished = false;
        while ~finished
        
            strideTransition = find(diff(subsLastDim, 2) ~= 0, 1, 'first') + 1;
            if isempty(strideTransition)
                strideTransition = numel(subsLastDim);
            end
            segments{count} = subsLastDim(1:strideTransition);
            
            subsLastDim(1:strideTransition) = [];
            count = count+1;
            
            if isempty(subsLastDim)
                finished = true;
            end
        end
        
        [start, count, stride] = deal({});
        
        tmpSubs = subs;
        for i = 1:numel(segments)
            tmpSubs{end} = segments{i};
            [start{i}, count{i}, stride{i}] = nansen.stack.virtual.HDF5.subs2h5ReadKeys(tmpSubs, sz);
        end
        
    end
    
    function initializeFile(filePath, arraySize, arrayClass)
        % Todo
    end
    
end 

end