FROM python:3.8

ENV PYTHONUNBUFFERED 1
RUN mkdir /code
WORKDIR /code
COPY requirements.txt /code/
RUN pip install -r requirements.txt
RUN pip install git+https://github.com/JVemmer/neomodel.git
# COPY . /code/