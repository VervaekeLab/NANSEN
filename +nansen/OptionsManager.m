classdef OptionsManager < nansen.manage.OptionsManager
%nansen.OptionsManager Interface for managing options for functions/methods
%
%   The purpose of this class is to simplify the process of loading and
%   saving preset- and custom options for a function or a session method

    methods
        function obj = OptionsManager(varargin)
            obj@nansen.manage.OptionsManager(varargin{:})
        end
    end

end