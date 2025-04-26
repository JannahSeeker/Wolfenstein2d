function inputStateStruct = renderGetInputState()
%renderGetInputState Gets the current keyboard and mouse input state.
%
%   INPUTSTATESTRUCT = renderGetInputState() returns a struct containing
%   the current state of relevant input devices polled via the C++ engine.
%
%   Struct Fields (Example):
%       .MoveForward  (logical) : True if W or UpArrow is down
%       .MoveBackward (logical) : True if S or DownArrow is down
%       .RotateLeft   (logical) : True if A or LeftArrow is down
%       .RotateRight  (logical) : True if D or RightArrow is down
%       .StrafeLeft   (logical) : True if Q is down
%       .StrafeRight  (logical) : True if E is down
%       .Exit         (logical) : True if Escape is down
%       .MouseX       (double)  : Current mouse X position (pixels)
%       .MouseY       (double)  : Current mouse Y position (pixels)
%       .MouseLeft    (logical) : True if left mouse button is down
%       .MouseRight   (logical) : True if right mouse button is down
%       .MouseMiddle  (logical) : True if middle mouse button is down
%
%   Example: input = renderGetInputState; if input.MoveForward, disp('W!'); end

    inputStateStruct = struct([]); % Initialize empty in case of error
    try
        % Call the MEX function, expect a struct back
        inputStateStruct = renderMex('getInputState');
    catch ME
        warning('renderGetInputState:FailedToCallMEX', ...
               'Failed to call renderMex function for "getInputState": %s', ME.message);
        % Return an empty or default struct on error?
         inputStateStruct = struct(...
            'MoveForward', false, 'MoveBackward', false, ...
            'RotateLeft', false, 'RotateRight', false,...
            'StrafeLeft', false, 'StrafeRight', false,...
            'Exit', false, ...
            'MouseX', 0, 'MouseY', 0, ...
            'MouseLeft', false, 'MouseRight', false, 'MouseMiddle', false ...
         );
    end
end