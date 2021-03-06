classdef MDF < nansen.stack.data.VirtualArray
% A class that creates a virtual array for an MDF file. 
%
%
%   Created from the MDF_file_reader @ flow_registration by Philipp Flotho
%       https://github.com/phflot/flow_registration

    
    properties (Constant, Hidden)
        FILE_PERMISSION = 'read'
    end

    properties (Access = private, Hidden)
        mfile  % MDF File object
        ChannelInd
    end
    
    
    methods % Structors
        
        function obj = MDF(filePath, varargin)
        %MDF Create an MDF virtual array object
            obj@nansen.stack.data.VirtualArray(filePath, varargin{:})
        end
        
        function delete(obj)
            if ~isempty(obj.mfile)
                delete(obj.mfile)
            end
        end

    end

    methods (Access = protected) % Implementation of abstract methods
            
        function assignFilePath(obj, filePath, ~)

            if isa(filePath, 'cell')
                if ischar( filePath{1} )
                    obj.FilePath = filePath{1};
                end
                
            elseif isa(filePath, 'char') || isa(filePath, 'string')
                obj.FilePath = char(filePath);
                
            else
                error('Invalid input')
            end

            % Open MCSX File Object
            obj.mfile = actxserver('MCSX.Data',[0 0 0 0]);
            status = obj.mfile.invoke('OpenMCSFile', obj.FilePath);

            if status
                error('Only one MDF file instance can be opened at once! E.g. close the MDF Viewer and clear the Matlab workspace.');
            end
    
        end
        
        function getFileInfo(obj)
            
            mdfParams = obj.getScanParameters();
            obj.assignScanParametersToMetadata(mdfParams)
            
            obj.ChannelInd = mdfParams.ChannelInd;
    
            obj.assignDataSize()
            
            obj.assignDataType()
    
        end
        
        function createMemoryMap(obj)
            % Skip
        end
        
        function assignDataSize(obj)
            dataSize(1) = obj.MetaData.SizeY;
            dataSize(2) = obj.MetaData.SizeX;
            dataSize(3) = obj.MetaData.SizeC;
            dataSize(4) = obj.MetaData.SizeZ;
            dataSize(5) = obj.MetaData.SizeT;

            obj.resolveDataSizeAndDimensionArrangement(dataSize)
        end
        
        function assignDataType(obj)
            obj.DataType = obj.MetaData.Class;
        end
        
    end

    methods

        function data = readFrames(obj, frameInd)
            
            numFrames = length(frameInd);
            
            if obj.MetaData.SizeT > 1 && obj.MetaData.SizeZ > 1
                error('Not implemented for multiplane time series stack. Please report')
            end
            
            dataSize = [obj.MetaData.SizeY, obj.MetaData.SizeX, obj.MetaData.SizeC];
            
            if obj.MetaData.SizeT > 1
                dataSize = [dataSize, obj.MetaData.SizeT];
            elseif obj.MetaData.SizeZ > 1
                dataSize = [dataSize, obj.MetaData.SizeZ];
            else
                dataSize = [dataSize, 1];
            end
            
            data = zeros(dataSize, obj.DataType);
            
            for i = 1:numFrames             
                for j = 1:obj.MetaData.SizeC
                    data(:, :, j, i) = cast(...
                        obj.mfile.ReadFrame(obj.ChannelInd(j), frameInd(i)), ...
                        obj.DataType)';
                end
            end
        end

        function writeFrames(obj, frameIndex, data)
            error('Writing frames to an MDF (MScan) file is not supported')
        end

    end


    methods (Access = private)
           
        function resolveDataSizeAndDimensionArrangement(obj, stackSize)
            % Todo: Remove when this is merged into main branch from
            % dev-imagestack-5d

            % Find singleton dimensions.
            isSingleton = stackSize == 1;

            % Get arrangement of dimensions of data
            try
                % Note subclasses might implement this as a constant
                % property. If it's not implemented, use default DDA
                dataDimensionArrangement = obj.DATA_DIMENSION_ARRANGEMENT;
            catch
                dataDimensionArrangement = obj.DEFAULT_DIMENSION_ARRANGEMENT;
            end

            % Get order of dimensions of data
            [~, ~, dimensionOrder] = intersect( obj.DEFAULT_DIMENSION_ARRANGEMENT, ...
                dataDimensionArrangement, 'stable' );

            % Rearrange beased on dimension order
            isSingleton_(dimensionOrder) = isSingleton;
            dataSize(dimensionOrder) = stackSize;

            % Assign size and dimension arrangement for data excluding
            % singleton dimension.
            obj.DataSize = dataSize(~isSingleton_);
            obj.DataDimensionArrangement = dataDimensionArrangement(~isSingleton_);
        end
        
        function mdfParams = getScanParameters(obj)
            mdfParams = ophys.twophoton.mscan.getScanParameters(obj.mfile);
        end
        
        function assignScanParametersToMetadata(obj, mdfParams)
            
            obj.MetaData.Class = mdfParams.DataType;
            obj.MetaData.SizeX = mdfParams.FrameWidth;
            obj.MetaData.SizeY = mdfParams.FrameHeight;

            %obj.MetaData.ImageSize = [];
            obj.MetaData.PhysicalSizeY = mdfParams.MicronsPerPixel;
            obj.MetaData.PhysicalSizeX = mdfParams.MicronsPerPixel;
            
            obj.MetaData.PhysicalSizeYUnit = 'micrometer'; % Todo: Will this always be um?
            obj.MetaData.PhysicalSizeXUnit = 'micrometer'; % Todo: Will this always be um?
            
            obj.MetaData.TimeIncrement = mdfParams.FrameDuration;
            %obj.MetaData.SampleRate = 1 / mdfParams.FrameDuration;
    
            obj.MetaData.SizeC = mdfParams.NumChannels;
            
            % Todo: need to implement 5D stacks if relevant for anyone
            if mdfParams.NumPlanes > 1 && mdfParams.NumPlanes ~= mdfParams.FrameCount
                obj.MetaData.SizeZ = mdfParams.NumPlanes;
            else
                obj.MetaData.SizeZ = 1;
            end
            
            obj.MetaData.SizeT = mdfParams.FrameCount / obj.MetaData.SizeZ;

            if obj.MetaData.SizeZ > 1 && obj.MetaData.SizeT > 1
                warning('Multiplane timeseries scans from MDF has not been tested, and probably does not work as expected. Please report')
            else
            
            end

        end
        
    end

end