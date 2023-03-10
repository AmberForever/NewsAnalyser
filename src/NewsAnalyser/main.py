import asyncio
from collections import deque
from rss_parser import rss_parser
from utils import create_logger
from postgres_dwh import save_post, make_dds_and_marts

from config import rss_channels


def send_dwh_func(title, link, text, category, post_source,tags):
    '''Отправляет посты в БД'''
    logger.info(text)
    save_post(title, link, text, category, post_source,tags)

# Количество уже опубликованных постов, чтобы их не повторять
amount_messages = 50
# Очередь уже опубликованных постов для реализации ассинхронности
posted_q = deque(maxlen=amount_messages)
# +/- интервал между запросами у парсеров в секундах
timeout = 2


logger = create_logger('NewsAnalyser')
logger.info('Start...')

loop = asyncio.new_event_loop()
asyncio.set_event_loop(loop)

#if __name__ == '__main__':

# обрабатываем каналы и сохраняем публикации в базу данных
for source, rss_link in rss_channels.items():
    rss_parser(source, rss_link, posted_q,  timeout, send_dwh_func, logger)
# после закачки всех постов в stage формируем DDS и витрину
make_dds_and_marts()
