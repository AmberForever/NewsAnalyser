FROM python:3.10

RUN apt-get install -yqq --no-install-recommends \
    && pip install 'feedparser==6.0.10' \
    && pip install 'pandas==1.5.0'
    && pip install 'Scrapy==2.6.2' \

WORKDIR /app

ADD main.py main.py
ADD utils.py utils.py
ADD config.py config.py
ADD user_agents.py user_agents.py
ADD rss_parser.py rss_parser.py
ADD postgres_dwh.py postgres_dwh.py