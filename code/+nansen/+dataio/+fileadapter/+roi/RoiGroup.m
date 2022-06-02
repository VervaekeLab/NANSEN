classdef RoiGroup < nansen.dataio.FileAdapter
    %UNTITLED Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (Constant)
        DataType = 'RoiGroup'
        Description = 'This file contains information about a group of rois';
    end
    
    properties (Dependent)
        RoiFormat
        RoiConverter % Todo.
    end
    
    properties (Access = private)
        RoiFormat_
    end
    
    properties (Constant, Hidden, Access = protected)
        SUPPORTED_FILE_TYPES = {'mat', 'npy'}
    end
    
    
    methods (Access = protected)
        
        function roiGroup = readData(obj, varargin)
            
            if obj.requireConversionToMat()
                matFilename = obj.convertToMatfile();
            else
                matFilename = obj.Filename;
            end
            
            S = load(matFilename);
            if numel(fieldnames(S))==1 && isfield(S, 'data') % converted from python
                data = S.data;
            else
                data = S;
            end

            roiFormat = obj.determineRoiFormat(data);
            
            if strcmp(roiFormat, 'Suite2p') && ~isa(data, 'struct')
                % Suite2p exports to stats and ops, we need both
                data = obj.collectSuite2pOutputs(data);
            end
            
            conversionFcn = obj.getDataConversionFunction(roiFormat);
            [roiArray, classification, stats, images] = conversionFcn(data);
            
            % Todo: Varargin might specify variables...
            
            % Todo: generalize this. % Todo: roigroup...
            if isstruct(images) && ~isempty(images)
                requiredImageFields = {'ActivityWeightedMean'};
                for i = 1:numel(requiredImageFields)
                    if ~isfield(images, requiredImageFields{i})
                        [images(:).(requiredImageFields{i})] = deal([]);
                    end
                end
            end
            
            % Todo.. concatenate with others... % Todo: roigroup...
            roiArray = roiArray.setappdata('roiClassification', classification);
            roiArray = roiArray.setappdata('roiImages', images);
            roiArray = roiArray.setappdata('roiStats', stats);
            
            roiGroupStruct.roiArray = roiArray;
            roiGroupStruct.roiClassification = classification;
            roiGroupStruct.roiStats = stats;
            roiGroupStruct.roiImages = images;

            roiGroup = roimanager.roiGroup(roiGroupStruct);
            roiGroup.markClean()
        end
        
        function writeData(obj, data, varName)
            
            % Todo: convert data to struct and add to S....
            
            % Use superclass method to write to mat...
                          
            if isa(data, 'RoI')
                [rois, images, stats, clsf] = obj.unpackFromRoiArray(data);
            elseif isa(data, 'roimanager.roiGroup')
                [rois, images, stats, clsf] = obj.unpackFromRoiGroup(data);
            elseif obj.isRoigroupStruct(data)
                [rois, images, stats, clsf] = obj.unpackFromStruct(data);
            else
                error('Can not save data as a RoiGroup')
            end
            
            if isa(rois, 'RoI')
                rois = roimanager.utilities.roiarray2struct(rois);
            end
            
            S = struct;
            S.roiArray = rois;
            S.roiImages = images;
            S.roiStats = stats;
            S.roiClassification = clsf;

            % Use superclass method to write to mat...
            obj.writeDataToMat(S);
            
        end
        
    end
    
    methods % Set/get
        
        function roiFormat = get.RoiFormat(obj)
            if isempty(obj.RoiFormat_)
                roiFormat = obj.determineRoiFormat();
            else
                roiFormat = obj.RoiFormat_;
            end
        end
        
        function set.RoiFormat(obj, newValue)
            VALID_FORMATS = {'Nansen', 'Suite2p', 'CaImAn', 'Extract'};
            newValue = validatestring(newValue, VALID_FORMATS);
            obj.RoiFormat_ = newValue;
        end
        
    end
    
    methods (Access = private) % Methods for reading
        
        function tf = requireConversionToMat(obj)
        %requireConversionToMat Check if file must be converted to mat    
            [~, ~, ext] = fileparts(obj.Filename);
            tf = ~strcmp(ext, '.mat');
        end

        function roiFormat = determineRoiFormat(obj, data)
            
            [folderpath, name, ext] = fileparts(obj.Filename);
            
            if ~strcmp(ext, '.mat')
                filepath = fullfile(folderpath, [name, '.mat']);
            else
                filepath = obj.Filename;
            end
            
            if ~strcmp(~ext, '.mat') && ~isfile(filepath)
                error(['File is not converted to matfile. Need a matfile ', ...
                    'to check the roi format'])
            end
            
            if nargin < 2 || ~exist('data', 'var')
                S = load(filepath);
                if numel(fieldnames(S))==1 && isfield(S, 'data')
                    data = S.data; % Assume file was converted from .npy?
                else
                    data = S;
                end
            end
            
            if obj.isNansenRoiFile(filepath, data)
                roiFormat = 'Nansen';
            elseif obj.isSuite2pRoiFile(filepath, data)
                roiFormat = 'Suite2p';
            elseif obj.isVHLabRoiFile(filepath, data)
                roiFormat = 'VHLab';
            elseif obj.isCaimanRoiFile(filepath, data)
                roiFormat = 'CaImAn';
            elseif obj.isExtractRoiFile(filepath, data)
                roiFormat = 'Extract';
            else
                roiFormat = 'Unknown';
            end
            
        end
        
        function conversionFcn = getDataConversionFunction(obj, roiFormat)
            
            switch roiFormat
                case 'Suite2p'
                    conversionFcn = @nansen.wrapper.suite2p.convertRois;
                case 'CaImAn'
                    
                case 'Nansen'
                    conversionFcn = @roimanager.getRoiData;
                case 'Extract'
                    
                case 'VHLab'
                    conversionFcn = @nansen.dataio.dataconvert.roi.vhlab;
                    
                otherwise
                    % Todo:
                    % Get manual 
            end
            
        end
        
        function S = collectSuite2pOutputs(obj, data)
        %collectSuite2pOutputs Collect complimentary variables from suite2p    
            
        % Suite2p exports roidata to multiple files. Try to collect it
        % here using the default output names of suite2p. If files are not
        % fitting this template, it might be necessary to create a custom
        % converter.
        
            S = struct.empty;
            
            suite2pVariableNames = {'stat', 'ops', 'iscell'};
                        
            % Check that filename is a suite2p output
            message = sprintf('Filename %s is not reckognized as a suite2p file', obj.Name);
            assert(ismember(obj.Name, suite2pVariableNames), message)
            
            S(1).(obj.Name) = data;
            
            complementaryVars = setdiff(suite2pVariableNames, obj.Name);
            filenamesTemp = strrep(obj.Filename, obj.Name, complementaryVars);

            % Load data from complementary variables
            if strcmp( obj.FileType, 'npy' )
                for i = 1:numel(filenamesTemp)
                    thisFile = filenamesTemp{i};
                    thisVarName = complementaryVars{i};
                    data = nansen.dataio.fileadapter.numpy(thisFile).load();
                    S.(thisVarName) = data;
                end
            elseif strcmp( obj.FileType, 'mat' )
                for i = 1:numel(filenamesTemp)
                    thisFile = filenamesTemp{i};
                    thisVarName = complementaryVars{i};
                    if ~isfile(thisFile)
                        error('File %s is required, but was not found', thisFile)
                    end
                    sLoaded = load(thisFile);
                    S.(thisVarName) = sLoaded.data;
                end
            else
                error('File type "%s" is not supported, please report.', obj.FileType)
            end
            
            % Reshape data. Some data is placed in cell arrays during
            % conversion from numpy
            for i = 1:numel(suite2pVariableNames)
                
                switch suite2pVariableNames{i}
                    
                    case 'stat'
                        if iscell(S.stat); S.stat = cat(1, S.stat{:}); end
                        assert(isa(S.stat, 'struct'), 'Expected suite2p "stat" to be a struct array')
                    case 'ops'
                        if iscell(S.ops); S.ops = cat(1, S.ops{:}); end
                        assert(isa(S.stat, 'struct'), 'Expected suite2p "ops" to be a struct')
                    case 'iscell'
                        assert(isnumeric(S.iscell), 'Expected suite2p "iscell" to be numeric')
                end
            end
        end
        
    end
    
    methods (Access = private) % Methods for writing %Todo: simplify...

        function [rois, images, stats, clsf] = unpackFromRoiArray(obj, data)
            rois = data;
            images = rois.getappdata('roiImages');
            stats = rois.getappdata('roiStats');
            clsf = rois.getappdata('roiClassification');
        end
        
        function [rois, images, stats, clsf] = unpackFromRoiGroup(obj, data)
            rois = data.roiArray;
            images = data.roiImages;
            stats = data.roiStats;
            clsf = data.roiClassification;
        end
        
        function [rois, images, stats, clsf] = unpackFromStruct(obj, data)
            rois = data.roiArray;
            images = data.roiImages;
            stats = data.roiStats;
            clsf = data.roiClassification;
        end
    
    end
    
    methods (Static)
        
        function tf = isNansenRoiFile(filepath, data)
        
            tf = false;
            %[~, name, ~] = fileparts(filepath);
            
            refVarNames = {'sessionData', 'roi_arr', 'RoiArray', 'roiArray'};
            
            if isa(data, 'struct')
                dataVarNames = fieldnames(data);
                isMatch = contains(dataVarNames, refVarNames);
                
                if any(isMatch)
                    tf = true;
                end
            end
            
        end
        
        function tf = isSuite2pRoiFile(filepath, data)
            
            if nargin < 2
                S = load(filepath);
            end
            
            tf = false;
            [~, name, ~] = fileparts(filepath);

            if strcmp(name, 'stat')
                if isa(data, 'cell')
                    if isa(data{1}, 'struct')
                        fieldnamesS2p = {'compact', 'med', 'lam', 'skew'}';
                        if all(ismember(fieldnamesS2p, fieldnames(data{1})))
                            tf = true;
                        end
                    end
                end
            else
                if all( isfield(data, {'stat', 'ops', 'iscell'}) )
                    tf = true;
                end
                
                % What if someone renamed their files...?
            end
        end
        
        function tf = isCaimanRoiFile(filepath, data)
        
            tf = false;
            [~, name, ~] = fileparts(filepath);

            if strcmp(name, 'stat')
                
                
            else
                % What if someone renamed their files...?
            end
        end
        
        function tf = isExtractRoiFile(filepath, data)
        
            tf = false;
            [~, name, ~] = fileparts(filepath);

            if strcmp(name, 'stat')
                
                
            else
                % What if someone renamed their files...?
            end
        end
        
        function tf = isVHLabRoiFile(filepath, data)
            if nargin < 2
                data = load(filepath);
            end
            
            if isfield(data, 'cellstructs')
                tf = true;
            end
        end
        
        function tf = isRoigroupStruct(data)
            fields = {'roiArray', 'roiImages', 'roiStats', 'roiClassification'};
            tf = isstruct(data) && all( isfield(data, fields) );
        end
        
    end
end

