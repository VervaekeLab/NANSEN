classdef sessionMethodClassTemplate < nansen.session.SessionMethod
%SESSIONMETHODCLASSTEMPLATE Summary of this function goes here
%   Detailed explanation goes here
    
    properties (Constant) % SessionMethod attributes
        MethodName = ''
        BatchMode = 'serial'
        IsManual = false
        IsQueueable = true;
        OptionsManager = nansen.OptionsManager(mfilename('class')) % todo...
    end
    
    methods
        
        function obj = sessionMethodClassTemplate(varargin)
            
            obj@nansen.session.SessionMethod(varargin{:})

        end
    end
    
    methods
        
        function runMethod(obj)
            
        end
    end
end
