# Slim Debian-based Python image (much smaller than python:3.12)
FROM python:3.12-slim

# Do not write .pyc files and do not buffer stdout (logs show up immediately)
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# Install dependencies first (cached layer while requirements.txt is unchanged)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the application code
COPY app.py .

EXPOSE 5000

CMD ["python", "app.py"]
