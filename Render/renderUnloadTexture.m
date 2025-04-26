function renderUnloadTexture(textureID)
%renderUnloadTexture Unloads a previously loaded texture from memory.
%
%   renderUnloadTexture(TEXTUREID) releases the resources associated with
%   the given numeric TEXTUREID handle obtained from renderLoadTexture.
%
%   Example: renderUnloadTexture(tex);
%
%   See also renderLoadTexture.

    arguments
        textureID (1,1) {mustBeNumeric, mustBeNonnegative} % ID obtained from loadTexture
    end

    try
        % Call the MEX function with the 'unloadTexture' command
        renderMex('unloadTexture', textureID);
    catch ME
        warning('renderUnloadTexture:FailedToCallMEX', ...
                'Failed to call renderMex function for "unloadTexture": %s', ME.message);
    end
end