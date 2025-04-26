#include "mex.h" // MATLAB MEX API header
#include "RaycasterEngine.h" // Your engine's header (for function declarations)
// Include raylib.h if needed for types like Color used internally here
#include "raylib.h"
#include <string>
#include <cstring> // For strcmp

// Helper to get Color from MATLAB input (e.g., expecting 1x4 uint8 array [R G B A])
Color getColorFromMxArray(const mxArray* arr) {
    if (!mxIsUint8(arr) || mxGetNumberOfElements(arr) != 4) {
        mexErrMsgIdAndTxt("Renderer:InvalidColor", "Color must be a 1x4 uint8 array [R G B A].");
    }
    unsigned char* rgba = (unsigned char*)mxGetData(arr);
    return Color{rgba[0], rgba[1], rgba[2], rgba[3]};
}


// The gateway function
void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {

    // Argument 1: Command string
    if (nrhs < 1 || !mxIsChar(prhs[0])) {
        mexErrMsgIdAndTxt("Renderer:InvalidInput", "First argument must be a command string.");
    }
    char* command = mxArrayToString(prhs[0]);
    std::string cmd(command);
    mxFree(command); // Free memory allocated by mxArrayToString

    // --- Dispatch based on command ---

    if (cmd == "init") {
        if (nrhs != 3 || !mxIsScalar(prhs[1]) || !mxIsScalar(prhs[2])) {
             mexErrMsgIdAndTxt("Renderer:Init", "Usage: init(width, height)");
        }
        int width = (int)mxGetScalar(prhs[1]);
        int height = (int)mxGetScalar(prhs[2]);
        // Assuming title is fixed or passed differently for simplicity here
        bool success = InitRenderer(width, height, "MATLAB Renderer");
        if (!success) {
            mexErrMsgIdAndTxt("Renderer:Init", "InitRenderer failed.");
        }
        // Optional: return success flag to MATLAB
        if (nlhs > 0) {
            plhs[0] = mxCreateLogicalScalar(success);
        }
        return; // Done with init
    }

    if (cmd == "shutdown") {
        ShutdownRenderer();
        return; // Done
    }

    if (cmd == "shouldClose") {
         if (nlhs > 0) {
            plhs[0] = mxCreateLogicalScalar(Renderer_WindowShouldClose());
        }
         return;
    }

     if (cmd == "beginFrame") {
        BeginFrame();
        return;
     }

      if (cmd == "endFrame") {
        EndFrame();
        return;
     }

    if (cmd == "drawRect") {
         // Expect: drawRect(x, y, w, h, color)
        if (nrhs != 6 || !mxIsScalar(prhs[1]) || !mxIsScalar(prhs[2]) || !mxIsScalar(prhs[3]) || !mxIsScalar(prhs[4])) {
             mexErrMsgIdAndTxt("Renderer:drawRect", "Usage: drawRect(x, y, w, h, [R G B A])");
        }
        int x = (int)mxGetScalar(prhs[1]);
        int y = (int)mxGetScalar(prhs[2]);
        int w = (int)mxGetScalar(prhs[3]);
        int h = (int)mxGetScalar(prhs[4]);
        Color color = getColorFromMxArray(prhs[5]); // Use helper to parse color

        // Assuming you still have the original DrawScreenRectangle(int, int, int, int, Color)
        DrawScreenRectangle(x, y, w, h, color);
        return;
    }

    // --- Add cases for drawText, drawLine, loadTexture etc. ---
    // Example for drawText:
    if (cmd == "drawText") {
        // Expect: drawText(text, x, y, fontSize, color)
         if (nrhs != 6 || !mxIsChar(prhs[1]) || !mxIsScalar(prhs[2]) || !mxIsScalar(prhs[3]) || !mxIsScalar(prhs[4])) {
             mexErrMsgIdAndTxt("Renderer:drawText", "Usage: drawText('text', x, y, fontSize, [R G B A])");
        }
        char* text = mxArrayToString(prhs[1]);
        int x = (int)mxGetScalar(prhs[2]);
        int y = (int)mxGetScalar(prhs[3]);
        int fontSize = (int)mxGetScalar(prhs[4]);
        Color color = getColorFromMxArray(prhs[5]);

        DrawScreenText(text, x, y, fontSize, color);
        mxFree(text); // Free text buffer
        return;
    }

    if (cmd == "loadTexture") {
        // Expect: loadTexture(filePath) -> textureID
         if (nrhs != 2 || !mxIsChar(prhs[1])) {
             mexErrMsgIdAndTxt("Renderer:LoadTexture:Args", "Usage: textureID = loadTexture('path/to/texture.png'). File path must be a string.");
         }
         if (nlhs > 1) mexErrMsgIdAndTxt("Renderer:LoadTexture:Outputs", "Too many output arguments for loadTexture.");

        char* filePath_cstr = mxArrayToString(prhs[1]);
        if (filePath_cstr == NULL) {
             mexErrMsgIdAndTxt("Renderer:OutOfMemory", "Failed to convert file path string (mxArrayToString).");
        }

        TextureID texID = LoadTextureFromPath(filePath_cstr); // Make sure LoadTextureFromPath exists and is linked
        mxFree(filePath_cstr);

        if (nlhs > 0) { // Return texture ID (treat 0 as invalid/failure)
             // Return as double, common practice in MATLAB for IDs/handles
             plhs[0] = mxCreateDoubleScalar((double)texID);
        }
        return; // Done
    }

     if (cmd == "unloadTexture") {
        // Expect: unloadTexture(textureID)
        if (nrhs != 2 || !mxIsNumeric(prhs[1]) || !mxIsScalar(prhs[1])) {
             mexErrMsgIdAndTxt("Renderer:UnloadTexture:Args", "Usage: unloadTexture(textureID). textureID must be a numeric scalar.");
        }

        TextureID texID = (TextureID)mxGetScalar(prhs[1]); // Cast from double
        // Add check for validity? (e.g., texID > 0) depends on C++ function
        UnloadTextureByID(texID); // Make sure UnloadTextureByID exists and is linked
        return; // Done
    }

     if (cmd == "drawLine") {
        // Expect: drawLine(x1, y1, x2, y2, color)
         if (nrhs != 6 || !mxIsNumeric(prhs[1]) || !mxIsScalar(prhs[1]) || !mxIsNumeric(prhs[2]) || !mxIsScalar(prhs[2]) || !mxIsNumeric(prhs[3]) || !mxIsScalar(prhs[3]) || !mxIsNumeric(prhs[4]) || !mxIsScalar(prhs[4])) {
             mexErrMsgIdAndTxt("Renderer:DrawLine:Args", "Usage: drawLine(x1, y1, x2, y2, [R G B A]). Coordinates must be numeric scalars.");
        }
        int x1 = (int)mxGetScalar(prhs[1]);
        int y1 = (int)mxGetScalar(prhs[2]);
        int x2 = (int)mxGetScalar(prhs[3]);
        int y2 = (int)mxGetScalar(prhs[4]);
        Color color = getColorFromMxArray(prhs[5]);

        DrawScreenLine(x1, y1, x2, y2, color); // Make sure DrawScreenLine exists and is linked
        return; // Done
    }

     if (cmd == "getScreenSize") {
        // Expect: [width, height] = getScreenSize()
         if (nrhs != 1) mexErrMsgIdAndTxt("Renderer:GetScreenSize:Args", "Usage: [width, height] = getScreenSize()");
         if (nlhs > 1) mexErrMsgIdAndTxt("Renderer:GetScreenSize:Outputs", "Too many output arguments for getScreenSize. Use [w, h] = getScreenSize().");

        if (nlhs > 0) { // Only call if output requested
            int width = GetRendererScreenWidth(); // Make sure these exist and are linked
            int height = GetRendererScreenHeight();

            // Return as a 1x2 double row vector
            plhs[0] = mxCreateDoubleMatrix(1, 2, mxREAL);
            double* sizeData = mxGetPr(plhs[0]);
            sizeData[0] = (double)width;
            sizeData[1] = (double)height;
        }
        return; // Done
     }

    if (cmd == "getInputState") {
    // Expect: [inputStruct] = getInputState()
    if (nrhs != 1) mexErrMsgIdAndTxt("Renderer:GetInput:Args", "Usage: [inputStruct] = getInputState()");
    if (nlhs > 1) mexErrMsgIdAndTxt("Renderer:GetInput:Outputs", "Too many output arguments.");

    // Define the fields for the output struct
    const char* fieldNames[] = {
        "MoveForward", "MoveBackward", "RotateLeft", "RotateRight", // Keyboard basic move/rotate
        "StrafeLeft", "StrafeRight", // Keyboard strafe (example)
        "Exit", // Keyboard exit request (e.g., Escape key)
        "MouseX", "MouseY",          // Mouse position
        "MouseLeft", "MouseRight", "MouseMiddle" // Mouse buttons
        // Add more fields as needed (e.g., specific action keys like 'Space')
    };
    int nfields = sizeof(fieldNames) / sizeof(*fieldNames);

    // Create the output struct
    plhs[0] = mxCreateStructMatrix(1, 1, nfields, fieldNames);
    if (plhs[0] == NULL) {
        mexErrMsgIdAndTxt("Renderer:GetInput:Memory", "Could not create output struct.");
    }

    // --- Poll Raylib Input Functions ---

    // Keyboard Movement/Rotation (WASD + Arrows)
    bool moveFwd = IsKeyDown(KEY_W) || IsKeyDown(KEY_UP);
    bool moveBwd = IsKeyDown(KEY_S) || IsKeyDown(KEY_DOWN);
    bool rotL = IsKeyDown(KEY_A) || IsKeyDown(KEY_LEFT);
    bool rotR = IsKeyDown(KEY_D) || IsKeyDown(KEY_RIGHT);
    // Add strafe keys if desired (e.g., Q/E)
    bool strafeL = IsKeyDown(KEY_Q);
    bool strafeR = IsKeyDown(KEY_E);
    // Exit Key
    bool exitReq = IsKeyDown(KEY_ESCAPE);

    // Mouse
    Vector2 mousePos = GetMousePosition();
    bool mouseL = IsMouseButtonDown(MOUSE_BUTTON_LEFT);
    bool mouseR = IsMouseButtonDown(MOUSE_BUTTON_RIGHT);
    bool mouseM = IsMouseButtonDown(MOUSE_BUTTON_MIDDLE);

    // --- Populate the MATLAB struct ---
    // Use mxSetFieldByNumber for simplicity, field order must match fieldNames
    mxSetFieldByNumber(plhs[0], 0, 0, mxCreateLogicalScalar(moveFwd));  // MoveForward
    mxSetFieldByNumber(plhs[0], 0, 1, mxCreateLogicalScalar(moveBwd));  // MoveBackward
    mxSetFieldByNumber(plhs[0], 0, 2, mxCreateLogicalScalar(rotL));     // RotateLeft
    mxSetFieldByNumber(plhs[0], 0, 3, mxCreateLogicalScalar(rotR));     // RotateRight
    mxSetFieldByNumber(plhs[0], 0, 4, mxCreateLogicalScalar(strafeL));  // StrafeLeft
    mxSetFieldByNumber(plhs[0], 0, 5, mxCreateLogicalScalar(strafeR));  // StrafeRight
    mxSetFieldByNumber(plhs[0], 0, 6, mxCreateLogicalScalar(exitReq));  // Exit
    mxSetFieldByNumber(plhs[0], 0, 7, mxCreateDoubleScalar(mousePos.x));// MouseX
    mxSetFieldByNumber(plhs[0], 0, 8, mxCreateDoubleScalar(mousePos.y));// MouseY
    mxSetFieldByNumber(plhs[0], 0, 9, mxCreateLogicalScalar(mouseL));   // MouseLeft
    mxSetFieldByNumber(plhs[0], 0, 10, mxCreateLogicalScalar(mouseR));  // MouseRight
    mxSetFieldByNumber(plhs[0], 0, 11, mxCreateLogicalScalar(mouseM));  // MouseMiddle

    return; // Done
}


    // If command not recognized
    mexErrMsgIdAndTxt("Renderer:UnknownCommand", "Unknown command: %s", cmd.c_str());
}