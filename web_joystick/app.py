from flask import Flask, jsonify, request, render_template
from flask_cors import CORS

app = Flask(__name__)
CORS(app)  # allow MATLAB or any client to fetch from this API

# Global in-memory state
joystick_state = {
    "x": 0,      # horizontal axis (−1 left to +1 right)
    "y": 0,      # vertical axis (−1 down to +1 up)
    "buttons": { # you can extend with as many buttons as you like
        "btn1": 0,
        "btn2": 0
    }
}

@app.route('/')
def index():
    # Renders templates/joystick.html (see next)
    return render_template('joystick.html')

@app.route('/api/joystick1', methods=['GET', 'POST'])
def api_joystick():
    global joystick_state
    if request.method == 'POST':
        data = request.get_json(force=True)
        # Expecting keys "x", "y", and optional "buttons"
        joystick_state["x"] = float(data.get("x", joystick_state["x"]))
        joystick_state["y"] = float(data.get("y", joystick_state["y"]))
        if "buttons" in data:
            joystick_state["buttons"].update(data["buttons"])
        return jsonify(success=True)
    else:
        # GET → return current state
        return jsonify(joystick_state)

if __name__ == '__main__':
    # Listen on all interfaces so MATLAB (or another machine) can reach it
    app.run(host='0.0.0.0', port=5100, debug=True)