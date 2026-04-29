function attributes = run(varargin)
%run Test action plugin entrypoint.

    if nargin == 0
        attributes = nansen.session.SessionMethod.setAttributes( ...
            struct(), 'serial', 'queueable');
        attributes.MethodName = 'Hello Session';
        return
    end

    attributes = [];
end
