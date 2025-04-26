function textureID = renderLoadTexture(filePath)
%renderLoadTexture Loads a texture from a file using the rendering engine.
%
%   TEXTUREID = renderLoadTexture(FILEPATH) loads the image file specified
%   by FILEPATH (string).
%   Returns a numeric TEXTUREID handle used by other functions (e.g.,
%   renderDrawSprite - if implemented). Returns 0 if loading fails.
%
%   Example: tex = renderLoadTexture('images/player.png');
%            if tex == 0, error('Failed to load texture'); end
%
%   See also renderUnloadTexture.

    arguments
        filePath (1,:) {mustBeTextScalar} % Path to image file
    end

    textureID = 0; % Default to failure
    try
        % Call the MEX function with the 'loadTexture' command
        textureID = renderMex('loadTexture', filePath);
        if textureID == 0
             warning('renderLoadTexture:LoadFailed', ...
                     'renderMex returned texture ID 0, likely indicating failure for file: %s', filePath);
        end
    catch ME
        warning('renderLoadTexture:FailedToCallMEX', ...
                'Failed to call renderMex function for "loadTexture": %s', ME.message);
        textureID = 0; % Ensure failure ID on error
    end
end