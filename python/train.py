import torch as T # for the neural network
import torch.nn as nn # for the neural network
import torch.nn.functional as F # for the activation functions
import torch.optim as optim # for the optimizer
import torch_directml as dml

import numpy as np # for the replay buffer

import struct # for converting bytes to floats
import socket # for connecting to the server
import json # for parsing the server's response
import random # for generating random actions

# pytorch setup
device = T.device("cuda" if T.cuda.is_available() else dml.device())
inType = T.float32

# model definition
class DQN(nn.Module):
    
    def __init__(self, n_observations, n_actions):
        super(DQN, self).__init__()
        # Reshape the input for Conv2D
        self.input_dim = int(np.sqrt(n_observations))
        
        # Convolutional layer
        self.conv1 = nn.Conv2d(1, 16, kernel_size=3, stride=1, padding=1)
        
        # Calculate the size after convolution for the fully connected layer
        conv_output_size = 16 * self.input_dim * self.input_dim
        
        self.fc1 = nn.Linear(conv_output_size, 128)
        self.fc2 = nn.Linear(128, 128)
        self.fc3 = nn.Linear(128, n_actions)
        
    def forward(self, x):
        # Reshape input to [batch_size, channels, height, width]
        batch_size = x.size(0)
        x = x.view(batch_size, 1, self.input_dim, self.input_dim)
        
        # Apply convolution and activation
        x = F.relu(self.conv1(x))
        
        # Flatten for fully connected layers
        x = x.view(batch_size, -1)
        
        x = F.relu(self.fc1(x))
        x = F.relu(self.fc2(x))
        x = self.fc3(x)
        return x

# now we use the observation, action, and reward to train the neural network
# we will use the DQN algorithm to train the neural network

num_iterations = 999_999_999

# model parameters
n_observations = 49
n_actions = 4

# hyperparameters
lr = 1e-3
gamma = 0.99
epsilon = 1.0
epsilon_decay = 0.9995
epsilon_min = 0.01

model = DQN(n_observations, n_actions).to(device)
target_model = DQN(n_observations, n_actions).to(device)
target_model.load_state_dict(model.state_dict())
optimizer = optim.Adam(model.parameters(), lr=lr)
criterion = nn.MSELoss()

print("=" * 50)
print("PyTorch Setup:")
print(f"Device: {device}")
print("\nModel Architecture:")
print(model)
print("\nHyperparameters:")
print(f"Learning rate: {lr}")
print(f"Discount factor (gamma): {gamma}")
print(f"Starting epsilon: {epsilon}")
print(f"Epsilon decay rate: {epsilon_decay}")
print(f"Minimum epsilon: {epsilon_min}")
print(f"Loss function: {criterion}")
print(f"Optimizer: {optimizer.__class__.__name__}")
print(f"Input dimensions: {n_observations}")
print(f"Output dimensions (actions): {n_actions}")
print("=" * 50)

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

# setup with godot
conn, addr = sock.accept()
print("Connection established with: ", addr)

# flush godot as it sends state and reward first, we can discard this
_discard = conn.recv(32)
_discard = conn.recv(4096)

for iteration in range(num_iterations):

    # send ready
    conn.send("ready".encode())

    # simulate the current state as a random tensor
    # state = T.randn((1, n_observations), device=device)
    
    # get state from godot
    data = conn.recv(4096)
    state_json = json.loads(data.decode())
    state_vals = list(state_json.values())
    state = T.tensor([state_vals], dtype=inType, device=device)

    # epsilon-greedy action selection
    if random.random() < epsilon:
        action = random.randint(0, n_actions - 1)
    else:
        with T.no_grad():
            q_vals = model(state)
            action = int(T.argmax(q_vals, dim=1))
    
    # send action to godot
    conn.send(action.to_bytes(1, byteorder='big'))

    # simulate next state, reward
    # next_state = T.randn((1, n_observations), device=device)
    
    # get next state from godot

    # get reward from godot
    reward = conn.recv(32)
    reward = struct.unpack('f', reward)[0]
    #if reward < -1 or reward > 1: print(reward)
    
    # get next state from godot
    data = conn.recv(4096)
    state_json = json.loads(data.decode())
    state_vals = list(state_json.values())
    next_state = T.tensor([state_vals], dtype=inType, device=device)

    # current Q value
    q_value = model(state)[0, action]
    
    # target Q value computation
    with T.no_grad():
        next_q_vals = target_model(next_state)
        max_next_q = T.max(next_q_vals)
        target_q = reward + gamma * max_next_q
    
    loss = criterion(q_value, target_q)
    
    optimizer.zero_grad()
    loss.backward()
    optimizer.step()
    
    # decay epsilon
    if epsilon > epsilon_min:
        epsilon *= epsilon_decay
    
    # periodically update the target network
    if iteration % 100 == 0:
        target_model.load_state_dict(model.state_dict())
        print(f"Iteration {iteration}: Loss = {loss.item():.4f}, Epsilon = {epsilon:.4f}")