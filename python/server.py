import torch as T
import torch.nn as nn
import torch.nn.functional as F
import torch.optim as optim

import socket
import json
import random

# model definition
class DQN(nn.Module):
    
    def __init__(self, n_observations, n_actions):
        super(DQN, self).__init__()
        self.fc1 = nn.Linear(n_observations, 128)
        self.fc2 = nn.Linear(128, 128)
        self.fc3 = nn.Linear(128, n_actions)
        
    def forward(self, x):
        x = F.relu(self.fc1(x))
        x = F.relu(self.fc2(x))
        x = self.fc3(x)
        return x

# hyperparameters
#
#

TCP_IP = "127.0.0.1"
TCP_PORT = 9876

# start a server
sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
sock.bind((TCP_IP, TCP_PORT))

# listen for incoming connections
sock.listen(1)

# keep trying until a connection is established
print("Waiting for connection...")

# setup with godot
conn, addr = sock.accept()
print("Connection established with: ", addr)

data = json.loads(conn.recv(1024).decode())

numOfObservations = data["numOfObservations"]
numOfActions = data["numOfActions"]

print("Number of observations: ", numOfObservations)
print("Number of actions: ", numOfActions)
