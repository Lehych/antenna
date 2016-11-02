FROM python:3.5.2-slim

WORKDIR /app/
RUN groupadd --gid 1001 app && useradd -g app --uid 1001 --shell /usr/sbin/nologin app

RUN apt-get update && \
    apt-get install -y gcc apt-transport-https

COPY ./requirements.txt /app/requirements.txt

RUN pip install -U 'pip>=8' && \
    pip install --no-cache-dir -r requirements.txt

# Install the app
COPY . /app/

# Set Python-related environment variables to reduce annoying-ness
ENV PYTHONUNBUFFERED 1
ENV PYTHONDONTWRITEBYTECODE 1
ENV PORT 8000

USER app
EXPOSE $PORT

CMD gunicorn \
    --workers=1 \
# only 1?
    --worker-connections=4 \
    --worker-class=gevent \
    --bind 0.0.0.0:$PORT \
    antenna.wsgi:application
