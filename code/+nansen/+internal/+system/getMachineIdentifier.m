function machineIdentifier = getMachineIdentifier()
%getMachineIdentifier Get an identifier for the current machine
%
%   machineIdentifier = getMachineIdentifier() returns a stable, filename
%   safe identifier for the machine NANSEN is running on, as a string of 32
%   hexadecimal characters. It names the machine specific folder of a user
%   data directory, so that machines sharing that directory keep their own
%   configurations.
%
%   On macOS it is the MD5 hash of the hardware UUID, the IOPlatformUUID
%   that "ioreg -rd1 -c IOPlatformExpertDevice" reports.
%   utility.system.getComputerName hashes the address that ifconfig
%   reports for en0 instead, and with private Wi-Fi addressing on, that is
%   an address macOS assigns per Wi-Fi network rather than the hardware
%   address. If ioreg reports no UUID, and on other platforms, the
%   identifier is utility.system.getComputerName(true).
%
%   The identifier is cached, because resolving it queries the operating
%   system and it is needed on every local path lookup.
%
%   See also nansen.localdatadir, utility.system.getComputerName

    persistent cachedIdentifier

    if isempty(cachedIdentifier)
        cachedIdentifier = resolveMachineIdentifier();
    end

    machineIdentifier = cachedIdentifier;
end

function machineIdentifier = resolveMachineIdentifier()
%resolveMachineIdentifier Derive the identifier from the operating system

    if ismac
        platformUuid = readPlatformUuid();
        if strlength(platformUuid) > 0
            machineIdentifier = hashText(platformUuid);
            return
        end
    end

    machineIdentifier = string( utility.system.getComputerName(true) );
end

function platformUuid = readPlatformUuid()
%readPlatformUuid Read the hardware UUID of a Mac, or "" if it is not found

    % ioreg is called by its full path, because the PATH that MATLAB passes
    % to system depends on how MATLAB was started.
    [status, output] = system('/usr/sbin/ioreg -rd1 -c IOPlatformExpertDevice');

    platformUuid = "";
    if status ~= 0; return; end

    candidates = extractBetween(string(output), '"IOPlatformUUID" = "', '"');
    if isempty(candidates); return; end

    % A UUID has 36 characters: 32 hexadecimal digits and 4 hyphens
    isUuid = strlength(candidates(1)) == 36 && count(candidates(1), "-") == 4 ...
        && all( isstrprop(char(erase(candidates(1), "-")), 'xdigit') );

    if isUuid
        platformUuid = candidates(1);
    end
end

function hashedText = hashText(text)
%hashText Hash text to 32 hexadecimal characters with MD5
%
%   Uses the same digest as utility.system.getComputerName, so that the
%   identifier has the same form on every platform.

    engine = java.security.MessageDigest.getInstance('MD5');
    engine.update( typecast(uint16(char(text)), 'uint8') );
    hashBytes = typecast(engine.digest, 'uint8');
    hashedText = string( sprintf('%.2x', double(hashBytes)) );
end
