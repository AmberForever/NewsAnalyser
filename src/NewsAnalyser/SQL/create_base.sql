CREATE SCHEMA "Stage" AUTHORIZATION postgres;
CREATE TABLE "Stage".stage_posts (
	id int4 NOT NULL GENERATED BY DEFAULT AS IDENTITY,
	post_title varchar NOT NULL,
	published_date date NOT NULL DEFAULT CURRENT_DATE,
	update_timestamp timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
	post_link varchar NOT NULL,
	post_text varchar NULL,
	post_category varchar NULL,
	source_type varchar NOT NULL,
	post_tags varchar NULL,
	CONSTRAINT stage_posts_pkey PRIMARY KEY (id)
);

CREATE SCHEMA "DDS" AUTHORIZATION postgres;
CREATE TABLE "DDS".sources (
	source_id int4 NOT NULL GENERATED ALWAYS AS IDENTITY,
	"source" varchar NULL,
	rss_link varchar NULL,
	CONSTRAINT sources_pkey PRIMARY KEY (source_id)
);
CREATE TABLE "DDS".categories (
	post_category varchar NOT NULL,
	category_id int4 NOT NULL GENERATED ALWAYS AS IDENTITY,
	source_id int4 NOT NULL,
	category varchar NULL,
	CONSTRAINT categories_pkey PRIMARY KEY (category_id)
);
CREATE INDEX "fki_IX_category_source" ON "DDS".categories USING btree (source_id);
CREATE TABLE "DDS".posts (
	id int4 NOT NULL GENERATED BY DEFAULT AS IDENTITY,
	post_title varchar NOT NULL,
	published_date date NOT NULL DEFAULT CURRENT_DATE,
	update_timestamp timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
	post_link varchar NOT NULL,
	post_text varchar NULL,
	source_id int4 NOT NULL,
	last_stage_id int4 NOT NULL,
	CONSTRAINT dds_posts_pkey PRIMARY KEY (id)
);
CREATE INDEX "fki_IX_post_source" ON "DDS".posts USING btree (source_id);


-- "DDS".posts foreign keys

ALTER TABLE "DDS".posts ADD CONSTRAINT "IX_post_source" FOREIGN KEY (source_id) REFERENCES "DDS".sources(source_id);
CREATE TABLE "DDS".post_category (
	post_id int8 NOT NULL,
	category_id int8 NOT NULL,
	CONSTRAINT post_category_pkey PRIMARY KEY (post_id, category_id)
);
CREATE INDEX "fki_IX_post_category_category" ON "DDS".post_category USING btree (category_id);
CREATE INDEX "fki_IX_post_category_post" ON "DDS".post_category USING btree (post_id);

-- "DDS".post_category foreign keys
ALTER TABLE "DDS".post_category ADD CONSTRAINT "IX_post_category_category" FOREIGN KEY (category_id) REFERENCES "DDS".categories(category_id);
ALTER TABLE "DDS".post_category ADD CONSTRAINT "IX_post_category_post" FOREIGN KEY (post_id) REFERENCES "DDS".posts(id);

CREATE TABLE "DDS".categories_unique (
	id int4 NOT NULL GENERATED BY DEFAULT AS IDENTITY,
	category_uniq varchar NULL
);

CREATE SCHEMA "Marts" AUTHORIZATION postgres;
CREATE TABLE "Marts".mart_1 (
	id int8 NOT NULL GENERATED BY DEFAULT AS IDENTITY,
	mart_date date NOT NULL DEFAULT CURRENT_DATE,
	category_id int4 NOT NULL,
	category_name varchar NOT NULL,
	source_id int4 NOT NULL,
	source_name varchar NULL,
	all_time_count int4 NULL,
	last_day_count int4 NULL,
	avrg_count_per_day int4 NULL,
	max_count_day date NULL,
	monday_count int4 NULL,
	tuesday_count int4 NULL,
	wednesday_count int4 NULL,
	thursday_count int4 NULL,
	friday_count int4 NULL,
	saturday_count int4 NULL,
	sunday_count int4 NULL
);


CREATE OR REPLACE PROCEDURE "Stage".sp_add_stage_post(IN title character varying, IN link character varying, IN text character varying, IN category character varying, IN source character varying, IN tags character varying)
 LANGUAGE plpgsql
AS $procedure$
begin
	   if not exists (select id  from "Stage".stage_posts where post_link=link and source_type=source and published_date=CURRENT_DATE) then
       INSERT INTO "Stage".stage_posts (post_title, post_link, post_text, post_category, source_type,post_tags)  values (title,link,text,category,source, tags);
       END IF;
	END;
$procedure$
;



CREATE OR REPLACE PROCEDURE "DDS".sp_make_dds_and_marts()
 LANGUAGE plpgsql
AS $procedure$
begin
--?????????????????? ?????????? ?????????????????? ?? ?????????????? ???????????????????? ???? Stage
INSERT INTO "DDS".sources
("source")
 SELECT distinct source_type
FROM "Stage".stage_posts st
where st.source_type not in
  (select "source" from "DDS".sources);

 --?????????????????? ?????????? ?????????????????? ?? ?????????????? ?????????????????? ???? Stage
 INSERT INTO "DDS".categories
(post_category, source_id)
   SELECT distinct post_category,ds.source_id
   FROM "Stage".stage_posts st
   join "DDS".sources ds on ds."source" =st.source_type
   except
   select  post_category, source_id from "DDS".categories;

  --?????? ?????????? ?????????????????? ?????????????????????? ???????????????????????? ???????????????? ???????????? ???????????????? ???? ??????????????????
update "DDS".categories set category=post_category where category is null;

--?????????????????? ?????????? ???????????????????? ???????????????? ?????????????????? ?? ?????????????? ???????????????????? ??????????????????
INSERT INTO "DDS".categories_unique
(category_uniq)
select category from "DDS".categories where category not in (select category_uniq from "DDS".categories_unique);

--?????????????????? ?????????? ?? DDS, ???????????????? ?? ?????? ???????????? ???? ????????????????????, ??????????????????
INSERT INTO "DDS".posts
(post_title, published_date,  post_link, post_text, source_id, last_stage_id)
  SELECT  st.post_title ,st.published_date , st.post_link , st.post_text , ds.source_id , st.id
   FROM "Stage".stage_posts st
   join "DDS".sources ds on ds."source" = st.source_type
   join "DDS".categories cat on cat.post_category = st.post_category
where st.id not in (select last_stage_id FROM "DDS".posts );

--?????????????????? ?? DDS ???????????????? ????????-?????????????????? (???????? ???????? ?????????? ?????????? ?????????? ?????????????????? ??????????????????)
INSERT INTO "DDS".post_category
(post_id, category_id)
  select post.id,cat.category_id  from (SELECT  st.id, unnest( string_to_array(st.post_tags,'|')) as tag FROM "Stage".stage_posts st) as ss
   join "DDS".categories cat on cat.post_category = ss.tag
   join "DDS".posts post on post.last_stage_id = ss.id
 except  select post_id, category_id from "DDS".post_category;


--?????????????? ?????????????????? ?????????????? ?????????????????? - ??????-???? ???????????? ???? ???????? ?????? ???????????????????? ??????????????????
--???? ?????????????? ?????????????? ????, ???????? ?????? ????????
DROP TABLE IF EXISTS tmp_table;

    CREATE temp TABLE tmp_table AS
select       -1 as source_id,
        '??????????' as source,
        cu.id   as category_id,
        cat.category ,
        count(post.id) as AllTime ,
        post.published_date  as date,
        extract(dow from post.published_date) as wd
from "DDS".posts post
join "DDS".post_category pc on pc.post_id = post.id
join "DDS".categories cat on cat.category_id = pc.category_id
join "DDS".sources src on src.source_id = post.source_id
join "DDS".categories_unique cu on cu.category_uniq =cat.category
group by cat.category, cu.id, post.published_date
union
--??????-???? ???? ?????????????? ?????????????????? ???? ?????? ??????????
select src.source_id as source_id ,
       src."source"  as source,
       cu.id as category_id,
       cat.category ,
       count(post.id) as AllTime ,
       post.published_date  as date,
       extract(dow from post.published_date) as wd
from "DDS".posts post
join "DDS".post_category pc on pc.post_id = post.id
join "DDS".categories cat on cat.category_id = pc.category_id
join "DDS".sources src on src.source_id = post.source_id
join "DDS".categories_unique cu on cu.category_uniq =cat.category
group by cu.id, cat.category, src."source", src.source_id, post.published_date;

--???????????????? ?????????????????? ??????????????. ?????????????? ???????????? ?????????????? ????????
delete from  "Marts".mart_1 where mart_date=CURRENT_DATE;
--?????????????????? ?????????? ???????????? ?? ???? ?????? ??????????
INSERT INTO "Marts".mart_1
(mart_date, source_id, source_name,category_id, category_name,  all_time_count)
--??????-???? ???? ???????? ???????????????????? ???? ?????? ??????????
select  CURRENT_DATE as mart_date,
        -1 as source_id,
        '??????????' as source,
        cu.id   as category_id,
        cat.category ,
        count(post.id) as AllTime
from "DDS".posts post
join "DDS".post_category pc on pc.post_id = post.id
join "DDS".categories cat on cat.category_id = pc.category_id
join "DDS".sources src on src.source_id = post.source_id
join "DDS".categories_unique cu on cu.category_uniq =cat.category
group by cat.category, cu.id
union
--??????-???? ???? ?????????????? ?????????????????? ???? ?????? ??????????
select CURRENT_DATE as mart_date,
       src.source_id as source_id ,
       src."source"  as source,
       cu.id as category_id,
       cat.category ,
       count(post.id) as AllTime
from "DDS".posts post
join "DDS".post_category pc on pc.post_id = post.id
join "DDS".categories cat on cat.category_id = pc.category_id
join "DDS".sources src on src.source_id = post.source_id
join "DDS".categories_unique cu on cu.category_uniq =cat.category
group by cu.id, cat.category, src."source", src.source_id;

--?????????????????? ???????????? ???? ???????????????????? ???? ?????????????????? ????????
update "Marts".mart_1 mr set last_day_count=d.last_day_count
from
--??????-???? ???? ?????????????? ?????????????????? ???? ?????????????????? ??????????
(select src.source_id as source_id ,
       src."source"  as source,
       cu.id as category_id,
       cat.category ,
        0 as AllTime ,
        count(post.id) as last_day_count
from "DDS".posts post
join "DDS".post_category pc on pc.post_id = post.id
join "DDS".categories cat on cat.category_id = pc.category_id
join "DDS".sources src on src.source_id = post.source_id
join "DDS".categories_unique cu on cu.category_uniq =cat.category
where post.published_date =current_date
group by cu.id, cat.category, src."source", src.source_id
union
--??????-???? ???? ?????????????????? ?????????? ???? ???????? ????????????????????
select -1 as source_id ,
       '??????????' as source,
       cu.id as category_id,
       cat.category ,
        0 as AllTime ,
        count(post.id) as last_day_count
from "DDS".posts post
join "DDS".post_category pc on pc.post_id = post.id
join "DDS".categories cat on cat.category_id = pc.category_id
join "DDS".sources src on src.source_id = post.source_id
join "DDS".categories_unique cu on cu.category_uniq =cat.category
where post.published_date =current_date
group by cu.id, cat.category
) d where d.source_id=mr.source_id and d.category_id=mr.category_id and mr.mart_date = current_date;

--?????????????????? ???????????? ???? ?????? ?? ???????????????????????? ??????-?????? ????????????
update "Marts".mart_1 mr set max_count_day =t3.max_count_day
from  (
select t1.source_id, t1.category_id, max(t1.date) as max_count_day from tmp_table t1
       join (select source_id, category_id, max(alltime) as alltime
             from tmp_table group by source_id, category_id) t2
          on t1.source_id=t2.source_id and t1.category_id=t2.category_id and t1.alltime=t2.alltime
          group by t1.source_id, t1.category_id
          ) t3
where mr.mart_date =current_date and
      mr.source_id =t3.source_id and
      mr.category_id =t3.category_id;


-- ?????????????????? ???????????? ???? ???????????????? ??????-???? ???????????? ???? ????????
-- ???? ??????-???? ???????? ?????????? ???????????? ???? ??????, ?? ?????????????? ???????? ?????????? ???? ?????? ??????????????????, ???????????? ????????????????????
update "Marts".mart_1 mr set avrg_count_per_day  =t3.all_day_count/t3.day_count
from (select t1.source_id, t1.category_id, sum(t1.alltime) as all_day_count, t2.day_count from tmp_table t1
       join (select source_id, category_id, count(date) as day_count
             from tmp_table group by source_id, category_id) t2
          on t1.source_id=t2.source_id and t1.category_id=t2.category_id
          group by t1.source_id, t1.category_id   ,t2.day_count
          ) t3
 where mr.mart_date =current_date and
      mr.source_id =t3.source_id and
      mr.category_id =t3.category_id
      and t3.day_count>0;

-- ?????????????????? ???????????? ???? ??????-???? ???????????? ???? ????????????????????????
update "Marts".mart_1 mr set monday_count=t3.monday_count
from (select t1.source_id, t1.category_id, sum(t1.alltime ) as monday_count
from tmp_table t1
       where t1.wd=1
        group by t1.source_id, t1.category_id ) t3
  where mr.mart_date =current_date and
      mr.source_id =t3.source_id and
      mr.category_id =t3.category_id    ;

     -- ?????????????????? ???????????? ???? ??????-???? ???????????? ???? ????????????????
update "Marts".mart_1 mr set tuesday_count=t3.tuesday_count
from (select t1.source_id, t1.category_id, sum(t1.alltime ) as tuesday_count
from tmp_table t1
       where t1.wd=2
        group by t1.source_id, t1.category_id ) t3
  where mr.mart_date =current_date and
      mr.source_id =t3.source_id and
      mr.category_id =t3.category_id    ;

-- ?????????????????? ???????????? ???? ??????-???? ???????????? ???? ??????????
update "Marts".mart_1 mr set wednesday_count=t3.wednesday_count
from (select t1.source_id, t1.category_id, sum(t1.alltime ) as wednesday_count
from tmp_table t1
       where t1.wd=3
        group by t1.source_id, t1.category_id ) t3
  where mr.mart_date =current_date and
      mr.source_id =t3.source_id and
      mr.category_id =t3.category_id    ;

-- ?????????????????? ???????????? ???? ??????-???? ???????????? ???? ????????????????
update "Marts".mart_1 mr set thursday_count=t3.thursday_count
from (select t1.source_id, t1.category_id, sum(t1.alltime ) as thursday_count
from tmp_table t1
       where t1.wd=4
        group by t1.source_id, t1.category_id ) t3
  where mr.mart_date =current_date and
      mr.source_id =t3.source_id and
      mr.category_id =t3.category_id    ;

-- ?????????????????? ???????????? ???? ??????-???? ???????????? ???? ??????????????
update "Marts".mart_1 mr set friday_count=t3.friday_count
from (select t1.source_id, t1.category_id, sum(t1.alltime ) as friday_count
from tmp_table t1
       where t1.wd=5
        group by t1.source_id, t1.category_id ) t3
  where mr.mart_date =current_date and
      mr.source_id =t3.source_id and
      mr.category_id =t3.category_id    ;

-- ?????????????????? ???????????? ???? ??????-???? ???????????? ???? ??????????????
update "Marts".mart_1 mr set saturday_count=t3.saturday_count
from (select t1.source_id, t1.category_id, sum(t1.alltime ) as saturday_count
from tmp_table t1
       where t1.wd=6
        group by t1.source_id, t1.category_id ) t3
  where mr.mart_date =current_date and
      mr.source_id =t3.source_id and
      mr.category_id =t3.category_id    ;

-- ?????????????????? ???????????? ???? ??????-???? ???????????? ???? ??????????????????????
update "Marts".mart_1 mr set sunday_count=t3.sunday_count
from (select t1.source_id, t1.category_id, sum(t1.alltime ) as sunday_count
from tmp_table t1
       where t1.wd=7
        group by t1.source_id, t1.category_id ) t3
  where mr.mart_date =current_date and
      mr.source_id =t3.source_id and
      mr.category_id =t3.category_id    ;



	END;
$procedure$
;

