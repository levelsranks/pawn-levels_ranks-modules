[Levels Ranks] Module - Fake Rank
===========================

[Levels Ranks] Module - Fake Rank - это модуль для плагина Levels Ranks. Данный модуль, используя ранги Ядра, показывает их в TAB(е).

<a href="//levels-ranks.ru/content/modules/fakerank.png"><img src="https://levels-ranks.ru/content/modules/fakerank.png"/></a>
<a href="//levels-ranks.ru/content/modules/fakerank2.png"><img src="https://levels-ranks.ru/content/modules/fakerank2.png"/></a>
<a href="//levels-ranks.ru/content/modules/fakerank3.png"><img src="https://levels-ranks.ru/content/modules/fakerank3.png"/></a>

Кастомные звания:
-------------------------
- <a href="//levels-ranks.ru/plugins/modules/custom_fakerank/skillgroup181.svg">Kruya Elite</a>

  - [Faceit Ranks] Pack (10 уровней/званий) - <a href="//vk.com/wend4r">Купить за 100 рублей</a>.
  - Свои звания на заказ - <a href="//vk.com/wend4r">Купить (1 звание - 50 рублей)</a>.

<details><summary>Как установить кастомные звания ?</summary>

1) В конфиге (`levels_ranks/fakerank.ini`) установите значение `"0"` у параметра `"Type"`; 
2) Файл со званием переместите в ``materials/panorama/images/icons/skillgroups/`` на FastDL; 
3) Укажите в конфиге модуля у звания в ТАБ(е) его индекс - skillgroup(индекс).svg. 

</details>

Поддерживаемые игры:
--------------------
- CS: GO

Требования:
-----------
- SourceMod <a href="//sourcemod.net/downloads.php?branch=stable">1.9.0.6241</a> / <a href="//sourcemod.net/downloads.php?branch=dev">1.10.6412</a> и выше.
- <a href="https://github.com/levelsranks/levels-ranks-core">[Levels Ranks] Core</a> (не ниже v3.0).

Установка:
----------
- Удалите прошлую версию плагина, если есть.
- Распакуйте содержимое архива по папкам.
- Настройте файл:
	- addons/sourcemod/configs/levels_ranks/fakerank.ini
- Перезапустите сервер.
```
