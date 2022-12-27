import random
import asyncio
import feedparser
import requests

from utils import random_user_agent_headers


def rss_parser( source, rss_link, posted_q,
               timeout=2,
               send_dwh_func=None, logger=None):
    # Парсер rss ленты
    # source - ссылка на новостной сайт
    # rss_link - ссылка на RSS канал
    # posted_q - очередь на запись в БД (для ассинхронной работы, пока не реализовано)
    # timeout - таймаут для дозвона в ленту
    # send_dwh_func - функция записи поста в ДВХ
    # logger - функция логирования
    f=True  # флаг удачной закачки ленты
    cnt=0 #количество попыток закачать ленту
    while f or cnt>10: # пытаемся достучаться до ленты 10 раз, не больше, чтобы не уйти в бесконечный цикл
        try:
            response = requests.get(rss_link, headers=  random_user_agent_headers())
        except Exception as e:
            if not (logger is None):
                logger.error(f'{source} rss error pass\n{e}') # пишем о неудачной попытке подключения в лог

            asyncio.sleep(timeout * 2 - random.uniform(0, 0.5))
            continue

        feed = feedparser.parse(response.text) # парсим ленту

        for entry in feed.entries:
            if 'summary' not in entry and 'title' not in entry:
                continue

            summary = entry['summary'] if 'summary' in entry else ''
            title = entry['title'] if 'title' in entry else ''

            news_text = f'{title}\n{summary}'

            tags = entry['tags'] if 'tags' in entry else ['']
            tags_str = ''
            for tag in tags:
                if tags_str != '':
                    tags_str += '|'
                tags_str += tag['term']
            category = entry['category'] if 'category' in entry else ''
            if category == '':
                category = tags_str
            pubDate = entry['pubDate'] if 'pubDate' in entry else ''

            link = entry['link'] if 'link' in entry else ''

            post = f'<b>{source}</b>\n{link}\n{news_text}'

            if send_dwh_func is None:
                print(post, '\n')
            else:
                send_dwh_func(title, link, news_text, category, source, tags_str)

        f=False

