import threading
import serial
import json
import time
from flask import Flask, jsonify
from flask_cors import CORS

# ——— Configuration —————————————————————————————
SERIAL_PORT = '/dev/tty.usbserial-A5069RR4'  # or COM3 on Windows
BAUD_RATE   = 115200
READ_TIMEOUT = 0.1            # seconds

# In-memory state
joystick_state = {}

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

# Start the background thread
thread = threading.Thread(target=serial_reader, daemon=True)
thread.start()

# ——— Flask app ——————————————————————————————————
app = Flask(__name__)
CORS(app)  # allow cross‐origin requests

@app.route('/api/joystick1', methods=['GET'])
def api_joystick():
    # Return the latest reading
    return jsonify(joystick_state)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5100, debug=False)