function setUiFigureMinSize(hFigure, minimumSize)
%SETUIFIGUREMINSIZE Set minimum size of uifigure
%
%   setUiFigureMinSize(hFigure, minimumSize)

    warning('off', 'MATLAB:structOnObject')
    warning('off', 'MATLAB:ui:javaframe:PropertyToBeRemoved')
    window = struct(struct(struct(hFigure).Controller).PlatformHost).CEF;
    window.setMinSize( minimumSize )
    warning('on', 'MATLAB:structOnObject')
    warning('on', 'MATLAB:ui:javaframe:PropertyToBeRemoved')

end
