# Build your own fast, multi-user Jupyter and Pluto server

These are the accompanying files for the JuliaCon 2021 poster "Build your own fast, multi-user Jupyter and Pluto server", as well as a short tutorial on how to get your server up and running.

## Set up the server

The first step is setting up the server:

1. Start from a clean debian 10 installation
2. Install `nginx`, `docker.io`, `npm` and `python3-pip`
3. Use pip to install `jupyterhub` and `dockerspawner`
4. Use npm to install `configurable-http-proxy`

To configure NGINX, we can follow the guidelines from the JupyterHub documentation and place a file like this for host `myserver.com` in `/etc/nginx/conf.d/`:

```nginx
server {
    listen 80;
    server_name  myserver.com;
    return 301 https://myserver.com$request_uri;
}

server {
    listen       443 ssl http2 default_server;
    listen       [::]:443 ssl http2 default_server;
    server_name  myserver.com;
    root         /usr/share/nginx/html;
    client_max_body_size 100m;

    ssl_certificate "/etc/letsencrypt/live/myserver.com/fullchain.pem";
    ssl_certificate_key "/etc/letsencrypt/live/myserver.com/privkey.pem";
    ssl_session_cache shared:SSL:1m;
    ssl_session_timeout  10m;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

        # websocket headers
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
    }

    # Managing WebHook/Socket requests between hub user servers and external proxy
    location ~* /(api/kernels/[^/]+/(channels|iopub|shell|stdin)|terminals/websocket)/? {
        proxy_pass http://127.0.0.1:8000;

        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

    }
}

```

## Configure jupyterhub

To configure jupyterhub, place the sample [`jupyterhub_config.py`](jupyterhub_config.py) in any directory (e.g. `/jupyterhub`). Relevant configuration to look out for is the authentication mechanism and the spawner. Here we use [Native Authenticator](https://github.com/jupyterhub/nativeauthenticator).

From within the directory containing the config file, the server can be started by simply running `jupyterhub`. To automate things using systemd, create `/etc/systemd/system/jupyterhub.service` wit the following contents:

```systemd
[Unit]
Description=Jupyterhub

[Service]
ExecStart=/usr/local/bin/jupyterhub
WorkingDirectory=/jupyterhub

[Install]
WantedBy=multi-user.target
```

Then enable and start the service using:

```bash
systemctl daemon-reload
systemctl enable jupyterhub
systemctl start jupyterhub
```

## Adjust the Docker file

Included in this repository is a sample [`Dockerfile`](Dockerfile) that runs the single-user server. This currently installs Julia with some packages, a custom sysimage and Pluto.
