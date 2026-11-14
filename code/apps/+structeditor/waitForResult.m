function [data, wasCanceled, optionsName] = waitForResult(editor)
%waitForResult Wait for a struct editor to finish, read its result and delete it.
%
%   [data, wasCanceled] = structeditor.waitForResult(editor) blocks until
%   the user presses Ok or Cancel in editor, an app returned by
%   structeditor, or closes its window. After Ok, data is the edited data
%   and wasCanceled is false. After Cancel or closing the window, data is
%   the data the app was opened with and wasCanceled is true. The function
%   deletes editor, which closes its window, after reading the result.
%
%   [data, wasCanceled, optionsName] = structeditor.waitForResult(editor)
%   also returns the name of the options set selected in the app when it
%   was opened with an OptionsManager, and '' otherwise.
%
%   If editor is deleted before the user finishes, data is [] and
%   wasCanceled is true.
%
%   The result of structeditor.App is read from its wasCanceled, dataOrig,
%   dataEdit and currentOptionsName properties. Any other app is read
%   through the structeditor.StructEditorApp members FinishState, Data,
%   OriginalData and getPlugin.
%
%   See also structeditor

    arguments
        editor (1,1) handle
    end

    editor.waitfor()

    if ~isvalid(editor)
        data = [];
        wasCanceled = true;
        optionsName = '';
        return
    end

    if isa(editor, 'structeditor.App')
        [data, wasCanceled, optionsName] = readLegacyResult(editor);
    else
        [data, wasCanceled, optionsName] = readModernResult(editor);
    end

    delete(editor)
end

function [data, wasCanceled, optionsName] = readLegacyResult(editor)
%readLegacyResult Read the result of a structeditor.App after it finished.
    wasCanceled = editor.wasCanceled;
    if wasCanceled
        data = editor.dataOrig;
    else
        data = editor.dataEdit;
    end
    optionsName = editor.currentOptionsName;
end

function [data, wasCanceled, optionsName] = readModernResult(editor)
%readModernResult Read the result of a structeditor.StructEditorApp after it finished.

    % Closing the window leaves FinishState empty, which counts as Cancel.
    wasCanceled = editor.FinishState ~= "Finished";
    if wasCanceled
        data = editor.OriginalData;
    else
        data = editor.Data;
    end

    plugin = editor.getPlugin("nansen.manage.OptionsManagerPlugin");
    if isempty(plugin)
        optionsName = '';
    else
        optionsName = plugin.CurrentOptionsName;
    end
end
