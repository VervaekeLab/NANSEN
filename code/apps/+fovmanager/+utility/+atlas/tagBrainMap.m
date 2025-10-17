function tagBrainMap()

tmpFig = fovmanager.view.openAtlas("paxinos");

h = findobj(tmpFig, 'Type', 'Polygon');

set(h, 'ButtonDownFcn', @addTag);
% set(h, 'ButtonDownFcn', []); % to reset callback

end

function addTag(src, ~)

tag = inputdlg('Enter Name');
if isempty(tag); return; end

src.DisplayName = tag{1};
src.Tag = tag{1};

end
