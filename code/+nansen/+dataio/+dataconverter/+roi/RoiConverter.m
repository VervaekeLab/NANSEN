classdef RoiConverter < handle
%RoiConverter Class with methods for finding roi adapters and using them 
% for converting rois to the standard format used within the Nansen toolbox
%
%   This class is used for detecting an appropriate roi adapter for
%   converting roi data from an unspecified format based on filename and/or
%   data in file and using that roi adapter for converting rois to a
%   standard format.
%
%
%   Supported roi types:
%       Suite2p
%       Nansen
%       CaImAn : todo
%       Extract : todo
%       ImageJ : todo

%   Todo: Get roi adapters from a watchfolder

    properties (Constant)
        % Package folder containing roi adapters:
        ADAPTER_PACKAGE = 'nansen.dataio.dataconverter.roi.adapter';
    end

    methods
        
        function roiData = convertRois(obj, filePath, data)
        %convertRois Converts data from given file to roidata
            
            adapterName = obj.findRoiAdapter(filePath, data);
            roiAdapter = feval(adapterName, filePath);
            
            roiData = roiAdapter.convertRois(data);
            
        end

        function adapterName = findRoiAdapter(obj, filepathOrig, data)
        %findRoiAdapter Find valid roi adapter for given filepath and data                
            
            % Split filepath to get file extension
            [folderpath, name, ext] = fileparts(filepathOrig);
            
            % If something else than a mat-file was given, use .mat extension
            if ~strcmp(ext, '.mat')
                filepath = fullfile(folderpath, [name, '.mat']);
            else
                filepath = filepathOrig;
            end
            
            % Throw error if mat-file does not exist for given file
            if ~strcmp(~ext, '.mat') && ~isfile(filepath)
                error(['File is not converted to matfile. Need a matfile ', ...
                    'to check the roi format'])
            end
            
            % Load data from file if data was not given as input
            if nargin < 2 || ~exist('data', 'var')
                S = load(filepath);
                if isfield(S, 'data')
                    data = S.data; % Assume file was converted from .npy?
                else
                    data = S;
                end
            end
            
            adapterNames = obj.listRoiAdapters();

            % Loop through adapters and use their isRoiFormatValid to test
            % if given the file is in the format of that roi adapter
            isMatched = false(1, numel(adapterNames));
            for i = 1:numel(adapterNames)
                thisAdapter = feval( adapterNames{i} );
                isMatched(i) = thisAdapter.isRoiFormatValid(filepath, data);
            end
            
            % Get name of matched adapter
            if sum(isMatched) == 1
                adapterName = adapterNames{isMatched};
            elseif sum(isMatched) == 0
                error('File "%s" contains rois of unknown format', filepathOrig)
            elseif sum(isMatched) > 1
                adapterName = adapterNames{find(isMatched, 1, 'first')};
                warning(['File with rois matched multiple roi formats. ', ...
                    'Using the first matched adapter "%s" to convert rois'], ...
                    adapterName)
            end
        end

        function fcnList = listRoiAdapters(obj)
        %listRoiAdapters Get list of available roi adapters from package

            % Adapter package is located in same folder as current file
            packageRootFolder = fileparts( mfilename('fullpath') );
            
            % Look for class folders in the adapter package
            L = dir( fullfile(packageRootFolder, '+adapter', '@*') );
            L = L([L.isdir]); % Just to make sure we only get folders
            
            % Get names for all detected classes.
            fcnList = strrep( {L.name}, '@', '' );
            
            % Assemble full class names, including package name.
            for i = 1:numel(fcnList)
                fcnList{i} = strjoin( ...
                    {obj.ADAPTER_PACKAGE, fcnList{i}}, '.');
            end
        end
        
    end
    
end