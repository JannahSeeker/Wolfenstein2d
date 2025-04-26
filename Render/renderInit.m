function success = renderInit(width, height)
%renderInit Initializes the custom rendering engine window.
%
%   SUCCESS = renderInit(WIDTH, HEIGHT) initializes the renderer with the
%   specified screen dimensions. Returns true on success, false otherwise.
%
%   The window title is currently hardcoded as "MATLAB Renderer" in the
%   MEX file.
%
%   See also renderShutdown, renderDrawRect.

    arguments
        width  (1,1) {mustBeNumeric, mustBeInteger, mustBePositive}
        height (1,1) {mustBeNumeric, mustBeInteger, mustBePositive}
    end

    try
        % Call the MEX function with the 'init' command
        % Pass arguments as int32, as C int is typically 32-bit
        success = renderMex('init', int32(width), int32(height));
    catch ME
        warning('renderInit:FailedToCallMEX', ...
                'Failed to call renderMex function for "init": %s', ME.message);
        success = false;
    end
end