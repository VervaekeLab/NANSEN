classdef DialogInterface < handle
    
    properties (Abstract)
        SaveLog
        LogFile
    end
    
    properties
        Verbosity
        ErrorStackDepth = inf           % How many levels to display from error stack
        WarningStackDepth = inf
    end
    
    properties (Access = protected)
        PreviousMessage
    end
    
    methods (Abstract)
        
        print(obj, varargin)
        
        replace(obj, varargin)
        
        append(obj, varargin) % append message
        
        warn(obj, varargin)
        
        alert(obj, varargin)
        
        confirm(obj, prompt, title)
        
        ask(obj, prompt, title, options, default)
        
        uiselect(obj, selectionList)
        
    end
end
