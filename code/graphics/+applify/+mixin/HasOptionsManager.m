classdef HasOptionsManager < handle
%HasOptionsManager Mixin that gives a class an instance-level OptionsManager
%
%   Provides a clean separation between user settings (persistent
%   preferences, saved to file via UserSettings) and method options
%   (algorithm parameters, managed via OptionsManager).
%
%   Intended for use by AppPlugin subclasses that represent an algorithm
%   with parameters. Mix this in alongside AppPlugin to get a dedicated
%   options path that does not go through obj.settings.
%
%   USAGE
%       classdef MyPlugin < applify.mixin.AppPlugin & applify.mixin.HasOptionsManager
%
%       % In assignDefaultOptions:
%       function assignDefaultOptions(obj)
%           obj.OptionsManager = nansen.manage.OptionsManager('myFunction');
%       end
%
%       % Elsewhere: read options
%       opts = obj.Options;
%
%       % Open editor and wait
%       [opts, wasAborted] = obj.editOptions();

    properties
        OptionsManager nansen.manage.OptionsManager
    end

    properties (Dependent)
        Options
    end

    properties (Access = private)
        Options_
    end

    methods

        function set.Options(obj, options)
            obj.Options_ = options;
        end

        function options = get.Options(obj)
            if ~isempty(obj.Options_)
                options = obj.Options_;
            elseif ~isempty(obj.OptionsManager)
                options = obj.OptionsManager.Options;
            else
                options = struct.empty;
            end
        end

    end

    methods (Access = public)

        function [options, wasAborted] = editOptions(obj)
        %editOptions Open the options editor and wait for user input
            [~, options, wasAborted] = obj.OptionsManager.editOptions();
            if ~wasAborted
                obj.Options_ = options;
                obj.onOptionsChanged();
            end
            if ~nargout
                clear options wasAborted
            elseif nargout == 1
                clear wasAborted
            end
        end

    end

    methods (Access = protected)

        function onOptionsChanged(obj) %#ok<MANU>
        %onOptionsChanged Called after options are changed via editOptions
        %   Subclasses may override to react to option changes immediately.
        end

    end

end
