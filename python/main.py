import torch as T
import torch.nn as nn
import torch.nn.functional as F
import torch.optim as optim
import torch_directml as dml
import os
import numpy as np
import struct
import socket
import json
import random
import argparse
import glob

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

def get_latest_checkpoint():
    # Find the latest checkpoint file based on iteration number
    checkpoint_files = glob.glob("model_checkpoint_*.pt")
    if not checkpoint_files:
        return None
    
    # Extract iteration numbers from filenames
    iterations = [int(f.split("_")[-1].split(".")[0]) for f in checkpoint_files]
    latest_file = checkpoint_files[iterations.index(max(iterations))]
    return latest_file

def setup_connection():
    # Setup TCP connection with Godot
    TCP_IP = "127.0.0.1"
    TCP_PORT = 9876

    # Start a server
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    sock.bind((TCP_IP, TCP_PORT))

    # Listen for incoming connections
    sock.listen(1)
    print("Waiting for connection...")

    # Setup with godot
    conn, addr = sock.accept()
    print("Connection established with:", addr)

    # Flush godot as it sends state and reward first
    _discard = conn.recv(32)
    _discard = conn.recv(4096)
    
    return conn

def train_model():
    # Train the model 
    checkpointing = True
    num_iterations = 999_999_999

    # Model parameters
    n_observations = 49
    n_actions = 4

    # Hyperparameters
    lr = 1e-3
    gamma = 0.99
    epsilon = 1.0
    epsilon_decay = 0.9995
    epsilon_min = 0.01
    
    # Check if there's a checkpoint to resume from
    latest_checkpoint = get_latest_checkpoint()
    start_iteration = 0
    
    model = DQN(n_observations, n_actions).to(device)
    target_model = DQN(n_observations, n_actions).to(device)
    optimizer = optim.Adam(model.parameters(), lr=lr)
    
    if latest_checkpoint:
        print(f"Loading checkpoint: {latest_checkpoint}")
        checkpoint = T.load(latest_checkpoint)
        model.load_state_dict(checkpoint['model_state_dict'])
        optimizer.load_state_dict(checkpoint['optimizer_state_dict'])
        start_iteration = checkpoint['iteration'] + 1
        epsilon = checkpoint['epsilon']
    
    target_model.load_state_dict(model.state_dict())
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
    print(f"Starting from iteration: {start_iteration}")
    print("=" * 50)
    
    # Setup connection with Godot
    conn = setup_connection()
    
    for iteration in range(start_iteration, num_iterations):
        # Send ready
        conn.send("ready".encode())
        
        # Get state from godot
        data = conn.recv(4096)
        state_json = json.loads(data.decode())
        state_vals = list(state_json.values())
        state = T.tensor([state_vals], dtype=inType, device=device)

        # Epsilon-greedy action selection
        if random.random() < epsilon:
            action = random.randint(0, n_actions - 1)
        else:
            with T.no_grad():
                q_vals = model(state)
                action = int(T.argmax(q_vals, dim=1))
        
        # Send action to godot
        conn.send(action.to_bytes(1, byteorder='big'))

        # Get reward from godot
        reward = conn.recv(32)
        reward = struct.unpack('f', reward)[0]
        
        # Get next state from godot
        data = conn.recv(4096)
        state_json = json.loads(data.decode())
        state_vals = list(state_json.values())
        next_state = T.tensor([state_vals], dtype=inType, device=device)

        # Current Q value
        q_value = model(state)[0, action]
        
        # Target Q value computation
        with T.no_grad():
            next_q_vals = target_model(next_state)
            max_next_q = T.max(next_q_vals)
            target_q = reward + gamma * max_next_q
        
        loss = criterion(q_value, target_q)
        
        optimizer.zero_grad()
        loss.backward()
        optimizer.step()
        
        # Decay epsilon
        if epsilon > epsilon_min:
            epsilon *= epsilon_decay
        
        # Periodically update the target network
        if iteration % 100 == 0:
            target_model.load_state_dict(model.state_dict())
            print(f"Iteration {iteration}: Loss = {loss.item():.4f}, Epsilon = {epsilon:.4f}")

        if checkpointing:
            # Every 1000 iterations save model checkpoint
            if iteration % 1000 == 0 and iteration > 0:
                checkpoint_path = f"model_checkpoint_{iteration}.pt"
                T.save({
                    'iteration': iteration,
                    'model_state_dict': model.state_dict(),
                    'optimizer_state_dict': optimizer.state_dict(),
                    'loss': loss.item(),
                    'epsilon': epsilon
                }, checkpoint_path)
                print(f"Model checkpoint saved to {checkpoint_path}")

def play_model():
    """Run the model in play mode using the latest checkpoint."""
    n_observations = 49
    n_actions = 4
    
    latest_checkpoint = get_latest_checkpoint()
    if not latest_checkpoint:
        print("Error: No checkpoint found for play mode")
        return
    
    print(f"Loading checkpoint: {latest_checkpoint}")
    model = DQN(n_observations, n_actions).to(device)
    checkpoint = T.load(latest_checkpoint)
    model.load_state_dict(checkpoint['model_state_dict'])
    model.eval()  # Set to evaluation mode
    
    print("=" * 50)
    print("Play Mode")
    print(f"Using checkpoint: {latest_checkpoint}")
    print(f"Iteration: {checkpoint['iteration']}")
    print(f"Device: {device}")
    print("=" * 50)
    
    # Setup connection with Godot
    conn = setup_connection()
    
    while True:
        try:
            # Send ready
            conn.send("ready".encode())
            
            # Get state from godot
            data = conn.recv(4096)
            state_json = json.loads(data.decode())
            state_vals = list(state_json.values())
            state = T.tensor([state_vals], dtype=inType, device=device)

            # Get action using the trained model (no exploration)
            with T.no_grad():
                q_vals = model(state)
                action = int(T.argmax(q_vals, dim=1))
            
            # Send action to godot
            conn.send(action.to_bytes(1, byteorder='big'))

            # Receive reward and next state but don't use them for training
            _ = conn.recv(32)  # Reward
            _ = conn.recv(4096)  # Next state
            
        except (BrokenPipeError, ConnectionResetError):
            print("Connection lost. Exiting play mode.")
            break

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='DQN model runner')
    parser.add_argument('--mode', choices=['train', 'play'], default='train',
                        help='Mode to run the model: train (default) or play')
    
    args = parser.parse_args()
    
    if args.mode == 'train':
        print("Starting training mode")
        train_model()
    else:
        print("Starting play mode")
        play_model()