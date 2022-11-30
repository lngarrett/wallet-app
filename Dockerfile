# syntax=docker/dockerfile:1

FROM python:3.8-slim-buster

WORKDIR /python-docker

COPY requirements.txt requirements.txt
RUN pip3 install -r requirements.txt

COPY . .
# ENV FLASK_APP=run.py
ENTRYPOINT [ "python" ]
CMD [ "run.py" ]