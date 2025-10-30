# Use a lightweight Python base image
FROM python:3.10-alpine

# Set the working directory inside the container
WORKDIR /app

# Copy the requirements file first to leverage Docker cache
COPY requirements.txt .

# Install the Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy the main watcher script
COPY watcher.py .

# Command to run the script
# -u = unbuffered output, so we see logs in real-time
CMD ["python", "-u", "watcher.py"]
