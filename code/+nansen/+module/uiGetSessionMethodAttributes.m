function S = uiGetSessionMethodAttributes()
    
%     Work in progress
%
%     Create function in the same way as nansen.plugin.fileadapter.uigetFileAdapterAttributes.
%     Adapted from nansen.session.methods.template.createNewSessionMethod
    
    wasSuccess = false;
    
    % Parameters to open in a dialog

    S = struct();
    S.MethodName = '';
% %     S.BatchMode = 'serial';
% %     S.BatchMode_ = {'serial', 'batch'};
    S.Input = 'Single session';
    S.Input_ = {'Single session', 'Multiple sessions'};
    S.Queueable = true;
    S.Type = 'Function'; % (Template type, i.e use function template or sessionmethod template)
    S.Type_ = {'Function', 'SessionMethod Class'};
    
    menuNames = app.SessionTaskMenu.getRootLevelMenuNames();
    S.MenuLocation = menuNames{1};
    S.MenuLocation_ = menuNames;
    
    S.MenuSubLocation = '';
    
    [S, wasAborted] = tools.editStruct(S, '', 'Create Session Method', ...
                'Prompt', 'Configure new session method:', ...
                'ReferencePosition', app.Figure.Position, ...
                'ValueChangedFcn', @onValueChanged );
    
    if wasAborted; return; end
    if isempty(S.MethodName); return; end
    wasSuccess = true;

end

% Todo:
%   S.Name
%   S.Attributes
%   S.Configuration
