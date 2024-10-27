import socket

TCP_IP = "127.0.0.1"
TCP_PORT = 9876

# start a server
sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
sock.bind((TCP_IP, TCP_PORT))

# listen for incoming connections
sock.listen(1)

# keep trying until a connection is established
print("Waiting for connection...")
conn, addr = sock.accept()
print("Connection established with: ", addr)

# receive data from the client
while True:
    data = conn.recv(1024)
    if data:
        print("Received data: ", data.decode())

# send data to the client
conn.send("Hello from server!".encode())

# close the connection
conn.close()