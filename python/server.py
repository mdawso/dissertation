import socket, time, random, json
import model

TCP_IP = "127.0.0.1"
TCP_PORT = 9876

# start a server
sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
sock.bind((TCP_IP, TCP_PORT))

# listen for incoming connections
sock.listen(1)

# keep trying until a connection is established
print("Waiting for connection...")

# initial handshake
conn, addr = sock.accept()
print("Connection established with: ", addr)
data = conn.recv(1024).decode()
print("Received data: ", data)

# recieve starting data from client