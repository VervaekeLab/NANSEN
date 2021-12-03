classdef OptionsManager < nansen.manage.OptionsManager
%OPTIONSMANAGER Interface for managing options for functions/methods
%
%   The purpose of this class is to simplify the process of loading and
%   saving preset- and custom options for a function or a session method

% Todo: Should this be a function instead?

    methods
        function obj = OptionsManager(varargin)
            obj@nansen.manage.OptionsManager(varargin{:})
        end
    end

end
