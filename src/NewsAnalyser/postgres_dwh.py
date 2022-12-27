import datetime

import psycopg2
from config import dwh_dbname,dwh_user,dwh_password,dwh_host

def save_post(title, link, text, category, source, tags):
    #category='www'
    sql='INSERT INTO "Stage".stage_posts (post_title, post_link, post_text, post_category, source_type) VALUES(\''\
        +title+'\',  \''+link+'\', \''+text+'\', \''+category+'\', \''+source+"');"
    conn = psycopg2.connect(dbname=dwh_dbname, user=dwh_user,
                            password=dwh_password, host=dwh_host)
    conn.autocommit = True
    cursor = conn.cursor()
    #cursor.execute(sql)
    cursor.execute('call "Stage".sp_add_stage_post(%s,%s,%s,%s,%s,%s)', (title, link, text, category, source, tags))
    cursor.close()

'''INSERT INTO "DDS".sources
("source")
 SELECT distinct source_type
FROM "Stage".stage_posts st
where st.source_type not in
  (select "source" from "DDS".sources);

 INSERT INTO "DDS".categories
(post_category, source_id)
   SELECT distinct post_category,ds.source_id
   FROM "Stage".stage_posts st
   join "DDS".sources ds on ds."source" =st.source_type
   except
   select  post_category, source_id from "DDS".categories;
'''
class News:
    def __init__(self):
        self.title=""
        self.date=datetime.date()
        self.link=""
        self.summary=""
        #self.




