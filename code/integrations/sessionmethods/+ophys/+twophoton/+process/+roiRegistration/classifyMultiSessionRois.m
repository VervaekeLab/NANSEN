function varargout = classifyMultiSessionRois(sessionObject, varargin)
%CLASSIFYMULTISESSIONROIS Summary of this function goes here
%   Detailed explanation goes here


% % % % % % % % % % % % % % % INSTRUCTIONS % % % % % % % % % % % % % % %
% - - - - - - - - - - You can remove this part - - - - - - - - - - - 
% Instructions on how to use this template: 
%   1) If the session method should have parameters, these should be
%      defined in the local function getDefaultParameters at the bottom of
%      this script.
%   2) Scroll down to the custom code block below and write code to do
%   operations on the sessionObjects and it's data.
%   3) Add documentation (summary and explanation) for the session method
%      above. PS: Don't change the function definition (inputs/outputs)
%
%   For examples: Press e on the keyboard while browsing the session
%   methods. (e) should appear after the name in the menu, and when you 
%   select a session method, the m-file will open.


% % % % % % % % % % % % CONFIGURATION CODE BLOCK % % % % % % % % % % % % 
% Create a struct of default parameters (if applicable) and specify one or 
% more attributes (see nansen.session.SessionMethod.setAttributes) for 
% details.
    
    % Get struct of parameters from local function
    params = getDefaultParameters();
    
    % Create a cell array with attribute keywords
    ATTRIBUTES = {'batch', 'queueable'};   

    
% % % % % % % % % % % % % DEFAULT CODE BLOCK % % % % % % % % % % % % % % 
% - - - - - - - - - - Please do not edit this part - - - - - - - - - - - 
    
    % Create a struct with "attributes" using a predefined pattern
    import nansen.session.SessionMethod
    fcnAttributes = SessionMethod.setAttributes(params, ATTRIBUTES{:});
    
    if ~nargin && nargout > 0
        varargout = {fcnAttributes};   return
    end
    
    % Parse name-value pairs from function input and update parameters
    params = utility.parsenvpairs(params, [], varargin);
    
    
% % % % % % % % % % % % % % CUSTOM CODE BLOCK % % % % % % % % % % % % % % 
% Implementation of the method : Add your code here:    
    
    varName = 'MultisessionRoiCrossReference';
    filePath = sessionObject(1).loadData(varName);

    S = load(filePath);
    multiSessionRoiCollection = S.multiSessionRois;
    channelNumber = multiSessionRoiCollection(1).ImageChannel;

    % Load all multi session roi groups and concatenate by nRois x nSessions
    % todo
    numSessions = numel(sessionObject);

    numRois = zeros(1, numSessions);
    loadedRoiGroups = cell(1, numSessions);
    for i = 1:numSessions
        loadedRoiGroups{i} = sessionObject(i).loadData('RoiGroupLongitudinal');
        %loadedRoiGroups{i} = utility.cell.flatten(loadedRoiGroups{i});
        numRois(i) = numel(loadedRoiGroups{i}(channelNumber).roiArray);
    end

    % Concatenate roi from different channels and planes
    % longterm todo
    
    [roiArray, roiImages, roiStats, roiClassification] = deal(cell(1, numSessions));

    for i = 1:numSessions
        roiArray{i} = forceRow(loadedRoiGroups{i}(channelNumber).roiArray);
        roiImages{i} = forceRow(loadedRoiGroups{i}(channelNumber).roiImages);
        roiClassification{i} = forceRow(loadedRoiGroups{i}(channelNumber).roiClassification);
    end

    roiArray = cat(1, roiArray{:});
    roiImages = cat(1, roiImages{:});
    roiClassification = cat(1, roiClassification{:});

    roiStats = struct();
    
    avgRoiCorrelation = zeros(1, numSessions);

    for i = 1:numRois
        thisImage = cat(3, roiImages(:,i).ActivityWeightedMean);
        
        RHO = zeros(numSessions);
        for j = 1:numSessions
            for k = 1:numSessions
                RHO(j,k)=corr2(thisImage(:,:,j), thisImage(:,:,k));
            end
        end
        avgRoiCorrelation(i) = mean(RHO(:));

    end

    avgRoiCorrelation = repmat(avgRoiCorrelation, numSessions, 1);
    
    % Flatten all
    roiArray = roiArray(:);
    roiImages = roiImages(:);
    roiClassification = roiClassification(:);
    roiStats = struct('MultisessionCorrelation', num2cell(avgRoiCorrelation(:)));

    roiGroup = struct('roiArray', roiArray, 'roiImages', ...
        roiImages, 'roiStats', roiStats, 'roiClassification', roiClassification);
    
    % - Create a new roiStats

        % Compute classification stats 

        % Create labels including session id and roi number
    

    % Exchange roi stats, and use some roistats for all identical rois
    hClassifier = roiclassifier.openRoiClassifier(roiGroup);

    % Get classifications and save back to roigroups.
    hClassifier.SaveFcn = @(rois) saveClassifiedRois(sessionObject, rois);    


    % Return session object (please do not remove):
    % if nargout; varargout = {sessionObject}; end
end

function saveClassifiedRois(sessionObjects, classifiedRoiGroup)
    
    varName = 'MultisessionRoiCrossReference';
    filePath = sessionObjects(1).loadData(varName);

    S = load(filePath);
    multiSessionRoiCollection = S.multiSessionRois;
    channelNumber = multiSessionRoiCollection(1).ImageChannel;


    numSessions = numel(sessionObjects);

    roiArray = builtin('reshape', classifiedRoiGroup.roiArray, numSessions, []);
    roiImages = reshape(classifiedRoiGroup.roiImages, numSessions, []);
    roiClassification = reshape(classifiedRoiGroup.roiClassification, numSessions, []);


    for i = 1:numSessions
        roiGroup = sessionObjects(i).loadData('RoiGroupLongitudinal', ...
            'FileAdapter', 'nansen.dataio.fileadapter.internal.RoiGroupStruct');
        
        roiGroup(1, channelNumber).roiArray = roiArray(i, :);
        roiGroup(1, channelNumber).roiImages = roiImages(i, :);
        roiGroup(1, channelNumber).roiClassification = roiClassification(i, :)';

        sessionObjects(i).saveData('RoiGroupLongitudinal', roiGroup);
    end
end

function X = forceRow(X)
    if iscolumn(X)
        X = X';
    end
end


function params = getDefaultParameters()
%getDefaultParameters Get the default parameters for this session method
%
%   params = getDefaultParameters() should return a struct, params, which 
%   contains fields and values for parameters of this session method.

    % Add fields to this struct in order to define parameters for this
    % session method:
    params = struct();

end