import socket

UDP_IP = "127.0.0.1"
UDP_PORT = 9876

# connect to the server
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.connect((UDP_IP, UDP_PORT))

# send a message
sock.send("Python Handshake".encode())

while True:
    try:
        # receive a message
        data, addr = sock.recvfrom(1024)
        print("Received message: ", data.decode())
    except KeyboardInterrupt:
        break

# close the connection
sock.close()

