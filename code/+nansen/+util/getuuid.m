function uuid = getuuid()
%getuuid Get a universal unique identifier. 
%
%   uuid = getuuid() returns a universal unique identifier. This function
%   uses matlab's builtin type if it is available (faster) or the Java
%   Virtual Machine if not

    persistent useJava
    if isempty(useJava); useJava = false; end

    if ~useJava
        try
            % matlab's builtin uuid was introduced sometimes after v2017b
            uuid = char( matlab.lang.internal.uuid );
            return
        catch
            % Save this choice for later calls to function:
            if ~usejava('jvm')
                error([mfilename ' requires Java to run.']);
            else
                useJava = true;
            end
        end
    else
        % continue
    end
    
    if useJava
        uuid = char( java.util.UUID.randomUUID() );
    end

end