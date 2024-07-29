# PFA-Model

## Overview

This repository is part of our end-of-year project (Projet Fin d'Année - PFA) titled "Deep Reinforcement Learning for Edge Kubernetes Load Optimization." It includes the model and related files necessary for the optimization of load distribution in Kubernetes clusters deployed at edge locations.

## Project Description

In this project, we aim to optimize load distribution in Kubernetes clusters deployed at edge locations using Deep Reinforcement Learning (DRL). Our approach dynamically adjusts resource allocation in real-time to respond to fluctuating demands and network conditions. We developed a custom simulation environment to train and validate our models, achieving significant improvements in resource utilization and response time compared to traditional load balancing methods.

## Structure

- `model/`: Directory containing the trained DRL model
- `Dockerfile`: Dockerfile for building the model container
- `app.yaml`: Application deployment configuration
- `prometheus/`: Prometheus configuration files
- `grafana/`: Grafana dashboard configurations
- `scripts/`: Various scripts for setup and execution
- `start.sh`: Shell script to start the application with the model

## Getting Started

### Prerequisites

- Docker
- K3d
- Prometheus
- Grafana

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/chaimaraachh/PFA-Model.git


2. Use the start.sh script to initiate the setup:
   ```bash
    ./start.sh
