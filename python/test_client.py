import socket

UDP_IP = "127.0.0.1"
UDP_PORT = 9876

# connect to the server
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.connect((UDP_IP, UDP_PORT))

def receive_and_print():
    # recieve messages from server
    data, addr = sock.recvfrom(1024)
    print("Received message: ", data.decode())

def send_and_print(message):
    # send messages to server
    sock.send(message)
    print("Sent message: ", message)

# send a message
send_and_print("Python Handshake".encode())

# receive a message
receive_and_print()

# close the connection
sock.close()