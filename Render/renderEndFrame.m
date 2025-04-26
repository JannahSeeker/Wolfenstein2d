function renderEndFrame()
%renderEndFrame Signals the end of a rendering frame.
%   Typically swaps buffers and displays the drawn content in the rendering engine.
%
%   renderEndFrame()
%
%   See also renderBeginFrame.

    try
        % Call the MEX function with the 'endFrame' command
        renderMex('endFrame');
    catch ME
        warning('renderEndFrame:FailedToCallMEX', ...
                'Failed to call renderMex function for "endFrame": %s', ME.message);
    end
end