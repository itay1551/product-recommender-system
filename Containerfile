# ---------- Frontend Build ----------
FROM registry.access.redhat.com/ubi9/nodejs-22 AS frontend-builder

USER root

WORKDIR /app/frontend

# Copy only package files first to leverage Docker cache
COPY frontend/package*.json ./

RUN npm install --debug

# Now copy the rest of the frontend code
COPY frontend/ ./

# Set node memory limit if needed
ENV NODE_OPTIONS=--max-old-space-size=512

RUN npm run build

# ---------- Backend Build ----------
FROM registry.access.redhat.com/ubi9/python-312

USER root
WORKDIR /app/

RUN dnf update -y
RUN dnf install -y nmap-ncat && dnf clean all

RUN pip3 install uv
COPY pyproject.toml pyproject.toml
RUN uv pip install -r pyproject.toml

# Copy the rest of the app
# Copy backend and install dependencies
COPY backend/ ./backend/
COPY frontend/src/assets/ ./backend/public/assets

# Copy built frontend to backend's static files
COPY --from=frontend-builder /app/frontend/dist ./backend/public/

RUN chmod -R +r . && ls -la

ENV HF_HOME=/hf_cache
RUN mkdir -p /hf_cache && \
    chmod -R 777 /hf_cache

USER 1001

# Expose FastAPI port
EXPOSE 8000
ENTRYPOINT ["uvicorn", "backend.main:app", "--host", "0.0.0.0", "--port", "8000"]