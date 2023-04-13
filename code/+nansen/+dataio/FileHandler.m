classdef FileHandler < handle

    % Alternative name:
    %   InteractiveFileHandler


    % Idea for a class that should have the following functionality

    % - Save data to datasets (right now this is handled by a DataLocation).
    %   Q: Why use a FileHandler instead?
    %
    % - Simplify interactive loading and saving of data to files
    %
    % - Determine filepaths to use for saving files. I.e should simplify the
    %   process of specifying where to save files to and where to load files
    %   from, i.e encapsulation of uiput and uiget
    %

    
    % Q: What is the difference between this and a file adapter?
    
    properties
        filepath
    end


    methods

        function obj = FileHandler(initPath, varargin)
            
            % Create a single folder dataset if initpath is a folder
            
            % Add data variables or set other params from varargin...
            
        end

    end

    methods
        % load
        % save
        % getfilepath

    end


    % Two different use cases:
    % 1) save and load from file
    %    uiput, uiget
    % 2) save and load from session data variable
    %    enter variable name
    %    save with correct file adapter subfolder location etc.


    % Some options/configurations
    % - PromptIfFileExists true/false
    % - Default file name suffix
    
end