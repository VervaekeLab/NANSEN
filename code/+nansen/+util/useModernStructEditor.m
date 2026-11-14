function tf = useModernStructEditor()
%useModernStructEditor True when structeditor can open the StructEditor toolbox app.
%
%   tf = nansen.util.useModernStructEditor() returns true when
%   nansen.util.useModernUiComponents returns true (MATLAB R2025a and newer)
%   and the class structeditor.StructEditorApp on the MATLAB path has the
%   members that NANSEN calls:
%     - properties Data, OriginalData, FinishState, CloseOnExit, Title,
%       IsModal, Callback and Plugins
%     - methods waitfor, getPlugin and getAttachmentContainer
%
%   StructEditor does not report a version, so these members stand in for
%   one. StructEditorApp in StructEditor 0.1.0 lacks OriginalData, getPlugin
%   and getAttachmentContainer, and it also lacks the name-value arguments
%   Prompt, Name, LabelPosition, CustomFigureSize, Callback and Plugin that
%   structeditor passes to it.
%
%   See also structeditor, nansen.util.useModernUiComponents

    tf = nansen.util.useModernUiComponents() && hasRequiredMembers();
end

function tf = hasRequiredMembers()
%hasRequiredMembers True when StructEditorApp has the members NANSEN calls.

    requiredProperties = ["Data", "OriginalData", "FinishState", ...
        "CloseOnExit", "Title", "IsModal", "Callback", "Plugins"];
    requiredMethods = ["waitfor", "getPlugin", "getAttachmentContainer"];

    classInfo = meta.class.fromName("structeditor.StructEditorApp");
    if isempty(classInfo)
        tf = false;
        return
    end

    propertyNames = string({classInfo.PropertyList.Name});
    methodNames = string({classInfo.MethodList.Name});

    tf = all(ismember(requiredProperties, propertyNames)) ...
        && all(ismember(requiredMethods, methodNames));
end
