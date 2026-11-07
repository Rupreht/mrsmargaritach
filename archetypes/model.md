---
title: "Рубашка «{{ replace .File.ContentBaseName `-` ` ` | title }}»"
slug: "{{ .File.ContentBaseName }}"
date: {{ .Date }}
collection: ""                # slug коллекции: classic | long
article: ""                   # артикул модели
color_name: ""                # название цвета, как на фото
color_hex: "#DED3C4"        # плейсхолдер карточки, пока нет фото
price: 0                      # TODO: цена в рублях
status: "в наличии"           # в наличии | под заказ | снята с продажи
fabric_id: ""                 # mixed | cotton | muslin → data/fabrics.yaml; пусто — только строка fabric
fabric: ""                    # состав по ярлыку; проценты слитно: 97% хлопок, 3% эластан
density: ""                   # плотность ткани, г/м²
care: ""                      # рекомендации по уходу
fit: "свободный"
length_cm:                    # фактическая длина по спинке, см (уточнить у владелицы)
sizes: ["54", "56", "58", "60", "62", "64", "66", "68", "70", "72"]
badge: ""                     # опционально: новинка, хит
description: ""               # 1–2 предложения для карточки и метатега
details:                      # дизайнерские особенности
  - ""
images:
  - src: "cover.webp"         # положить файлы рядом с index.md
    alt: ""                   # обязательно: что на фото
    ratio: "4:5"
cta:
  label: "Написать про эту модель"
  channel: "telegram"
  prefill: "Здравствуйте, Маргарита! Интересует рубашка «{{ replace .File.ContentBaseName `-` ` ` | title }}», размер ___."
seo:
  title: ""
  description: ""
---

Короткое описание модели: как сидит, с чем носить, для какого сезона.
