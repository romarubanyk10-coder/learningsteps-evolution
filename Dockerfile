# Base image: Debian Linux "slim" with Python 3.13 already installed
FROM python:3.13-slim

# Python settings: no .pyc cache files, print logs immediately
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Install security updates for the Linux packages in the base image
RUN apt-get update \
    && apt-get upgrade -y \
    && rm -rf /var/lib/apt/lists/*

# A normal user without admin rights: the app will run as this user
RUN useradd --create-home --uid 10001 appuser

# All following commands work inside the folder /app
WORKDIR /app

# 1) Libraries first: this layer is reused while requirements.txt does not change
COPY app/requirements.txt .
RUN pip install --no-cache-dir --requirement requirements.txt

# 2) Then the application code
COPY app/ .

# From here on, run as the normal user, not as root
USER appuser

# Documentation: the app listens on port 8000
EXPOSE 8000

# Docker checks every 30 s that /health answers
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health')" || exit 1

# Start the web server (0.0.0.0 = accept connections from outside the container)
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]