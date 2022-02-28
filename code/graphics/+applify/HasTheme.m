classdef HasTheme < uim.handle
%HasTheme Mixin class to provide apps / containers with a Theme property
%and a callback for when the value of Theme is changed.
%
%   A theme is a struct of fields with colors and other appearance
%   specifications for different ui components. Any class implementing the
%   onThemeMethod should be responsible/take into consideration for whether 
%   a given field is available in the theme struct.
%
%   ABSTRACT PROPERTIES
%       DEFAULT_THEME (Constant)
%
%   ABSTRACT METHODS 
%       onThemeChanged (Protected) : Callback function which is invoked 
%           when value of theme property is changed 


%   Todo: 
%       [x] Implement a private Theme_ property and make Theme Dependent.
%           Then, when setting Theme, Theme_ is set, and when getting Theme
%           the DEFAULT_THEME is returned if Theme_ is empty... (~I~U).
%       [ ] Use classes instead of structs for the Theme property (~I~U).


    properties (Abstract, Constant, Hidden)
        DEFAULT_THEME   
    end

    properties (Dependent)
        Theme
    end
    
    properties (Access = private)
        Theme_ = []     % Internally set value of theme.
    end
    
    methods (Abstract, Access = protected)
        onThemeChanged(obj)
    end
    
    methods
        function set.Theme(obj, newTheme)
            
            if ischar(newTheme)
                newTheme = nansen.theme.getThemeColors(newTheme);
                %Todo: validate
            end
            
            obj.Theme_ = newTheme;
            obj.onThemeChanged();
            
        end
        
        function theme = get.Theme(obj)
            
            if isempty(obj.Theme_)
                theme = obj.DEFAULT_THEME;
            else
                theme = obj.Theme_;
            end
            
        end
    end

end