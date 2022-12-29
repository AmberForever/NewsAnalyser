# NewsAnalyser
Проект для итоговой аттестации по курсу "Инженер данных"

<!-- TOC -->
* [Общая структура проекта](#--)
* [Структура программы Python](#--python)
* [Структура хранилища](#-)
* [Запуск программы](#-)
* [Планы по доработке](#--)
<!-- TOC -->

# Общая структура проекта
Проект построен на скрипте Python и базе данных на PostgreSQL.

Скрипт Python обращается к RSS источникам, собирает из них новости, приводит полученные данные к общему формату и с помощью процедуры отдает в базу данных PostgreSQL.
Запуск скрипта осуществляется раз в час.

В базе данных производится обработка данных и формируется витрина.

# Структура программы Python
В файле config.py хранятся список каналов RSS, настройки подключения к базе данных.

main.py - запускает парсер RSS по всем каналам.

rss_parser.py - функции работы с RSS (получает ленту, парсит, отдает на сохранение в базу).

user_agents.py - список параметров для имитации браузера

utils.py - утилиты (функции логирования и создания заголовка для эмуляции браузера)

postgres_dwh.py - функции работы с базой данных (пока только сохранение поста)

# Структура хранилища
В хранилище реализовано 3 слоя через схемы: Stage, DDS, Marts.

В слое Stage одна таблица - stage_posts. Здесь хранятся полученные посты. 
Здесь же лежит процедура сохранения нового поста sp_add_stage_post. Считаем уникальным для поста связку дата-ссылка на пост-источник. При повторении игнорируем.

В слое DDS лежат детальные данные.
categories - таблица категорий. Формируется автоматически из всех категорий из источника. В поле post_category лежит название из источника.
Дополнительное поле category позволяет приводить категории из разных источников к единому виду.

categories_unique - таблица общих названий категорий. Формируется автоматически из поля category таблицы categories. Эти названия используются для витрины.

sources - таблица источников. Формируется автоматически по данным Stage.

posts - таблица постов. Формируется по данным Stage.

post_category - таблица сопоставления постов и категорий. Один пост может относится сразу к нескольким категориям.
Здесь же лежит процедура sp_make_dds_and_marts, которая перекладывает данные из Stage в DDS, дополняя при необходимости таблицы категорий, источников и общих категорий.
Она же формирует витрину данных.

В слое Marts лежит витрина данных.
Предполагалось, что витрина данных формируется на каждый день и хранится для истории. Т.е. мы сможем посмотреть витрину в динамике, при необходимости.

SQL скрипт создания схем, таблиц и процедур лежит в папке "SQL". Здесь же лежит диаграмма базы в форматах pdf и drawio

# Запуск программы
Программа запускается через main.py. Для постоянной работы нужно запланировать ее работу через любой планировщик задач. Т.к. ленты отдают ограниченное кол-во постов за один раз, желательно настроить задачу на каждый час. Или чаще.
Пример на Crontab, который запускает скрипт каждый час за 2 минуты до конца часа: 

58 * * * * cd /home/usr/NewsAnalyser/src/NewsAnalyser && /home/usr/NewsAnalyser/src/NewsAnalyser/venv/bin/python3 main.py

# Планы по доработке
1. Реализовать ассинхронность. Хочется, чтобы посты загружались не последовательно, а параллельно.
2. Организовать контейнер для Docker.
