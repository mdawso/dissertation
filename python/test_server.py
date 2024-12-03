import socket, time, random, json

TCP_IP = "127.0.0.1"
TCP_PORT = 9876

# start a server
sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1) # allow the port to be reused immediately after the server is killed
sock.bind((TCP_IP, TCP_PORT))

# listen for incoming connections
sock.listen(1)

# keep trying until a connection is established
print("Waiting for connection...")

conn, addr = sock.accept()
print("Connection established with: ", addr)

while True:

    # send a ready message to signal the python script is ready
    conn.send("ready".encode())

    # first we wait for godot to send an observation
    observation = conn.recv(4096)
    observation = json.loads(observation.decode())
    print("Received observation: ", observation)

    # then we send an action
    action = random.choice([0, 1, 2])
    print("Sending action: ", action)
    conn.send(action.to_bytes(1, byteorder='big'))

    # finally we wait for the reward
    reward = conn.recv(8)
    reward = int.from_bytes(reward, byteorder='big')
    print("Received reward: ", reward)

# close the connection
conn.close()