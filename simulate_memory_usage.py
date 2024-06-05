import numpy as np
import random
import time
import os
import requests
import uuid

class Pod:
    def __init__(self, name, namespace, seed, tw_mean=35, tp_mean=50, um_mean=0.5, duration=200, start_time=0, variability=0.4):
        self.name = name
        self.namespace = namespace
        self.seed = seed
        self.tw_mean = tw_mean  # Average active time
        self.tp_mean = tp_mean  # Period of repetition
        self.um_mean = um_mean  # Utilization mean
        self.duration = duration  # Total duration to simulate
        self.start_time = start_time
        self.variability = variability  # Variability as a fraction of the parameter
        self.activity = self.generate_activity()

    def generate_activity(self):
        random.seed(self.seed)
        up_time = self.duration - self.start_time
        time_series = np.linspace(0, up_time, num=int(up_time))
        activity = np.zeros_like(time_series)

        for period_start in np.arange(0, up_time, self.tp_mean):
            tw_variation = random.uniform(-1, 1) * self.variability * self.tw_mean
            tp_variation = random.uniform(-1, 1) * self.variability * self.tp_mean
            um_variation = random.uniform(-1, 1) * self.variability * self.um_mean

            tw = self.tw_mean + tw_variation
            tp = self.tp_mean + tp_variation
            um = self.um_mean + um_variation

            period_end = period_start + tw
            rising_end = period_start + tw * 0.2
            falling_start = period_end - tw * 0.2
            end = min(period_end, up_time)

            # Rising phase
            rising_indices = np.where((time_series >= period_start) & (time_series < rising_end))[0]
            rising_time = time_series[rising_indices] - period_start
            rising_activity = rising_time / np.max(rising_time)

            activity[rising_indices] = rising_activity

            # Falling phase
            falling_indices = np.where((time_series >= falling_start) & (time_series < end))[0]
            if falling_indices.size > 0:  # Check if falling_indices is not empty
                falling_time = time_series[falling_indices] - falling_start
                falling_activity = 1 - falling_time / np.max(falling_time)
                activity[falling_indices] = falling_activity

        # Normalize the activity to the utilization mean
        activity *= self.um_mean / np.max(activity)
        
        # Empty activity head
        empty_activity = [0] * self.start_time
        if len(empty_activity) != 0:
            total_activity = empty_activity + list(activity)
            return total_activity
        else:
            return activity

    def simulate_memory_usage(self):
        for usage in self.activity:
            self.stress_memory(int(usage * 100))  # Adjust size as needed
            time.sleep(1)  # Sleep to simulate time progression

    def stress_memory(self, size_mb):
        url = f"http://{self.name}.{self.namespace}.svc.cluster.local:3000/service/stress?size={size_mb}"
        try:
            response = requests.get(url)
            if response.status_code == 200:
                print(f"Successfully stressed pod {self.name} with {size_mb} MB")
            else:
                print(f"Failed to stress pod {self.name}: {response.status_code}")
        except requests.exceptions.RequestException as e:
            print(f"Request to {self.name} failed: {e}")

if __name__ == "__main__":
    pod_name = os.getenv("POD_NAME", "your-pod-name")  # Replace with the actual pod name
    namespace = os.getenv("NAMESPACE", "your-namespace")  # Replace with the actual namespace
    seed = os.getenv("SEED", str(uuid.uuid4()))
    pod = Pod(name=pod_name, namespace=namespace, seed=seed)
    pod.simulate_memory_usage()
