classdef tab < uim.abstract.virtualContainer & uim.mixin.assignProperties
    
    properties
        Title = ''
        Panel = []
    end
    
    
    methods
        function obj = tab(hParent, varargin)
            
            
            % Assert that parent is a tabgroup.
            assertMsg = 'Parent must be an instance of uim.tabgroup';
            assert(isa(hParent, 'uim.tabgroup') || isa(hParent, 'uim.wtabgroup'), assertMsg)
            
            obj.Parent = hParent;
            obj.parseInputs(varargin{:});
            
            % Create tab panel (todo: Add more properties?)
            % Since tabgroup itself is a virtual container, need to add the 
            % panel in the tabgroups parent handle
            obj.Panel = uim.panel(obj.Parent.Parent, ...
                'BackgroundColor', obj.BackgroundColor);
             
            % Add tab to the tabgroup
            obj.Parent.addTab(obj)
            
            obj.IsConstructed = true;
            
        end
        
        function delete(obj)
            delete(obj.Panel)
        end
        
    end
    
    methods (Access = protected)
        
    end
    
    methods 
        function set.Title(obj, newValue)
            obj.Title = newValue;
            
            if obj.IsConstructed 
                obj.Parent.updateTabTitle(obj)
            end
        end
    end
    
    methods % Wrappers for placing matlab components
        
        function hContainer = getGraphicsContainer(obj)
            hContainer = obj.Panel.hPanel;
        end
        
    end
    
end



% %         did not work:
% %         function varargout = subsref(obj, s)
% %         
% %             varargout = cell(1, nargout);
% % 
% %             switch s(1).type
% % 
% %                 % Use builtin if a property is requested.
% %                 case '.'
% % 
% %                     if isprop(obj, s(1).subs)
% %                         [varargout{1}] = builtin('subsref', obj, s);
% %                     elseif ismethod(obj, s(1).subs)
% %                         [varargout{:}] = builtin('subsref', obj, s);
% %                     else % todo: the subsasgn is not a property or not a method, unwrap panel an call again. 
% %                         func = str2func(s(1).subs);
% %                         [varargout{:}] = func(obj.Panel, s(2).subs{''});
% %                     end
% %                     
% %                 otherwise
% %                     [varargout{:}] = builtin('subsref', obj, s);
% %             end