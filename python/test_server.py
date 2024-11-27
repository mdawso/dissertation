import socket, time, random, json

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
data = conn.recv(1024).decode()
print("Received data: ", data)

# this is just a test that randomly moves the ai
while True:
    
    #recieve data
    recievedData = conn.recv(4096).decode()
    recievedDataDecoded = json.loads(recievedData)
    
    distToFinishLine : float = recievedDataDecoded["distToFinishLine"]
    finishLineVisible : bool = recievedDataDecoded["finishLineVisible"]
    visibleTiles : dict = recievedDataDecoded["visibleTiles"]
    
    #send data
    data = {"direction": random.choice(["none", "left", "right"]), "jump": random.choice([True, False])}
    jsonData = json.dumps(data) + "|"
    conn.send(jsonData.encode())
    print("Sent data: ", data)

conn.close()