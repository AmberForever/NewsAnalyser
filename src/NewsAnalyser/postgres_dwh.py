import datetime

import psycopg2
from config import dwh_dbname, dwh_user, dwh_password, dwh_host, dwh_DDS_dbname, dwh_DDS_user, dwh_DDS_password, dwh_DDS_host

# функция сохранения поста
def save_post(title, link, text, category, source, tags):
    # category='www'
    sql = 'INSERT INTO "Stage".stage_posts (post_title, post_link, post_text, post_category, source_type) VALUES(\'' \
          + title + '\',  \'' + link + '\', \'' + text + '\', \'' + category + '\', \'' + source + "');"
    conn = psycopg2.connect(dbname=dwh_dbname, user=dwh_user,
                            password=dwh_password, host=dwh_host)
    conn.autocommit = True
    cursor = conn.cursor()
    # cursor.execute(sql)
    cursor.execute('call "Stage".sp_add_stage_post(%s,%s,%s,%s,%s,%s)', (title, link, text, category, source, tags))
    cursor.close()

# функция вызова процедуры формирования детального слоя и витрины
def make_dds_and_marts():
    conn = psycopg2.connect(dbname=dwh_DDS_dbname, user=dwh_DDS_user,
                            password=dwh_DDS_password, host=dwh_DDS_host)
    conn.autocommit = True
    cursor = conn.cursor()
    cursor.execute('CALL "DDS".sp_make_dds_and_marts();')
    cursor.close()
