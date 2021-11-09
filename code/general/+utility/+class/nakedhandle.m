classdef nakedhandle < handle
%strippedhandle handle where handle methods dont show up in doc list.

    %Overload matlab handle methods to hide them 
    methods(Sealed, Hidden)
        
        function lh = addlistener(varargin)
            lh = addlistener@handle(varargin{:});
        end
        
        function eL = listener(varargin)
            eL = listener@handle(varargin{:});
        end
        
        function notify(varargin)
            notify@handle(varargin{:});
        end
        
        function Hmatch = findobj(varargin)
            Hmatch = findobj@handle(varargin{:});
        end
        
        function p = findprop(varargin)
            p = findprop@handle(varargin{:});
        end
        
        function TF = eq(varargin)
            TF = eq@handle(varargin{:});
        end
        
        function TF = ne(varargin)
            TF = ne@handle(varargin{:});
        end
        
        function TF = lt(varargin)
            TF = lt@handle(varargin{:});
        end
        
        function TF = le(varargin)
            TF = le@handle(varargin{:});
        end
        
        function TF = gt(varargin)
            TF = gt@handle(varargin{:});
        end
        
        function TF = ge(varargin)
            TF = ge@handle(varargin{:});
        end
        
    end
    
    
end

