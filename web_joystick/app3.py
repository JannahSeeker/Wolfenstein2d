import threading
import serial
import time
from flask import Flask, jsonify, request
from flask import Flask, jsonify, request, render_template
from flask_cors import CORS

# ——— Configuration —————————————————————————————
SERIAL_PORT = '/dev/tty.usbserial-A5069RR4'  # or COM3 on Windows
BAUD_RATE   = 115200
READ_TIMEOUT = 0.1            # seconds
joystick_state = {}
joy = True

# ——— Serial‐reader thread ——————————————————————
def serial_reader():
    """
    Continuously reads 2-byte packets from the Arduino, decodes them, 
    and updates `joystick_state`.
    """
    ser = serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=READ_TIMEOUT)
    while True:
        if ser.in_waiting >= 1:
            raw = ser.read(1)
            if raw:
                # Grab the single byte as an integer
                p = raw[0]

                # Buttons
                bl = (p >> 7) & 0x01    # bit-7: left button
                br = (p >> 6) & 0x01    # bit-6: right button

                # Axes (each encoded in two bits, mapped 0→–1,1→0,2→+1)
                xl = ((p >> 4) & 0x03) - 1   # bits 5–4
                yl = ((p >> 2) & 0x03) - 1   # bits 3–2
                xr = ( p        & 0x03) - 1  # bits 1–0

                # Update shared state
                joystick_state['xl'] = xl
                joystick_state['yl'] = yl
                joystick_state['xr'] = xr
                joystick_state['bl'] = bl
                joystick_state['br'] = br
        else:
            time.sleep(READ_TIMEOUT)
        print(joystick_state)

if joy:# Start the background thread
    thread = threading.Thread(target=serial_reader, daemon=True)
    thread.start()


def create_joystick(id=None):
    """
    Ensure a joystick state exists for the given ID.
    If no ID is provided, create a new one at the end of the list.
    """
    if id is None:
        id = len(joysticks)
    # Expand list to include this ID
    while len(joysticks) <= id:
        joysticks.append({})
    # Initialize state if empty
    if not joysticks[id]:
        joysticks[id] = {'xl': 0, 'yl': 0, 'xr': 0, 'bl': 0, 'br': 0}
    return id



# ——— Flask app ——————————————————————————————————
app = Flask(__name__)
CORS(app)  # allow cross‐origin requests

@app.route('/')
def index():
    # Renders templates/joystick.html (see next)
    return render_template('joystick2.html')
# In-memory state
joysticks = [{}]  # list of joystick states by ID, index 0 unused or default

@app.route('/api/createJoystick/<int:id>', methods=['GET'])
def create_joystick_id(id):
    new_id = create_joystick(id)
    print(new_id)
    return jsonify({'status': 'created', 'id': new_id})

@app.route('/api/createJoystick', methods=['GET'])
def create_joystick_():
    new_id = create_joystick()
    print(new_id)
    return jsonify({'status': 'created', 'id': new_id})

@app.route('/api/updateJoystick/<int:id>', methods=['POST'])
def update_joystick(id):
    if id >= len(joysticks):
        return jsonify({'error': 'Joystick not found'}), 404
    data = request.get_json() or {}
    state = joysticks[id]
    # Update only known keys
    for key in ['xl', 'yl', 'xr', 'bl', 'br']:
        if key in data:
            state[key] = data[key]
    print(data)
    print(state)
    return jsonify({'status': 'updated', 'id': id, 'state': state})

@app.route('/api/joystick/<int:id>', methods=['GET'])
def api_joystick(id):
    if id == 999:
        print(joystick_state)
        return jsonify(joystick_state)
    if id >= len(joysticks):
        return jsonify({'error': 'Joystick not found'}), 404
    print(joysticks[id])
    return jsonify(joysticks[id])



if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5100, debug=False)
