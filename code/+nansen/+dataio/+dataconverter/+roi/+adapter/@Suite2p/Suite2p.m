classdef Suite2p < nansen.dataio.dataconverter.roi.RoiAdapter
    
    properties (Constant)
        SUITE_2P_VARNAMES = {'stat', 'ops', 'iscell'};
    end

    methods (Static)% Methods in separate files
        
        tf = isRoiFormatValid(filePath, data)

    end

    methods

        function roiData = convertRois(obj, data)

            %assert( isstruct(data), 'Data must be a struct' )

            % Suite2p exports to stats, ops & icell, we need all
            if ~isfield(data, obj.SUITE_2P_VARNAMES)
                data = obj.collectSuite2pVariables(data);
            end

            [roiArray, classification, stats, images] = nansen.wrapper.suite2p.convertRois(data);
            roiData = struct(roiArray,classification,stats,images);
        end

    end


    methods (Access = private)

        function S = collectSuite2pVariables(obj, data)
        %collectSuite2pVariables Collect complimentary variables from suite2p    
            
        % Suite2p exports roidata to multiple files. Try to collect it
        % here using the default output names of suite2p. If files are not
        % fitting this pattern, it might be necessary to create a specific
        % method(s) for handling those cases.
            
            assert(~isempty(obj.FilePath), 'FilePath is not set')
            
            [~, filename, fileExtension] = fileparts(obj.FilePath);
            obj.assertIsSuite2pFilename(filename)

            % Build a struct with fields for each of the files that are
            % output by suite 2p (stat, ops, iscell)
            S = struct.empty;
            
            suite2pVariableNames = obj.SUITE_2P_VARNAMES;
            
            S(1).(filename) = data;
            
            complementaryVars = setdiff(suite2pVariableNames, filename);
            filenamesTemp = strrep(obj.FilePath, filename, complementaryVars);

            % Load data from complementary variables
            if strcmp( fileExtension, '.npy' )
                for i = 1:numel(filenamesTemp)
                    thisFile = filenamesTemp{i};
                    thisVarName = complementaryVars{i};
                    data = nansen.dataio.fileadapter.numpy(thisFile).load();
                    S.(thisVarName) = data;
                end
            elseif strcmp( fileExtension, '.mat' )
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
                error('File type "%s" is not supported, please report.', fileExtension)
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
        
        function assertIsSuite2pFilename(obj, filename)
            
            validNames = obj.SUITE_2P_VARNAMES;

            % Check that filename is a suite2p output
            message = sprintf('Filename %s is not reckognized as a suite2p file', filename);
            assert(ismember(filename, validNames), message)
        end

    end

end