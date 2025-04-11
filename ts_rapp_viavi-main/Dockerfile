FROM python:3.10.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install -r /app/requirements.txt

COPY main.py .
COPY rapp/ rapp
#USER nonroot
ENTRYPOINT ["python", "main.py"]
